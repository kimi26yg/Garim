import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class FrameExtractor {
  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();
  bool _isExtracting = false;

  Stream<Uint8List> get frameStream => _frameController.stream;

  /// Starts extracting frames from the given [track].
  Future<void> startExtraction(MediaStreamTrack track) async {
    if (_isExtracting) return;
    _isExtracting = true;
    // debugPrint("[FrameExtractor] Starting extraction on track ${track.id}");

    // Start extraction loop WITHOUT await to run in parallel
    _extractionLoop(track);
  }

  Future<void> _extractionLoop(MediaStreamTrack track) async {
    int frameCount = 0;
    final loopStart = DateTime.now();

    while (_isExtracting) {
      final start = DateTime.now();
      try {
        // Strategy D: captureFrame returns ByteBuffer (PNG encoded usually)
        dynamic result = await track.captureFrame();

        if (result is ByteBuffer) {
          frameCount++;
          _frameController.add(result.asUint8List());

          // Log every 20 frames to track FPS
          // if (frameCount % 20 == 0) {
          //   final totalSeconds =
          //       DateTime.now().difference(loopStart).inMilliseconds / 1000.0;
          //   final actualFps = frameCount / totalSeconds;
          //   debugPrint(
          //     "[FrameExtractor] Captured $frameCount frames in ${totalSeconds.toStringAsFixed(1)}s (${actualFps.toStringAsFixed(1)} FPS)",
          //   );
          // }
        } else if (result is List<int>) {
          frameCount++;
          _frameController.add(Uint8List.fromList(result));
        } else {
          // debugPrint(
          //   "[FrameExtractor] ⚠️ Unexpected result type: ${result.runtimeType}",
          // );
        }
      } catch (e) {
        // debugPrint("[FrameExtractor] ❌ Capture error: $e");
      }

      final elapsed = DateTime.now().difference(start).inMilliseconds;
      // Target ~20 FPS (50ms interval). Adjust delay based on processing time.
      final delay = (50 - elapsed).clamp(5, 50);

      // Debug slow captures
      // if (elapsed > 30) {
      //   debugPrint(
      //     "[FrameExtractor] ⚠️ Slow capture: ${elapsed}ms (delay: ${delay}ms)",
      //   );
      // }

      await Future.delayed(Duration(milliseconds: delay));
    }

    // debugPrint(
    //   "[FrameExtractor] Loop ended. Total frames captured: $frameCount",
    // );
  }

  void stopExtraction() {
    _isExtracting = false;
    // debugPrint("[FrameExtractor] Stopped extraction");
  }

  void dispose() {
    stopExtraction();
    _frameController.close();
  }
}
