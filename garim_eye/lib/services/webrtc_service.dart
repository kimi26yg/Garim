import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef StreamStateCallback = void Function(MediaStream stream);
typedef IceCandidateCallback =
    void Function(RTCIceCandidate candidate, String? roomId);

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  StreamStateCallback? onLocalStream;
  StreamStateCallback? onRemoteStream;
  IceCandidateCallback? onIceCandidate;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
      },
    ],
  };

  Future<void> startLocalStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {'facingMode': 'user'},
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      onLocalStream?.call(_localStream!);
    } catch (e) {
      debugPrint('Error getting user media: $e');
    }
  }

  Future<void> initializePeerConnection(String roomId) async {
    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      onIceCandidate?.call(candidate, roomId);
    };

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      debugPrint('WebRTC: onTrack - kind: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams[0]);
      }
    };

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });
  }

  Future<RTCSessionDescription> createOffer() async {
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  Future<void> addCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  void dispose() {
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream?.dispose();
    _localStream = null;

    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;
  }
}
