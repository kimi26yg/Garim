import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'video_feed_section.dart';
import 'control_sidebar.dart';
import 'providers/socket_provider.dart';
import 'providers/webrtc_provider.dart';
import 'providers/attack_asset_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Defer to next frame to ensure providers are ready and we don't trigger state updates during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSignaling();
    });
  }

  void _setupSignaling() {
    final socketNotifier = ref.read(socketProvider.notifier);
    final webRTCNotifier = ref.read(webRTCProvider.notifier);
    final socket = socketNotifier.socket;

    // Use Protocol v1.1 Listeners
    webRTCNotifier.setupSignalListeners(socket);
  }

  @override
  Widget build(BuildContext context) {
    final socketState = ref.watch(socketProvider);
    final socketNotifier = ref.read(socketProvider.notifier);

    // Reset source uploaded status when image changes
    ref.listen(attackAssetProvider, (previous, next) {
      if (previous?.imageBytes != next.imageBytes) {
        socketNotifier.resetSourceUploadedStatus();
      }
    });

    // LOOP: Listen for new deepfake frames and trigger next capture if active
    ref.listen(socketProvider, (previous, next) {
      // Trigger next frame when we receive a processed image
      if (previous?.processedImage != next.processedImage &&
          next.processedImage != null) {
        if (next.isDeepfakeActive) {
          _captureAndEmit(context, ref);
        }
      }
    });

    // LISTENER: Show Incoming Call Dialog
    ref.listen(webRTCProvider, (previous, next) {
      if (previous?.callStatus != CallStatus.incoming &&
          next.callStatus == CallStatus.incoming) {
        _showIncomingCallDialog(context, ref, next.targetPhoneNumber);
      }
    });

    // LISTENER: Close dialog if call status changes from incoming (e.g. cancelled by caller)
    ref.listen(webRTCProvider, (previous, next) {
      if (previous?.callStatus == CallStatus.incoming &&
          next.callStatus != CallStatus.incoming) {
        // If a dialog is open, maybe close it?
        // This is tricky without a key or context handle, but often we can just pop.
        // For now, assume user interaction or self-dismiss logic handles it, or check if top route is dialog.
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route is! PopupRoute);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      // AppBar Removed as per instructions
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Desktop / Wide Mode
          if (constraints.maxWidth > 900) {
            return Row(
              children: [
                // 1. LEFT PANEL (Controls & Monitor)
                SizedBox(
                  width: 450,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101010),
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SourceIdentityPanel(),
                        const SizedBox(height: 16),
                        const AttackControlsPanel(),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                LatencyGraph(
                                    history: socketState.latencyHistory),
                                const SizedBox(height: 16),
                                TerminalLogs(logs: socketState.logs),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. CENTER PANEL (Video Feed)
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.black,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    child: const Center(child: VideoFeedSection()),
                  ),
                ),

                // 3. RIGHT PANEL (Station Identity & Dialer)
                Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101010),
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  child: const ControlSidebar(),
                ),
              ],
            );
          } else {
            // Mobile Mode (Linear Stack)
            return SingleChildScrollView(
              child: Column(
                children: [
                  // Video Feed (Top)
                  Container(
                    color: Colors.black,
                    height: 500,
                    width: double.infinity,
                    child: const Center(child: VideoFeedSection()),
                  ),
                  const Divider(height: 1, color: Colors.grey),

                  // Left Panel Content (Middle)
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        const SourceIdentityPanel(),
                        const SizedBox(height: 16),
                        const AttackControlsPanel(),
                        const SizedBox(height: 16),
                        SizedBox(
                            height: 200,
                            child: LatencyGraph(
                                history: socketState.latencyHistory)),
                        const SizedBox(height: 16),
                        SizedBox(
                            height: 200,
                            child: TerminalLogs(logs: socketState.logs)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.grey),

                  // Right Panel Content (Bottom)
                  const ControlSidebar(),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _captureAndEmit(BuildContext context, WidgetRef ref) async {
    final socketNotifier = ref.read(socketProvider.notifier);
    final assetState = ref.read(attackAssetProvider);
    final webRTCState = ref.read(webRTCProvider);
    // videoKeyProvider is exported by webrtc_provider.dart
    final videoKey = ref.read(videoKeyProvider);

    if (assetState.imageBytes == null) {
      socketNotifier.emit("log_local", "ERROR: Select Source Image first!");
      socketNotifier.setDeepfakeActive(false);
      return;
    }

    if (!webRTCState.isCameraReady) {
      socketNotifier.emit(
          "log_local", "ERROR: Camera not ready! Cannot capture frame.");
      socketNotifier.setDeepfakeActive(false);
      return;
    }

    try {
      RenderRepaintBoundary? boundary =
          videoKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary != null) {
        ui.Image image = await boundary.toImage();
        ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          Uint8List frameBytes = byteData.buffer.asUint8List();
          socketNotifier.emitDeepfake(
            sourceBytes: assetState.imageBytes!,
            targetBytes: frameBytes,
          );
        } else {
          socketNotifier.emit(
              "log_local", "ERROR: Failed to convert frame to bytes");
        }
      }
    } catch (e) {
      print("[Capture] Exception: $e");
      socketNotifier.emit("log_local", "ERROR: Frame capture failed: $e");
    }
  }

  void _showIncomingCallDialog(
      BuildContext context, WidgetRef ref, String? callerId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.greenAccent, width: 2)),
          title: const Text(
            "INCOMING CALL",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_in_talk, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                callerId ?? "Unknown Caller",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                ref.read(webRTCProvider.notifier).rejectCall(
                      ref.read(socketProvider.notifier),
                    );
              },
              icon: const Icon(Icons.call_end),
              label: const Text("REJECT"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(webRTCProvider.notifier).acceptCall(
                      ref.read(socketProvider.notifier),
                    );
              },
              icon: const Icon(Icons.call),
              label: const Text("ACCEPT"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );
  }
}
