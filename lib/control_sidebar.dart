import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart
import 'providers/socket_provider.dart';
import 'providers/attack_asset_provider.dart';
import 'providers/webrtc_provider.dart';

class ControlSidebar extends ConsumerStatefulWidget {
  const ControlSidebar({super.key});

  @override
  ConsumerState<ControlSidebar> createState() => _ControlSidebarState();
}

class _ControlSidebarState extends ConsumerState<ControlSidebar> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: 'http://localhost:3000');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socketState = ref.watch(socketProvider);
    final socketNotifier = ref.read(socketProvider.notifier);

    final assetState = ref.watch(attackAssetProvider);
    final assetNotifier = ref.read(attackAssetProvider.notifier);

    // Sync controller with state if needed, or just let user type.
    // Ideally we might want to update controller if state.serverUrl changes externally,
    // but for now local control is fine.

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
          print("[Loop] Received frame, sending next frame...");
          _captureAndEmit(context, ref);
        }
      }
    });

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 0. Server Configuration
            _buildSectionHeader(context, "SERVER CONFIG"),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'Courier',
                        fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary)),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.5))),
                      labelText: "Server URL",
                      labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    socketNotifier.setServerUrl(_urlController.text);
                  },
                  style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary),
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  tooltip: "Connect",
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                ref
                    .read(webRTCProvider.notifier)
                    .startCall(socketNotifier.socket);
              },
              icon: const Icon(Icons.video_call),
              label: const Text("START VIDEO CALL"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 24),

            // 1. Image Selection Area
            _buildSectionHeader(context, "SOURCE IDENTITY"),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => assetNotifier.pickImage(),
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 1),
                  borderRadius: BorderRadius.circular(4),
                  color: Theme.of(context).colorScheme.surface,
                  image: assetState.imageBytes != null
                      ? DecorationImage(
                          image: MemoryImage(assetState.imageBytes!),
                          fit: BoxFit.cover,
                          opacity: 0.8,
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    if (assetState.imageBytes == null)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 32),
                            const SizedBox(height: 8),
                            Text(
                              "UPLOAD FACE IMAGE",
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    if (assetState.imageBytes != null)
                      Positioned(
                          top: 4,
                          right: 4,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 12,
                            child: Icon(Icons.check,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary),
                          ))
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. Control Buttons
            _buildSectionHeader(context, "ATTACK CONTROLS"),
            const SizedBox(height: 16),

            // Deepfake Start/Stop
            ElevatedButton(
              onPressed: () {
                final isActive = socketState.isDeepfakeActive;
                socketNotifier.setDeepfakeActive(!isActive);
                if (!isActive) {
                  _captureAndEmit(context, ref);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: socketState.isDeepfakeActive
                    ? Colors.redAccent
                    : Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(
                socketState.isDeepfakeActive
                    ? "⚠ DEEPFAKE STOP ⚠"
                    : "⚠ DEEPFAKE START ⚠",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5),
              ),
            ),
            const SizedBox(height: 12),

            // Mosaic & Beauty Buttons
            Row(
              children: [
                Expanded(
                  child: _buildToggleButton(
                    context: context,
                    label: "MOSAIC [STRESS]",
                    isActive: socketState.isMosaicActive,
                    onPressed: () => socketNotifier.toggleMosaic(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildToggleButton(
                    context: context,
                    label: "BEAUTY [MDPIPE]",
                    isActive: socketState.isBeautyActive,
                    onPressed: () => socketNotifier.toggleBeauty(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Network Stress
            _buildSectionHeader(context, "NETWORK LATENCY"),
            const SizedBox(height: 10),
            SizedBox(
              height: 200, // Increased height
              child: ClipRect(
                child: LatencyGraph(history: socketState.latencyHistory),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Log Console
            _buildSectionHeader(context, "TERMINAL LOGS"),
            const SizedBox(height: 10),
            SizedBox(
              height: 250, // Fixed height for scrollable area
              child: TerminalLogs(logs: socketState.logs),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureAndEmit(BuildContext context, WidgetRef ref) async {
    final socketNotifier = ref.read(socketProvider.notifier);
    final assetState = ref.read(attackAssetProvider);
    final webRTCState = ref.read(webRTCProvider);
    final videoKey = ref.read(videoKeyProvider);

    if (assetState.imageBytes == null) {
      socketNotifier.emit("log_local", "ERROR: Select Source Image first!");
      // If auto-looping but no image, maybe stop?
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
      // Capture Frame from Local Video
      RenderRepaintBoundary? boundary =
          videoKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary != null) {
        ui.Image image = await boundary.toImage(); // Capture as is
        ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          Uint8List frameBytes = byteData.buffer.asUint8List();

          print(
              "[Capture] Frame captured: ${frameBytes.length} bytes, sending to server...");

          // Send full frame to server - server will detect face and return coordinates
          socketNotifier.emitDeepfake(
            sourceBytes: assetState.imageBytes!,
            targetBytes: frameBytes,
          );
        } else {
          socketNotifier.emit(
              "log_local", "ERROR: Failed to convert frame to bytes");
        }
      } else {
        socketNotifier.emit(
            "log_local", "ERROR: Could not find Video RenderObject");
      }
    } catch (e) {
      print("[Capture] Exception: $e");
      socketNotifier.emit("log_local", "ERROR: Frame capture failed: $e");
    }
  }

  Widget _buildToggleButton({
    required BuildContext context,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          side: BorderSide(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withValues(alpha: 0.5),
            width: isActive ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isActive ? Theme.of(context).colorScheme.primary : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        border: Border(
            left: BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 4)),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class LatencyGraph extends StatelessWidget {
  final List<int> history;
  const LatencyGraph({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Text(
          "NO DATA",
          style: TextStyle(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              fontSize: 10),
        ),
      );
    }

    final points = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.toDouble());
    }).toList();

    Color lineColor = Colors.greenAccent;
    final last = history.last;
    if (last > 500) {
      lineColor = Colors.redAccent;
    } else if (last > 200) {
      lineColor = Colors.orangeAccent;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(8),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: const FlTitlesData(
              leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
              bottomTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false))),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 29, // Fixed window of 30
          minY: 0,
          maxY: 1000,
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              color: lineColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TerminalLogs extends StatefulWidget {
  final List<String> logs;
  const TerminalLogs({super.key, required this.logs});

  @override
  State<TerminalLogs> createState() => _TerminalLogsState();
}

class _TerminalLogsState extends State<TerminalLogs> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TerminalLogs oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to bottom when new logs arrive
    if (widget.logs.length != oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(
                milliseconds: 100), // Slightly longer for smooth effect
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: widget.logs.length,
        itemBuilder: (context, index) {
          final log = widget.logs[index];
          // Simple color coding
          Color color = Colors.greenAccent;
          if (log.contains("[ERROR]")) color = Colors.redAccent;
          if (log.contains("[CMD]")) color = Colors.blueAccent;
          if (log.contains("[LATENCY]")) color = Colors.yellowAccent;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SelectableText(
              "> $log",
              style: TextStyle(
                color: color,
                fontFamily: 'Courier',
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }
}
