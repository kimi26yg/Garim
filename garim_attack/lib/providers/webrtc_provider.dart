import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../video_processor.dart';
import 'socket_provider.dart';

// Top-level function for compute
Future<Uint8List> decodeImageTask(String base64Str) async {
  try {
    if (base64Str.contains(',')) {
      base64Str = base64Str.split(',').last;
    }
    return base64Decode(base64Str);
  } catch (e) {
    throw Exception("Decoding failed: $e");
  }
}

final videoKeyProvider = Provider((ref) => GlobalKey());

enum CallStatus {
  idle,
  connecting,
  connected,
  failed,
  incoming,
}

class WebRTCState {
  final bool isCameraReady;
  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;
  final RTCPeerConnection? peerConnection;
  final Uint8List? deepfakeFrame;

  // Filter States
  final bool isDeepfakeActive;
  final bool isMosaicActive;
  final bool isBeautyActive;

  // Stability States
  final bool isAutoplayBlocked;

  // Call Status
  final CallStatus callStatus;

  // ID storage for signaling
  final String? myPhoneNumber;
  final String? targetPhoneNumber;

  WebRTCState({
    required this.isCameraReady,
    required this.localRenderer,
    required this.remoteRenderer,
    this.peerConnection,
    this.deepfakeFrame,
    this.isDeepfakeActive = false,
    this.isMosaicActive = false,
    this.isBeautyActive = false,
    this.isAutoplayBlocked = false,
    this.callStatus = CallStatus.idle,
    this.myPhoneNumber,
    this.targetPhoneNumber,
  });

  WebRTCState copyWith({
    bool? isCameraReady,
    RTCVideoRenderer? localRenderer,
    RTCVideoRenderer? remoteRenderer,
    RTCPeerConnection? peerConnection,
    Uint8List? deepfakeFrame,
    bool? isDeepfakeActive,
    bool? isMosaicActive,
    bool? isBeautyActive,
    bool? isAutoplayBlocked,
    CallStatus? callStatus,
    String? myPhoneNumber,
    String? targetPhoneNumber,
  }) {
    return WebRTCState(
      isCameraReady: isCameraReady ?? this.isCameraReady,
      localRenderer: localRenderer ?? this.localRenderer,
      remoteRenderer: remoteRenderer ?? this.remoteRenderer,
      peerConnection: peerConnection ?? this.peerConnection,
      deepfakeFrame: deepfakeFrame ?? this.deepfakeFrame,
      isDeepfakeActive: isDeepfakeActive ?? this.isDeepfakeActive,
      isMosaicActive: isMosaicActive ?? this.isMosaicActive,
      isBeautyActive: isBeautyActive ?? this.isBeautyActive,
      isAutoplayBlocked: isAutoplayBlocked ?? this.isAutoplayBlocked,
      callStatus: callStatus ?? this.callStatus,
      myPhoneNumber: myPhoneNumber ?? this.myPhoneNumber,
      targetPhoneNumber: targetPhoneNumber ?? this.targetPhoneNumber,
    );
  }
}

final videoProcessorProvider = Provider.autoDispose((ref) => VideoProcessor());

class WebRTCNotifier extends Notifier<WebRTCState> {
  VideoProcessor? _processor;
  Timer? _debounceTimer;
  Timer? _callTimeoutTimer; // For call connection timeout

  @override
  WebRTCState build() {
    final localRenderer = RTCVideoRenderer();
    final remoteRenderer = RTCVideoRenderer();

    // Obtain processor instance
    _processor = ref.read(videoProcessorProvider);

    ref.onDispose(() {
      _debounceTimer?.cancel();
      _callTimeoutTimer?.cancel();
      state.localRenderer.srcObject?.dispose();
      state.localRenderer.dispose();
      state.remoteRenderer.srcObject?.dispose();
      state.remoteRenderer.dispose();
      state.peerConnection?.dispose();
      _processor?.dispose();
    });

    _init(localRenderer, remoteRenderer);

    return WebRTCState(
      isCameraReady: false,
      localRenderer: localRenderer,
      remoteRenderer: remoteRenderer,
    );
  }

  // --- Actions ---

  void warmUp() {
    _processor?.warmUp();
    if (state.isAutoplayBlocked) {
      state = state.copyWith(isAutoplayBlocked: false);
    }
  }

  void toggleDeepfake() {
    // 1. Warm up immediately on user gesture interaction (before debounce)
    warmUp();

    if (_debounceTimer?.isActive ?? false) return;
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final newState = !state.isDeepfakeActive;
      _setDeepfake(newState);
    });
  }

  void toggleMosaic() {
    final newState = !state.isMosaicActive;
    state = state.copyWith(isMosaicActive: newState);
    _processor?.setMosaic(newState);
  }

  void toggleBeauty() {
    final newState = !state.isBeautyActive;
    state = state.copyWith(isBeautyActive: newState);
    _processor?.setBeauty(newState);
  }

  void loadDeepfakeVideo(String url) {
    _processor?.updateDeepfakeUrl(url);
  }

  // --- Internal Logic ---

  void _onPlayError(String error) {
    print("[WebRTC] Play Error: $error");
    if (error.contains("play") || error.contains("blocked")) {
      state = state.copyWith(isAutoplayBlocked: true);
    }
  }

  void _setDeepfake(bool active) {
    if (_processor == null) return;

    // Update State
    state = state.copyWith(isDeepfakeActive: active);

    // Update Processor
    _processor!
        .setSource(active ? VideoSourceType.deepfake : VideoSourceType.camera);

    _updateAudioTrackInPC();
  }

  void _onVideoEnded() {
    print("[System] Video playback finished. Reverting to Live Camera...");
    state = state.copyWith(isDeepfakeActive: false);
    _processor?.setSource(VideoSourceType.camera);
    _updateAudioTrackInPC();
  }

  Future<void> _updateAudioTrackInPC() async {
    if (state.peerConnection == null || _processor == null) return;

    final newTrack = _processor!.currentAudioTrack;
    if (newTrack == null) return;

    var senders = await state.peerConnection!.getSenders();
    for (var sender in senders) {
      if (sender.track?.kind == 'audio') {
        try {
          await sender.replaceTrack(newTrack);
          print("[WebRTC] Replaced Audio Track");
        } catch (e) {
          print("[WebRTC] Error replacing audio track: $e");
        }
      }
    }
  }

  Future<void> _init(RTCVideoRenderer local, RTCVideoRenderer remote) async {
    await local.initialize();
    await remote.initialize();
    await _getUserMedia(local);
    await _createPeerConnection();
  }

  Future<void> _getUserMedia(RTCVideoRenderer renderer) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 720},
        'height': {'ideal': 1280}
      }
    };

    try {
      MediaStream cameraStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);

      // Initialize Processor w/ Callbacks
      _processor!.onVideoEnded = _onVideoEnded;
      _processor!.onPlayError = _onPlayError;

      await _processor!
          .initialize(cameraStream, 'assets/videos/deepfake_v1.mp4');

      renderer.srcObject = _processor!.outputStream;

      state = state.copyWith(isCameraReady: true);

      if (state.peerConnection != null && _processor!.outputStream != null) {
        final stream = _processor!.outputStream!;
        for (var track in stream.getTracks()) {
          state.peerConnection!.addTrack(track, stream);
          print("[WebRTC] ${track.kind} track from Processor added");
        }
      }
    } catch (e) {
      print("[WebRTC] Error getting user media: $e");
    }
  }

  Future<void> _createPeerConnection() async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };

    try {
      RTCPeerConnection pc =
          await createPeerConnection(configuration, offerSdpConstraints);

      pc.onIceCandidate = (RTCIceCandidate candidate) {
        _onIceCandidate?.call(candidate);
      };

      pc.onTrack = (RTCTrackEvent event) {
        print("[WebRTC] Track detected: ${event.track.kind}");
        if (event.track.kind == 'video') {
          print("[SYSTEM] Target stream received. Ready for injection.");
          state.remoteRenderer.srcObject = event.streams[0];
          state = state.copyWith(remoteRenderer: state.remoteRenderer);
        }
      };

      state = state.copyWith(peerConnection: pc);

      if (state.isCameraReady && state.localRenderer.srcObject != null) {
        final stream = state.localRenderer.srcObject!;
        for (var track in stream.getTracks()) {
          pc.addTrack(track, stream);
          print("[WebRTC] ${track.kind} track added to PeerConnection");
        }
      }
    } catch (e) {
      print("[WebRTC] Error creating PeerConnection: $e");
    }
  }

  // Helper: Prefer Codec (Restored)
  String _preferCodec(String sdp, String codec) {
    var lines = sdp.split('\r\n');
    int mLineIndex = -1;
    String codecPayloadType = '-1';

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('m=video')) {
        mLineIndex = i;
        break;
      }
    }

    if (mLineIndex == -1) return sdp;

    final regex = RegExp('^a=rtpmap:(\\d+) $codec/\\d+');
    for (var line in lines) {
      var match = regex.firstMatch(line);
      if (match != null) {
        codecPayloadType = match.group(1)!;
        break;
      }
    }

    if (codecPayloadType == '-1') {
      return sdp;
    }

    var mLine = lines[mLineIndex];
    var elements = mLine.split(' ');
    if (elements.length < 4) return sdp;

    var codecs = elements.sublist(3);
    codecs.remove(codecPayloadType);
    codecs.insert(0, codecPayloadType);

    lines[mLineIndex] =
        "${elements.sublist(0, 3).join(' ')} ${codecs.join(' ')}";

    return lines.join('\r\n');
  }

  // Signaling Callbacks
  Function(RTCIceCandidate)? _onIceCandidate;

  // --- Helper: Robust Data Parsing ---
  dynamic _parseSocketData(dynamic data) {
    if (data == null) return null;
    try {
      if (data is List) {
        if (data.isEmpty) return null;
        return _parseSocketData(data.first); // Recursively unwrap if needed
      }
      if (data is String) {
        return jsonDecode(data);
      }
      return data;
    } catch (e) {
      print("[WebRTC] Error parsing socket data: $e");
      return null;
    }
  }

  // --- Protocol v1.1 Signaling ---

  void setupSignalListeners(IO.Socket socket) {
    // 1. Handshake Response
    socket.on('call:response', (data) {
      try {
        final payload = _parseSocketData(data);
        if (payload == null) return;

        print("[Protocol v1.1] Received call:response: $payload");

        final status = payload['status'];
        if (status == 'accepted') {
          _callTimeoutTimer?.cancel();
          state =
              state.copyWith(callStatus: CallStatus.connected); // Update status
          // With Protocol v1.1 unification, we rely on stored targetPhoneNumber
          // or ensure 'from' is the phone number.
          _createOffer(socket);
        } else {
          print("[Protocol v1.1] Call Rejected or Busy: $status");
          _handleCallFailed();
        }
      } catch (e) {
        print("[WebRTC] Error processing call:response: $e");
      }
    });

    // 2. Remote Answer (Standard WebRTC)
    socket.on('webrtc:answer', (data) async {
      try {
        final payload = _parseSocketData(data);
        if (payload == null) return;

        print("[Protocol v1.1] Received webrtc:answer");
        await _handleAnswer(payload);
      } catch (e) {
        print("[WebRTC] Error processing webrtc:answer: $e");
      }
    });

    // 3. ICE Candidates
    socket.on('webrtc:ice', (data) async {
      try {
        final payload = _parseSocketData(data);
        if (payload == null) return;

        await _handleCandidate(payload);
      } catch (e) {
        print("[WebRTC] Error processing webrtc:ice: $e");
      }
    });

    // 4. Remote Hangup
    socket.on('call:hangup', (data) {
      try {
        final payload = _parseSocketData(data);
        print("[Protocol v1.1] Received call:hangup: $payload");
        _hangUp();
      } catch (e) {
        print("[WebRTC] Error processing call:hangup: $e");
      }
    });

    // 5. Incoming Call Request (Callee)
    socket.on('call:request', (data) {
      try {
        final payload = _parseSocketData(data);
        if (payload == null) return;

        print("[Protocol v1.1] Incoming Call Request: $payload");

        // Extract Caller Info
        final from = payload['from']?.toString();
        // final to = payload['to']; // Should be me

        if (state.callStatus == CallStatus.idle) {
          state = state.copyWith(
            callStatus: CallStatus.incoming,
            targetPhoneNumber: from, // Temporarily store who is calling
          );
          // We do NOT set myPhoneNumber here, assuming it's already set or we get it from socketState if needed.
          // But actually we need it. Let's assume we use what we have or just respond.
        } else {
          // Busy - Reject automatically?
          print("[Protocol v1.1] Busy. Rejecting incoming call from $from");
          socket.emit('call:response', {
            'status': 'busy',
            'to': from,
            'from': 'busy_user', // Or my number if available
            'reason': 'User is busy'
          });
        }
      } catch (e) {
        print("[WebRTC] Error processing call:request: $e");
      }
    });
  }

  // --- Actions ---

  void acceptCall(SocketNotifier socketNotifier) {
    final socket = socketNotifier.socket;
    final targetPhone = state.targetPhoneNumber;
    final myPhone = socketNotifier.state.myPhoneNumber; // Get from socket state

    if (targetPhone == null) return;

    print("[Protocol v1.1] Accepting Call from $targetPhone");

    // Update State
    state = state.copyWith(
      callStatus: CallStatus.connected,
      myPhoneNumber: myPhone,
    );

    // Emit Response
    socket.emit('call:response', {
      'status': 'accepted',
      'to': targetPhone,
      'from': myPhone,
    });

    // As Callee, we wait for 'webrtc:offer' now.
    // _createOffer is only for Caller.
  }

  void rejectCall(SocketNotifier socketNotifier) {
    final socket = socketNotifier.socket;
    final targetPhone = state.targetPhoneNumber;
    final myPhone = socketNotifier.state.myPhoneNumber;

    print("[Protocol v1.1] Rejecting Call from $targetPhone");

    state = state.copyWith(callStatus: CallStatus.idle);

    if (targetPhone != null) {
      socket.emit('call:response', {
        'status': 'rejected',
        'to': targetPhone,
        'from': myPhone,
        'reason': 'User rejected'
      });
    }
  }

  Future<void> requestCall(SocketNotifier socketNotifier,
      String targetPhoneNumber, String? myPhoneNumber) async {
    final socket = socketNotifier.socket;
    if (state.peerConnection == null) await _createPeerConnection();

    // Reset state just in case
    // Protocol v1.1 Step 1: Send call:request with Phone Numbers
    final payload = {
      'to': targetPhoneNumber, // Target Phone Number
      'from': myPhoneNumber, // My Phone Number
      'callerName': 'GEYE_ADMIN',
      'room': 'GEYE_SESSION_SECURE',
    };

    print(
        "[Protocol v1.1] Sending call:request -> $targetPhoneNumber (My: $myPhoneNumber)");
    socketNotifier.addLog("SIGNAL OUTGOING: Calling $targetPhoneNumber...");

    // Store IDs in state for future signaling
    state = state.copyWith(
      callStatus: CallStatus.connecting,
      myPhoneNumber: myPhoneNumber,
      targetPhoneNumber: targetPhoneNumber,
    );

    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (state.callStatus == CallStatus.connecting) {
        print("[Call] Timeout! No answer after 15s.");
        _handleCallFailed();
      }
    });

    socket.emit('call:request', payload);
  }

  void endCall(SocketNotifier socketNotifier) {
    print("[Protocol v1.1] User initiated Hangup.");
    socketNotifier.addLog("SIGNAL OUTGOING: Ending Call...");
    socketNotifier.emit('call:hangup', {
      'from': state.myPhoneNumber,
      'to': state.targetPhoneNumber,
      'reason': 'hangup'
    });
    _hangUp(); // Perform local cleanup
  }

  void cancelCall(SocketNotifier socketNotifier) {
    print("[Protocol v1.1] User Cancelled Call.");
    socketNotifier.addLog("SIGNAL OUTGOING: Call Cancelled");

    // Stop timeout timer
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;

    // Reset status to idle immediately. Keep numbers for a moment or clear?
    // We'll keep them until cleanup.
    state = state.copyWith(callStatus: CallStatus.idle);

    // Notify server just in case signal went through
    socketNotifier.emit('call:hangup', {
      'from': state.myPhoneNumber,
      'to': state.targetPhoneNumber,
      'reason': 'cancel'
    });

    // Ensure cleanup
    _hangUp();
  }

  void _handleCallFailed() {
    state = state.copyWith(callStatus: CallStatus.failed);
    // Revert to idle after short delay to show failed state
    Future.delayed(const Duration(seconds: 2), () {
      state = state.copyWith(callStatus: CallStatus.idle);
    });
  }

  Future<void> _createOffer(IO.Socket socket) async {
    if (state.peerConnection == null) return;

    final myPhone = state.myPhoneNumber;
    final targetPhone = state.targetPhoneNumber;

    if (myPhone == null || targetPhone == null) {
      print("[WebRTC] Error: Missing Phone Numbers for signaling");
      return;
    }

    try {
      RTCSessionDescription offer = await state.peerConnection!.createOffer();

      // Prefer H.264 if possible
      String sdp = offer.sdp!;
      sdp = _preferCodec(sdp, 'H264');
      RTCSessionDescription newOffer = RTCSessionDescription(sdp, offer.type);

      await state.peerConnection!.setLocalDescription(newOffer);

      // Protocol v1.1 Step 3: Send webrtc:offer w/ Phone Numbers
      final payload = {
        'from': myPhone,
        'to': targetPhone,
        'sdp': newOffer.sdp,
        'type': newOffer.type,
      };

      print("[Protocol v1.1] Sending webrtc:offer -> $targetPhone");
      socket.emit('webrtc:offer', payload);

      // Setup ICE candidate hook to send via correct protocol
      _onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        final icePayload = {
          'from': myPhone,
          'to': targetPhone,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        };
        print("[Protocol v1.1] Sending webrtc:ice");
        socket.emit('webrtc:ice', icePayload);
      };
    } catch (e) {
      print("[WebRTC] Error creating offer: $e");
    }
  }

  Future<void> _handleAnswer(dynamic data) async {
    if (state.peerConnection == null) return;
    try {
      // Unpack if needed
      dynamic payload = data;
      if (payload is String) payload = jsonDecode(payload);

      // Extract SDP. data might be { ..., sdp: "..." }
      String? sdp = payload['sdp'];
      String? type = payload['type'];

      if (sdp != null && type != null) {
        RTCSessionDescription description = RTCSessionDescription(sdp, type);
        await state.peerConnection!.setRemoteDescription(description);
      }
    } catch (e) {
      print("[WebRTC] Error handling answer: $e");
    }
  }

  Future<void> _handleCandidate(dynamic data) async {
    if (state.peerConnection == null) return;
    try {
      dynamic payload = data;
      if (payload is String) payload = jsonDecode(payload);

      // Access 'candidate' field
      dynamic candidateData = payload['candidate'];

      if (candidateData != null) {
        String iceCandidate = candidateData['candidate'];
        String sdpMid = candidateData['sdpMid'];
        int sdpMLineIndex = candidateData['sdpMLineIndex'];

        RTCIceCandidate candidate =
            RTCIceCandidate(iceCandidate, sdpMid, sdpMLineIndex);
        await state.peerConnection!.addCandidate(candidate);
      }
    } catch (e) {
      print("[WebRTC] Error handling candidate: $e");
    }
  }

  void _hangUp() {
    print("[Protocol v1.1] Hangup/Cleanup.");
    state.peerConnection?.close();
    state.remoteRenderer.srcObject = null;

    // Reset Status
    state = state.copyWith(
      remoteRenderer: state.remoteRenderer,
      callStatus: CallStatus.idle,
    );

    // Re-initialize peer connection for future calls
    _createPeerConnection();
  }

  Future<void> handleAttackComplete(dynamic data) async {
    try {
      String? base64Str;
      if (data is Map && data.containsKey('image')) {
        base64Str = data['image'];
      } else if (data is String) {
        base64Str = data;
      }

      if (base64Str != null) {
        final Uint8List bytes = await compute(decodeImageTask, base64Str);
        state = state.copyWith(deepfakeFrame: bytes);
      }
    } catch (e) {
      print("[WebRTC] Error decoding/updating frame: $e");
    }
  }
}

final webRTCProvider = NotifierProvider<WebRTCNotifier, WebRTCState>(() {
  return WebRTCNotifier();
});
