import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../video_processor.dart';

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
    );
  }
}

final videoProcessorProvider = Provider.autoDispose((ref) => VideoProcessor());

class WebRTCNotifier extends Notifier<WebRTCState> {
  VideoProcessor? _processor;
  Timer? _debounceTimer;

  @override
  WebRTCState build() {
    final localRenderer = RTCVideoRenderer();
    final remoteRenderer = RTCVideoRenderer();

    // Obtain processor instance
    _processor = ref.read(videoProcessorProvider);

    ref.onDispose(() {
      _debounceTimer?.cancel();
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

  Future<void> startCall(IO.Socket socket, String roomId) async {
    if (state.peerConnection == null) return;
    try {
      RTCSessionDescription offer = await state.peerConnection!.createOffer();

      String sdp = offer.sdp!;
      sdp = _preferCodec(sdp, 'H264');
      RTCSessionDescription newOffer = RTCSessionDescription(sdp, offer.type);

      await state.peerConnection!.setLocalDescription(newOffer);

      print("[WebRTC] Sending Offer to room: $roomId (Preferring H.264)");
      socket.emit('offer', {
        'sdp': newOffer.sdp,
        'type': newOffer.type,
        'roomId': roomId,
      });
    } catch (e) {
      print("[WebRTC] Error starting call: $e");
    }
  }

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
  void setOnIceCandidate(Function(RTCIceCandidate) callback) {
    _onIceCandidate = callback;
  }

  // Signaling Handlers
  Future<void> handleOffer(
      Map<String, dynamic> offerData, IO.Socket socket) async {
    if (state.peerConnection == null) return;

    try {
      RTCSessionDescription description =
          RTCSessionDescription(offerData['sdp'], offerData['type']);
      await state.peerConnection!.setRemoteDescription(description);

      RTCSessionDescription answer = await state.peerConnection!.createAnswer();
      await state.peerConnection!.setLocalDescription(answer);

      String roomId = offerData['roomId'] ?? 'garim_room';
      socket.emit('answer', {
        'sdp': answer.sdp,
        'type': answer.type,
        'roomId': roomId,
      });
    } catch (e) {
      print("[WebRTC] Error handling offer: $e");
    }
  }

  Future<void> handleAnswer(dynamic answerData) async {
    if (state.peerConnection == null) return;
    try {
      Map<String, dynamic> payload;
      if (answerData is String) {
        payload = jsonDecode(answerData);
      } else if (answerData is Map) {
        payload = Map<String, dynamic>.from(answerData);
      } else if (answerData is List) {
        if (answerData.isEmpty) return;
        payload = Map<String, dynamic>.from(answerData[0] as Map);
      } else {
        return;
      }

      RTCSessionDescription description =
          RTCSessionDescription(payload['sdp'], payload['type']);
      await state.peerConnection!.setRemoteDescription(description);
    } catch (e) {
      print("[WebRTC] Error handling answer: $e");
    }
  }

  Future<void> handleCandidate(dynamic candidateData) async {
    if (state.peerConnection == null) return;
    try {
      Map<String, dynamic> payload;
      if (candidateData is String) {
        payload = jsonDecode(candidateData);
      } else if (candidateData is Map) {
        payload = Map<String, dynamic>.from(candidateData);
      } else if (candidateData is List) {
        if (candidateData.isEmpty) return;
        payload = Map<String, dynamic>.from(candidateData[0] as Map);
      } else {
        return;
      }

      RTCIceCandidate candidate = RTCIceCandidate(
          payload['candidate'], payload['sdpMid'], payload['sdpMLineIndex']);
      await state.peerConnection!.addCandidate(candidate);
    } catch (e) {
      print("[WebRTC] Error handling candidate: $e");
    }
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
