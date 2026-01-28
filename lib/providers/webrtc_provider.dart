import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

// Top-level function for compute
Future<Uint8List> decodeImageTask(String base64Str) async {
  try {
    // Strip header if present (e.g. data:image/png;base64,)
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

  WebRTCState({
    required this.isCameraReady,
    required this.localRenderer,
    required this.remoteRenderer,
    this.peerConnection,
    this.deepfakeFrame,
  });

  WebRTCState copyWith({
    bool? isCameraReady,
    RTCVideoRenderer? localRenderer,
    RTCVideoRenderer? remoteRenderer,
    RTCPeerConnection? peerConnection,
    Uint8List? deepfakeFrame,
  }) {
    return WebRTCState(
      isCameraReady: isCameraReady ?? this.isCameraReady,
      localRenderer: localRenderer ?? this.localRenderer,
      remoteRenderer: remoteRenderer ?? this.remoteRenderer,
      peerConnection: peerConnection ?? this.peerConnection,
      deepfakeFrame: deepfakeFrame ?? this.deepfakeFrame,
    );
  }
}

class WebRTCNotifier extends Notifier<WebRTCState> {
  @override
  WebRTCState build() {
    final localRenderer = RTCVideoRenderer();
    final remoteRenderer = RTCVideoRenderer();

    ref.onDispose(() {
      state.localRenderer.srcObject?.dispose();
      state.localRenderer.dispose();
      state.remoteRenderer.srcObject?.dispose();
      state.remoteRenderer.dispose();
      state.peerConnection?.dispose();
    });

    _init(localRenderer, remoteRenderer);

    return WebRTCState(
      isCameraReady: false,
      localRenderer: localRenderer,
      remoteRenderer: remoteRenderer,
    );
  }

  Future<void> _init(RTCVideoRenderer local, RTCVideoRenderer remote) async {
    await local.initialize();
    await remote.initialize();
    await _getUserMedia(local);
    await _createPeerConnection();
  }

  Future<void> _getUserMedia(RTCVideoRenderer renderer) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': false,
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 720},
        'height': {'ideal': 1280}
      }
    };

    try {
      MediaStream stream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      renderer.srcObject = stream;
      state = state.copyWith(isCameraReady: true);

      if (state.peerConnection != null) {
        state.peerConnection!.addStream(stream);
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
        'OfferToReceiveAudio': false,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };

    try {
      RTCPeerConnection pc =
          await createPeerConnection(configuration, offerSdpConstraints);

      pc.onIceCandidate = (RTCIceCandidate candidate) {
        print('[WebRTC] ICE Candidate generated: ${candidate.candidate}');
        _onIceCandidate?.call(candidate);
      };

      pc.onTrack = (RTCTrackEvent event) {
        print("[WebRTC] Track detected: ${event.track.kind}");
        if (event.track.kind == 'video') {
          print("[SYSTEM] Target stream received. Ready for injection.");
          state.remoteRenderer.srcObject = event.streams[0];
          // Force update to trigger UI redraw
          state = state.copyWith(remoteRenderer: state.remoteRenderer);
        }
      };

      // Fallback for Unified Plan (though onTrack is standard)
      pc.onAddStream = (MediaStream stream) {
        print("[WebRTC] Stream added: ${stream.id}");
        print("[SYSTEM] Target stream received. Ready for injection.");
        state.remoteRenderer.srcObject = stream;
        state = state.copyWith(remoteRenderer: state.remoteRenderer);
      };

      state = state.copyWith(peerConnection: pc);

      if (state.isCameraReady && state.localRenderer.srcObject != null) {
        pc.addStream(state.localRenderer.srcObject!);
      }
    } catch (e) {
      print("[WebRTC] Error creating PeerConnection: $e");
    }
  }

  Future<void> startCall(IO.Socket socket) async {
    if (state.peerConnection == null) return;
    try {
      RTCSessionDescription offer = await state.peerConnection!.createOffer();
      await state.peerConnection!.setLocalDescription(offer);

      print("[WebRTC] Sending Offer");
      socket.emit('offer', {'sdp': offer.sdp, 'type': offer.type});
    } catch (e) {
      print("[WebRTC] Error starting call: $e");
    }
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

      socket.emit('answer', {'sdp': answer.sdp, 'type': answer.type});
    } catch (e) {
      print("[WebRTC] Error handling offer: $e");
    }
  }

  Future<void> handleAnswer(Map<String, dynamic> answerData) async {
    if (state.peerConnection == null) return;
    try {
      RTCSessionDescription description =
          RTCSessionDescription(answerData['sdp'], answerData['type']);
      await state.peerConnection!.setRemoteDescription(description);
    } catch (e) {
      print("[WebRTC] Error handling answer: $e");
    }
  }

  Future<void> handleCandidate(Map<String, dynamic> candidateData) async {
    if (state.peerConnection == null) return;
    try {
      RTCIceCandidate candidate = RTCIceCandidate(candidateData['candidate'],
          candidateData['sdpMid'], candidateData['sdpMLineIndex']);
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
        // Offload decoding to isolate using compute
        final Uint8List bytes = await compute(decodeImageTask, base64Str);
        state = state.copyWith(deepfakeFrame: bytes);
        // print("[WebRTC] Deepfake frame updated."); // Reduce log spam
      } else {
        print(
            "[WebRTC] Attack complete event received but no image data found.");
      }
    } catch (e) {
      print("[WebRTC] Error decoding/updating frame: $e");
      // Do not update state, keeping last frame
    }
  }
}

final webRTCProvider = NotifierProvider<WebRTCNotifier, WebRTCState>(() {
  return WebRTCNotifier();
});
