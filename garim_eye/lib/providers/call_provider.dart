import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import '../services/socket_service.dart';
import 'socket_provider.dart';

enum CallStatus { idle, incoming, connecting, calling, connected, ended }

class CallState {
  final CallStatus status;
  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;
  final String? callerId; // Phone number or ID of the caller
  final String? callerName;
  final String? room;

  CallState({
    required this.status,
    required this.localRenderer,
    required this.remoteRenderer,
    this.callerId,
    this.callerName,
    this.room,
  });

  CallState copyWith({
    CallStatus? status,
    String? callerId,
    String? callerName,
    String? room,
  }) {
    return CallState(
      status: status ?? this.status,
      localRenderer: localRenderer,
      remoteRenderer: remoteRenderer,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      room: room ?? this.room,
    );
  }
}

class CallNotifier extends StateNotifier<CallState> {
  final SocketService _socketService;
  late WebRTCService _webRTCService;

  CallNotifier(this._socketService) : super(_initialState()) {
    _init();
  }

  static CallState _initialState() {
    return CallState(
      status: CallStatus.idle,
      localRenderer: RTCVideoRenderer(),
      remoteRenderer: RTCVideoRenderer(),
    );
  }

  void _init() {
    _initRenderers(state.localRenderer, state.remoteRenderer);
    _webRTCService = WebRTCService();
    _initWebRTCCallbacks();

    // Setup Socket Callbacks
    _socketService.onIncomingCall = (data) {
      // data: {from, to, room, callerName}
      debugPrint('CallNotifier: Incoming call from ${data['from']}');
      state = state.copyWith(
        status: CallStatus.incoming,
        callerId: data['from'],
        callerName: data['callerName'] ?? 'Unknown',
        room: data['room'],
      );
    };

    _socketService.onHangup = (data) {
      hangup();
    };

    _socketService.onOffer = (data) async {
      // We received an offer (likely from web).
      // Ensure we have PeerConnection
      // data: {from, to, sdp, type}
      debugPrint('CallNotifier: Processing Offer');
      await _webRTCService.initializePeerConnection(state.room!);

      String sdp = data['sdp'];
      String type = data['type'];
      await _webRTCService.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );

      // Create Answer
      RTCSessionDescription answer = await _webRTCService.createAnswer();

      _socketService.sendAnswer({
        'from': _socketService.myPhoneNumber,
        'to': state.callerId!,
        'sdp': answer.sdp,
        'type': answer.type,
      });
    };

    _socketService.onAnswer = (data) async {
      String sdp = data['sdp'];
      String type = data['type'];
      await _webRTCService.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );
    };

    _socketService.onIceCandidate = (data) async {
      var candidateMap = data['candidate'];
      if (candidateMap != null) {
        await _webRTCService.addCandidate(
          RTCIceCandidate(
            candidateMap['candidate'],
            candidateMap['sdpMid'],
            candidateMap['sdpMLineIndex'],
          ),
        );
      }
    };
  }

  Future<void> _initRenderers(
    RTCVideoRenderer local,
    RTCVideoRenderer remote,
  ) async {
    await local.initialize();
    await remote.initialize();
  }

  // Actions
  Future<void> startCall(String targetPhone) async {
    final room = 'room_${DateTime.now().millisecondsSinceEpoch}';

    // Update state
    state = state.copyWith(
      status: CallStatus.calling,
      room: room,
      callerId: targetPhone, // User I am calling
    );

    // 1. Start Local Stream FIRST
    debugPrint('CallNotifier: Starting local stream...');
    await _webRTCService.startLocalStream();

    // 2. Initialize PeerConnection with room ID
    debugPrint('CallNotifier: Initializing PeerConnection for room: $room');
    await _webRTCService.initializePeerConnection(room);

    // 3. Create and send Offer
    debugPrint('CallNotifier: Creating Offer...');
    RTCSessionDescription offer = await _webRTCService.createOffer();
    debugPrint('CallNotifier: Offer created, sending to $targetPhone');

    _socketService.sendOffer({
      'from': _socketService.myPhoneNumber,
      'to': targetPhone,
      'sdp': offer.sdp,
      'type': offer.type,
    });

    // 4. Send Call Request (for notification)
    debugPrint('CallNotifier: Sending call request notification');
    _socketService.sendCallRequest(to: targetPhone, room: room);
  }

  Future<void> acceptCall() async {
    if (state.status != CallStatus.incoming) return;

    _socketService.sendCallResponse(to: state.callerId!, status: 'accepted');

    // Update state first
    state = state.copyWith(status: CallStatus.connecting);

    // Start media
    try {
      await _webRTCService.startLocalStream();
    } catch (e) {
      debugPrint('Failed to start local stream: $e');
    }
  }

  void rejectCall() {
    if (state.status != CallStatus.incoming) return;

    _socketService.sendCallResponse(to: state.callerId!, status: 'rejected');

    hangup();
  }

  void hangup() {
    // 1. Emit Hangup Event to Server (Protocol v1.1)
    if (state.callerId != null) {
      _socketService.sendHangup(to: state.callerId!, reason: 'user_ended');
    }

    // 2. Local Cleanup
    _webRTCService.dispose();

    // 3. Reset State
    state = state.copyWith(
      status: CallStatus.ended,
      callerId: null,
      callerName: null,
      room: null,
    );

    // Reset to idle after delay
    Future.delayed(const Duration(seconds: 2), () {
      _webRTCService = WebRTCService();
      // Re-init callbacks for the new service instance
      _initWebRTCCallbacks(); // Need to extract init logic to reuse
      state = state.copyWith(status: CallStatus.idle);
    });
  }

  // Refracted to allow re-init
  void _initWebRTCCallbacks() {
    _webRTCService.onLocalStream = (stream) {
      debugPrint('📹 [CallNotifier] Local stream received: ${stream.id}');
      state.localRenderer.srcObject = stream;
      state = state.copyWith();
    };

    _webRTCService.onRemoteStream = (stream) {
      debugPrint('📹 [CallNotifier] Remote stream received: ${stream.id}');
      debugPrint(
        '📹 [CallNotifier] Remote video tracks: ${stream.getVideoTracks().length}',
      );
      state.remoteRenderer.srcObject = stream;
      debugPrint('📹 [CallNotifier] Setting status to CONNECTED');
      state = state.copyWith(status: CallStatus.connected);
      debugPrint('✅ [CallNotifier] Status now: ${state.status}');
      debugPrint(
        '✅ [CallNotifier] Remote srcObject: ${state.remoteRenderer.srcObject != null}',
      );
    };

    _webRTCService.onIceCandidate = (candidate, _) {
      if (state.room != null && state.callerId != null) {
        _socketService.sendIce({
          'from': _socketService.myPhoneNumber,
          'to': state.callerId!,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };
  }

  @override
  void dispose() {
    _webRTCService.dispose();
    state.localRenderer.dispose();
    state.remoteRenderer.dispose();
    super.dispose();
  }
}

final callProvider = StateNotifierProvider.autoDispose<CallNotifier, CallState>(
  (ref) {
    final socketService = ref.watch(socketServiceProvider);
    return CallNotifier(socketService);
  },
);
