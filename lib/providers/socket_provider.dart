import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image/image.dart' as img;
import 'face_detection_provider.dart';

// Top-level function for compute
Future<Uint8List> decodeImageTask(String base64Str) async {
  try {
    if (base64Str.contains(',')) {
      base64Str = base64Str.split(',').last;
    }
    return base64Decode(base64Str);
  } catch (e) {
    if (kDebugMode) {
      print("Decoding error: $e");
    }
    return Uint8List(0);
  }
}

// Top-level function for compute - send full frame to server
// Resizes to 50% and compresses with JPEG quality 50
Future<String> compressImageTask(Uint8List bytes) async {
  try {
    // Decode image
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return base64Encode(bytes); // Fallback

    // Resize to 50% (0.5x scale) for bandwidth optimization
    final newWidth = (decoded.width * 0.5).toInt();
    final newHeight = (decoded.height * 0.5).toInt();
    decoded = img.copyResize(decoded, width: newWidth, height: newHeight);

    // Encode to JPG with quality 50 (optimized for upload speed)
    Uint8List jpgBytes = img.encodeJpg(decoded, quality: 50);
    return base64Encode(jpgBytes);
  } catch (e) {
    if (kDebugMode) {
      print("[Socket Isolate] Compression Error: $e");
    }
    return base64Encode(bytes); // Fallback
  }
}

// State class to hold socket status
class SocketState {
  final bool isConnected;
  final List<String> logs; // Changed from lastLog
  final bool isDeepfakeActive;
  final List<int> latencyHistory; // New
  final double serverFps;
  final double serverInferenceTime;
  final String serverUrl;
  final String roomId; // New
  final bool isMosaicActive;
  final bool isBeautyActive;
  final Uint8List? processedImage;
  final String? myPhoneNumber;

  SocketState({
    this.isConnected = false,
    this.logs = const [],
    this.isDeepfakeActive = false,
    this.latencyHistory = const [],
    this.serverFps = 0.0,
    this.serverInferenceTime = 0.0,
    this.serverUrl = 'https://garim-signaling-server-production.up.railway.app',
    this.roomId = 'garim_room',
    this.isMosaicActive = false,
    this.isBeautyActive = false,
    this.processedImage,
    this.myPhoneNumber,
  });

  SocketState copyWith({
    bool? isConnected,
    List<String>? logs,
    bool? isDeepfakeActive,
    List<int>? latencyHistory,
    double? serverFps,
    double? serverInferenceTime,
    String? serverUrl,
    String? roomId,
    bool? isMosaicActive,
    bool? isBeautyActive,
    Uint8List? processedImage,
    String? myPhoneNumber,
  }) {
    return SocketState(
        isConnected: isConnected ?? this.isConnected,
        logs: logs ?? this.logs,
        isDeepfakeActive: isDeepfakeActive ?? this.isDeepfakeActive,
        latencyHistory: latencyHistory ?? this.latencyHistory,
        serverFps: serverFps ?? this.serverFps,
        serverInferenceTime: serverInferenceTime ?? this.serverInferenceTime,
        serverUrl: serverUrl ?? this.serverUrl,
        roomId: roomId ?? this.roomId,
        isMosaicActive: isMosaicActive ?? this.isMosaicActive,
        isBeautyActive: isBeautyActive ?? this.isBeautyActive,
        processedImage: processedImage ?? this.processedImage,
        myPhoneNumber: myPhoneNumber ?? this.myPhoneNumber);
  }

  // Helper to get last log for simple display if needed
  String get lastLog => logs.isNotEmpty ? logs.last : "";
}

class SocketNotifier extends Notifier<SocketState> {
  late IO.Socket _socket;
  Timer? _reconnectTimer;
  Timer? _timeoutTimer; // Watchdog timer for 3-second timeout
  bool _isSourceUploaded = false;
  bool _isProcessing = false;
  DateTime? _lastEmitTime; // For latency calculation

  @override
  SocketState build() {
    // 1. Generate Virtual Number
    final randomPart = (1000 + (DateTime.now().microsecond % 9000)).toString();
    final myPhone = "0108293$randomPart";

    // 2. Schedule Socket Initialization after build
    Future.microtask(() => _initSocket(
        'https://garim-signaling-server-production.up.railway.app'));

    ref.onDispose(() {
      _reconnectTimer?.cancel();
      if (_socket.connected) {
        _socket.disconnect();
      }
      _socket.dispose();
    });

    // 3. Return Initial State
    return SocketState(myPhoneNumber: myPhone);
  }

  void addLog(String msg) {
    final newLogs = List<String>.from(state.logs)..add(msg);
    if (newLogs.length > 100) newLogs.removeAt(0); // Limit to 100
    state = state.copyWith(logs: newLogs);
  }

  void updateServerStats(double fps, double inferenceTime) {
    state = state.copyWith(serverFps: fps, serverInferenceTime: inferenceTime);
  }

  void setServerUrl(String url) {
    if (state.serverUrl == url) return;

    addLog("[SYSTEM] Changing Server URL to: $url");
    state = state.copyWith(serverUrl: url, isConnected: false);

    // Disconnect old socket
    _reconnectTimer?.cancel();
    if (_socket.connected) {
      _socket.disconnect();
    }
    _socket.dispose();

    // Re-init with new URL
    _initSocket(url);
  }

  void toggleMosaic() {
    state = state.copyWith(isMosaicActive: !state.isMosaicActive);
    addLog("[SYSTEM] Mosaic Effect: ${state.isMosaicActive ? 'ON' : 'OFF'}");
  }

  void toggleBeauty() {
    state = state.copyWith(isBeautyActive: !state.isBeautyActive);
    addLog("[SYSTEM] Beauty Effect: ${state.isBeautyActive ? 'ON' : 'OFF'}");
  }

  void _initSocket([String? overrideUrl]) {
    // If overrideUrl is provided (e.g. during build), use it.
    // Otherwise try to read from state (only safe after build).
    // During build, we pass standard localhost url.
    String url = overrideUrl ??
        'https://garim-signaling-server-production.up.railway.app';
    try {
      // Try to read state if no override, but wrap in try-catch or just rely on logic
      if (overrideUrl == null) {
        url = state.serverUrl;
      }
    } catch (e) {
      // If state read fails (shouldn't if logic is correct), fallback
      url = 'https://garim-signaling-server-production.up.railway.app';
    }

    _socket = IO.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'connectTimeout': 10000, // 10s timeout
    });

    _socket.onConnect((_) {
      _reconnectTimer?.cancel();
      state = state.copyWith(isConnected: true);
      addLog("[SOCKET] Connected to signaling server at ${state.serverUrl}");

      // Join the matching room
      _socket.emit('join', {'room': state.roomId});

      // Virtual Number Registration
      if (state.myPhoneNumber != null) {
        _socket.emit('register:phone', {'phoneNumber': state.myPhoneNumber});
        addLog("[SOCKET] Registered Virtual Number: ${state.myPhoneNumber}");
      }

      addLog("[SOCKET] Joined room: ${state.roomId}");
    });

    _socket.onDisconnect((_) {
      _isProcessing = false; // Reset processing flag
      state = state.copyWith(isConnected: false);
      addLog("[SOCKET] Disconnected. Reconnecting in 3s...");

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        print("[SOCKET] Attempting auto-reconnect...");
        connect();
      });
    });

    _socket.onConnectError((data) {
      _isProcessing = false; // Reset
      addLog("[SOCKET] Connection Error: $data");
    });

    _socket.onError((data) {
      _isProcessing = false; // Reset
      addLog("[SOCKET] Transport Error: $data");
    });

    _socket.on('attack_complete', _handleAttackComplete);

    connect();
  }

  void connect() {
    _reconnectTimer?.cancel();
    if (!_socket.connected) {
      _socket.connect();
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    if (_socket.connected) {
      _socket.disconnect();
    }
  }

  void emit(String event, dynamic data) {
    if (_socket.connected) {
      _socket.emit(event, data);
      addLog("[CMD] Emitted: $event");
    } else {
      addLog("[ERROR] Cannot emit $event - Disconnected");
    }
  }

  void on(String event, Function(dynamic) callback) {
    _socket.on(event, callback);
  }

  void resetSourceUploadedStatus() {
    _isSourceUploaded = false;
    addLog("[SYSTEM] Source Identity Changed. Will re-upload.");
  }

  void setDeepfakeActive(bool isActive) {
    state = state.copyWith(isDeepfakeActive: isActive);
    if (!isActive) {
      addLog("[SYSTEM] Deepfake Deactivated.");
    } else {
      addLog("[SYSTEM] Deepfake ACTIVATED. Starting loop...");
    }
  }

  Future<void> _handleAttackComplete(dynamic data) async {
    try {
      // [UNWRAPPING] Handle Socket.IO data that comes as List [{...}]
      Map<String, dynamic> payload;

      if (data is List) {
        if (data.isEmpty) {
          addLog("[ERROR] Empty data list received");
          if (kDebugMode) print("[Socket] Received empty list from server");
          return;
        }
        // Extract first element from list and convert to Map
        payload = Map<String, dynamic>.from(data[0] as Map);
        if (kDebugMode) print("[Socket] Unwrapped data from List to Map");
      } else if (data is Map) {
        // Safely convert to Map<String, dynamic>
        payload = Map<String, dynamic>.from(data);
        if (kDebugMode) print("[Socket] Converted data to Map");
      } else if (data is String) {
        // Handle string data (legacy base64 format)
        payload = {'image': data};
        if (kDebugMode) print("[Socket] Wrapped string data in Map");
      } else {
        addLog("[ERROR] Unknown data type: ${data.runtimeType}");
        if (kDebugMode)
          print("[Socket] Unexpected data type: ${data.runtimeType}");
        return;
      }

      // Cancel timeout timer since we received a response
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _isProcessing = false; // Reset flag to allow next frame

      recordLatency();

      // Extract data from payload
      double fps = (payload['fps'] ?? 0).toDouble();
      double inferenceTime = (payload['inference_time'] ?? 0).toDouble();

      String? base64Str;
      if (payload.containsKey('processed_image')) {
        base64Str = payload['processed_image'];
      } else if (payload.containsKey('image')) {
        base64Str = payload['image'];
      }

      List<dynamic>? faceRect;
      double? imageWidth;
      double? imageHeight;

      // Parse face coordinates from server
      // Server sends face_rect as List: [x, y, w, h]
      if (payload.containsKey('face_rect')) {
        final rawFaceRect = payload['face_rect'];
        if (rawFaceRect is List) {
          faceRect = rawFaceRect;
          if (kDebugMode) print("[Socket] face_rect parsed as List: $faceRect");
        } else {
          if (kDebugMode)
            print(
                "[Socket] face_rect is not a List, type: ${rawFaceRect.runtimeType}");
          faceRect = null;
        }
      }
      if (payload.containsKey('image_width')) {
        imageWidth = (payload['image_width'] ?? 0).toDouble();
      }
      if (payload.containsKey('image_height')) {
        imageHeight = (payload['image_height'] ?? 0).toDouble();
      }

      state =
          state.copyWith(serverFps: fps, serverInferenceTime: inferenceTime);

      // Update face detection state if server provided coordinates
      if (faceRect != null && faceRect.length >= 4) {
        try {
          // Scale factor: 2.0 (to compensate for 50% resize during upload)
          const double scale = 2.0;

          // Extract values from List: [x, y, w, h] and apply scale
          final rect = Rect.fromLTWH(
            (faceRect[0] as num).toDouble() * scale, // x * 2
            (faceRect[1] as num).toDouble() * scale, // y * 2
            (faceRect[2] as num).toDouble() * scale, // width * 2
            (faceRect[3] as num).toDouble() * scale, // height * 2
          );

          // Use provided image size or fallback to typical webcam resolution
          // Typical webcam: 640x480 -> after 50% resize: 320x240 -> after 2x scale back: 640x480
          // But we're using 2x scale, so fallback to 1280x960 (common 4:3 aspect)
          final finalImageSize = Size(
            imageWidth != null ? imageWidth * scale : 1280.0,
            imageHeight != null ? imageHeight * scale : 960.0,
          );

          ref.read(faceDetectionProvider.notifier).updateFaceRect(
                rect,
                finalImageSize,
              );
          print(
              "[Server] Face rect received (scaled 2x): $rect, imageSize: $finalImageSize");
        } catch (e) {
          // Fallback to Rect.zero on parsing error
          if (kDebugMode)
            print("[Socket] Error creating Rect from face_rect: $e");
          ref.read(faceDetectionProvider.notifier).updateFaceRect(
                Rect.zero,
                Size(1280, 960),
              );
        }
      }

      if (base64Str != null) {
        try {
          // Remove Base64 header if present (e.g., "data:image/jpeg;base64,")
          String cleanBase64 = base64Str;
          if (cleanBase64.contains(',')) {
            cleanBase64 = cleanBase64.split(',').last;
          }

          final Uint8List bytes = await compute(decodeImageTask, cleanBase64);
          if (bytes.isNotEmpty) {
            state = state.copyWith(processedImage: bytes);
            addLog("[UI] Frame Updated");
          } else {
            addLog("[ERROR] Received empty image data");
            if (kDebugMode) print("[Decode] Empty bytes after decoding");
          }
        } catch (e) {
          addLog("[ERROR] Image decode failed: ${e.toString()}");
          if (kDebugMode) {
            print("[Decode] Error decoding image: $e");
            print("[Decode] Base64 length: ${base64Str.length}");
          }
        }
      }
    } catch (e, stackTrace) {
      // Catch-all for any unexpected errors in _handleAttackComplete
      addLog("[ERROR] Attack complete handler failed: ${e.toString()}");
      if (kDebugMode) {
        print("[CRITICAL] _handleAttackComplete error: $e");
        print("[CRITICAL] Stack trace: $stackTrace");
      }
      // Ensure processing flag is reset even on error
      _isProcessing = false;
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
    }
  }

  void recordLatency() {
    if (_lastEmitTime == null) return;
    final latency = DateTime.now().difference(_lastEmitTime!).inMilliseconds;

    final newHistory = List<int>.from(state.latencyHistory)..add(latency);
    if (newHistory.length > 30) newHistory.removeAt(0); // Keep last 30 points

    state = state.copyWith(latencyHistory: newHistory);
    // Optional: Log latency occasionally or just rely on graph
    // addLog("[LATENCY] ${latency}ms");
  }

  Future<void> emitDeepfake({
    required Uint8List sourceBytes,
    required Uint8List targetBytes,
  }) async {
    if (!_socket.connected) {
      addLog("[ERROR] Cannot emit deepfake - Disconnected");
      return;
    }

    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Compress full frame (50% resize + quality 80)
      String targetBase64 = await compute(compressImageTask, targetBytes);

      Map<String, dynamic> payload = {
        'type': 'deepfake',
        'target_frame': targetBase64,
        'status': true,
        'mosaic': state.isMosaicActive,
        'beauty': state.isBeautyActive,
      };

      if (!_isSourceUploaded) {
        // First frame: Include source image
        String sourceBase64 = await compute(compressImageTask, sourceBytes);
        payload['source_image'] = sourceBase64;
        payload['image'] = sourceBase64;
        _isSourceUploaded = true;
        addLog("[SOCKET] Sending FULL Payload (Source + Target)");
        if (kDebugMode) {
          print(
              '[Socket] FULL Payload - Source: ${sourceBytes.length} -> ${sourceBase64.length}, Target: ${targetBytes.length} -> ${targetBase64.length}');
        }
      } else {
        // Subsequent frames: Target only (source already uploaded)
        addLog("[SOCKET] Sending LIGHT Payload (Target only)");
        if (kDebugMode) {
          print(
              '[Socket] LIGHT Payload - Target only: ${targetBytes.length} -> ${targetBase64.length}');
        }
      }

      _lastEmitTime = DateTime.now(); // Start latency timer
      _socket.emit('attack_start', payload);

      // Start 3-second timeout watchdog
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (_isProcessing) {
          addLog("[TIMEOUT] No response in 3s - Retrying");
          if (kDebugMode) {
            print("[Watchdog] Timeout detected - forcing retry");
          }
          _isProcessing = false; // Reset flag to allow next frame
          _timeoutTimer = null;
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print("[Socket] Error in emitDeepfake: $e");
      }
      addLog("[ERROR] Deepfake Emit Failed");
    } finally {
      // Don't reset _isProcessing here - let timeout or response handle it
      // _isProcessing = false;
    }
  }

  IO.Socket get socket => _socket;
}

final socketProvider = NotifierProvider<SocketNotifier, SocketState>(() {
  return SocketNotifier();
});
