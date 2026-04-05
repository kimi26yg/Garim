import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

class SocketService {
  socket_io.Socket? _socket;

  // Callbacks
  Function(Map<String, dynamic>)? onIncomingCall;
  Function(Map<String, dynamic>)? onOffer;
  Function(Map<String, dynamic>)? onAnswer;
  Function(Map<String, dynamic>)? onIceCandidate;
  Function(Map<String, dynamic>)? onHangup;

  static const String _serverUrl =
      'https://garim-signaling-server-production.up.railway.app';
  static const String _myPhoneNumber = '010-1234-5678'; // Fixed for demo

  void init() {
    _socket = socket_io.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket?.connect();

    _socket?.onConnect((_) {
      debugPrint('Socket Connected: ${_socket?.id}');
      _registerPhone();
    });

    _socket?.on('call:request', (data) {
      debugPrint('Received call:request: $data');
      final map = _ensureMap(data);
      // Ensure the call is for me (normalized check)
      final target = _normalize(map['to']);
      final me = _normalize(_myPhoneNumber);

      if (target.isEmpty || target == me) {
        onIncomingCall?.call(map);
      } else {
        debugPrint('Ignored call:request for $target (I am $me)');
      }
    });

    _socket?.on('webrtc:offer', (data) {
      debugPrint('Received webrtc:offer: $data');
      onOffer?.call(_ensureMap(data));
    });

    _socket?.on('webrtc:answer', (data) {
      debugPrint('Received webrtc:answer: $data');
      onAnswer?.call(_ensureMap(data));
    });

    _socket?.on('webrtc:ice', (data) {
      debugPrint('Received webrtc:ice: $data');
      onIceCandidate?.call(_ensureMap(data));
    });

    _socket?.on('call:hangup', (data) {
      debugPrint('Received call:hangup: $data');
      onHangup?.call(_ensureMap(data));
    });
  }

  void _registerPhone() {
    final normalized = _normalize(_myPhoneNumber);
    debugPrint('Registering phone number: $normalized');
    _socket?.emit('register:phone', {'phoneNumber': normalized});
  }

  void sendCallRequest({
    required String to,
    required String room,
    String? callerName,
  }) {
    final payload = {
      'from': _normalize(_myPhoneNumber),
      'to': _normalize(to),
      'room': room,
      'callerName': callerName ?? 'Garim User',
    };
    debugPrint('Sending call:request: $payload');
    _socket?.emit('call:request', payload);
  }

  void sendCallResponse({required String to, required String status}) {
    final payload = {
      'from': _normalize(_myPhoneNumber),
      'to': _normalize(to), // Respond to the caller (normalized)
      'status': status,
    };
    debugPrint('Sending call:response: $payload');
    _socket?.emit('call:response', payload);
  }

  void sendOffer(Map<String, dynamic> offerData) {
    var payload = Map<String, dynamic>.from(offerData);
    if (payload.containsKey('from'))
      payload['from'] = _normalize(payload['from']);
    if (payload.containsKey('to')) payload['to'] = _normalize(payload['to']);
    _socket?.emit('webrtc:offer', payload);
  }

  void sendAnswer(Map<String, dynamic> answerData) {
    var payload = Map<String, dynamic>.from(answerData);
    if (payload.containsKey('from'))
      payload['from'] = _normalize(payload['from']);
    if (payload.containsKey('to')) payload['to'] = _normalize(payload['to']);
    _socket?.emit('webrtc:answer', payload);
  }

  void sendIce(Map<String, dynamic> candidateData) {
    var payload = Map<String, dynamic>.from(candidateData);
    if (payload.containsKey('from'))
      payload['from'] = _normalize(payload['from']);
    if (payload.containsKey('to')) payload['to'] = _normalize(payload['to']);
    _socket?.emit('webrtc:ice', payload);
  }

  void sendHangup({required String to, required String reason}) {
    _socket?.emit('call:hangup', {
      'from': _normalize(_myPhoneNumber),
      'to': _normalize(to),
      'reason': reason,
    });
  }

  String _normalize(String? phone) {
    return phone?.replaceAll('-', '') ?? '';
  }

  Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is List && data.isNotEmpty) {
      return Map<String, dynamic>.from(data[0] as Map);
    } else if (data is Map) {
      return Map<String, dynamic>.from(data);
    } else if (data is String) {
      // Should parse JSON if string, but assuming object for now based on typical socket.io
      debugPrint('Warning: Received String data, expected Map: $data');
      return {};
    }
    return {};
  }

  String get myPhoneNumber => _myPhoneNumber;

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
  }
}
