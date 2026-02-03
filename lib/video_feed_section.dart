import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'providers/webrtc_provider.dart';
import 'providers/socket_provider.dart';
import 'providers/face_detection_provider.dart';

class VideoFeedSection extends ConsumerWidget {
  const VideoFeedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webRTCState = ref.watch(webRTCProvider);
    final socketState = ref.watch(socketProvider);
    final faceDetectionState = ref.watch(faceDetectionProvider);
    final videoKey = ref.read(videoKeyProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate actual video container size based on AspectRatio
        final containerWidth = constraints.maxWidth;
        final containerHeight = containerWidth * (16 / 9); // 9:16 aspect ratio

        return AspectRatio(
          aspectRatio: 9 / 16,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main Video Feed (Attacker Local) - Always visible at full quality
              RepaintBoundary(
                key: videoKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: webRTCState.isCameraReady
                      ? RTCVideoView(
                          webRTCState.localRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          mirror: false,
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "ATTACKER\n(LOADING)",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              // Deepfake Face Overlay (Positioned dynamically based on face detection)

              if (socketState.processedImage != null &&
                  faceDetectionState.faceRect != null)
                _buildFaceOverlay(
                  context,
                  socketState.processedImage!,
                  faceDetectionState.faceRect!,
                  faceDetectionState.imageSize!,
                  Size(containerWidth,
                      containerHeight), // Pass actual container size
                ),

              // Target Overlay (Remote Stream)
              Positioned(
                top: 16,
                right: 16,
                width: 120, // Could make this responsive
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondary,
                        width: 2,
                      ),
                    ),
                    child: webRTCState.remoteRenderer.srcObject != null
                        ? RTCVideoView(
                            webRTCState.remoteRenderer,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          )
                        : Center(
                            child: webRTCState.callStatus ==
                                    CallStatus.connecting
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "CONNECTING...",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    webRTCState.callStatus == CallStatus.failed
                                        ? "CONNECTION\nFAILED"
                                        : "TARGET\n(WAITING)",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: webRTCState.callStatus ==
                                              CallStatus.failed
                                          ? Colors.redAccent
                                          : Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                  ),
                ),
              ),

              // Overlay UI Elements
              _buildOverlayUI(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFaceOverlay(
    BuildContext context,
    Uint8List deepfakeImage,
    Rect faceRect,
    Size imageSize,
    Size containerSize, // Actual video container size
  ) {
    // Use container dimensions instead of MediaQuery
    final screenWidth = containerSize.width;
    final screenHeight = containerSize.height;

    // Map faceRect coordinates to screen space
    final scaleX = screenWidth / imageSize.width;
    final scaleY = screenHeight / imageSize.height;

    final screenLeft = faceRect.left * scaleX;
    final screenTop = faceRect.top * scaleY;
    final screenWidth2 = faceRect.width * scaleX;
    final screenHeight2 = faceRect.height * scaleY;

    return Positioned(
      left: screenLeft,
      top: screenTop,
      width: screenWidth2,
      height: screenHeight2,
      child: Image.memory(
        deepfakeImage,
        fit: BoxFit.fill,
        gaplessPlayback: true,
      ),
    );
  }

  Widget _buildOverlayUI(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration:
            BoxDecoration(border: Border.all(color: Colors.transparent)),
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 10,
              child: _buildCorner(context, true, true),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _buildCorner(context, true, false),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              child: _buildCorner(context, false, true),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: _buildCorner(context, false, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner(BuildContext context, bool top, bool left) {
    const double size = 20;
    const double thickness = 2;
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? BorderSide(color: color, width: thickness)
              : BorderSide.none,
          bottom: !top
              ? BorderSide(color: color, width: thickness)
              : BorderSide.none,
          left: left
              ? BorderSide(color: color, width: thickness)
              : BorderSide.none,
          right: !left
              ? BorderSide(color: color, width: thickness)
              : BorderSide.none,
        ),
      ),
    );
  }
}
