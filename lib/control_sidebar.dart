import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'providers/socket_provider.dart';
import 'providers/attack_asset_provider.dart';
import 'providers/webrtc_provider.dart';

// --- MAIN RIGHT SIDEBAR ---
class ControlSidebar extends ConsumerStatefulWidget {
  const ControlSidebar({super.key});

  @override
  ConsumerState<ControlSidebar> createState() => _ControlSidebarState();
}

class _ControlSidebarState extends ConsumerState<ControlSidebar> {
  late TextEditingController _targetController;

  @override
  void initState() {
    super.initState();
    _targetController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socketState = ref.watch(socketProvider);
    final myPhone = socketState.myPhoneNumber ?? "UNKNOWN";

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. STATION IDENTITY (Replaces Server Config)
          const SectionHeader(title: "STATION NUMBER"),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.05),
              border:
                  Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                const Icon(Icons.security, color: Colors.greenAccent, size: 30),
                const SizedBox(height: 8),
                Text(
                  myPhone,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. SECURE DIALER
          const SectionHeader(title: "SECURE DIALER"),
          const SizedBox(height: 12),
          // Display Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _targetController.text.isEmpty
                  ? "010-XXXX-XXXX"
                  : _formatPhoneNumber(_targetController.text),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontFamily: 'Courier',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Keypad
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            childAspectRatio: 1.5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ...List.generate(9, (index) => index + 1)
                  .map((e) => _buildNumpadButton(context, e.toString())),
              _buildActionButton(context, "CLR", Colors.redAccent, () {
                _targetController.clear();
                setState(() {});
              }),
              _buildNumpadButton(context, "0"),
              _buildActionButton(context, "CALL", Colors.greenAccent, () {
                final socketNotifier = ref.read(socketProvider.notifier);
                final targetPhone =
                    _formatRawPhoneNumber(_targetController.text);
                if (targetPhone.length == 11) {
                  ref.read(webRTCProvider.notifier).requestCall(
                        socketNotifier.socket,
                        targetPhone,
                        socketState.myPhoneNumber,
                      );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("INVALID NUMBER LENGTH")),
                  );
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  // --- DIAL PAD HELPERS ---
  String _formatPhoneNumber(String raw) {
    if (raw.isEmpty) {
      return "";
    }
    String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 3) return digits;
    if (digits.length <= 7)
      return "${digits.substring(0, 3)}-${digits.substring(3)}";
    return "${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, digits.length > 11 ? 11 : digits.length)}";
  }

  String _formatRawPhoneNumber(String raw) {
    return raw.replaceAll(RegExp(r'\D'), '');
  }

  void _onNumpadPress(String value) {
    if (_targetController.text.length >= 13) return;
    String currentRaw = _formatRawPhoneNumber(_targetController.text);
    if (currentRaw.length >= 11) return;
    _targetController.text = _formatPhoneNumber(currentRaw + value);
    setState(() {});
  }

  Widget _buildNumpadButton(BuildContext context, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: InkWell(
        onTap: () => _onNumpadPress(value),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier'),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, String label, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier'),
          ),
        ),
      ),
    );
  }
}

// --- EXTRACTED PANELS FOR LEFT SIDE ---

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
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

class SourceIdentityPanel extends ConsumerWidget {
  const SourceIdentityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetState = ref.watch(attackAssetProvider);
    final assetNotifier = ref.read(attackAssetProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: "SOURCE IDENTITY"),
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
      ],
    );
  }
}

class AttackControlsPanel extends ConsumerWidget {
  const AttackControlsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: "ATTACK CONTROLS"),
        const SizedBox(height: 16),
        // Deepfake Start/Stop
        ElevatedButton(
          onPressed: () {
            ref.read(webRTCProvider.notifier).toggleDeepfake();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: ref.watch(webRTCProvider).isDeepfakeActive
                ? Colors.redAccent
                : Theme.of(context).colorScheme.secondary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: Text(
            ref.watch(webRTCProvider).isDeepfakeActive
                ? "⚠ DEEPFAKE STOP ⚠"
                : "⚠ DEEPFAKE START ⚠",
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
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
                isActive: ref.watch(webRTCProvider).isMosaicActive,
                onPressed: () =>
                    ref.read(webRTCProvider.notifier).toggleMosaic(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                context: context,
                label: "BEAUTY [MDPIPE]",
                isActive: ref.watch(webRTCProvider).isBeautyActive,
                onPressed: () =>
                    ref.read(webRTCProvider.notifier).toggleBeauty(),
              ),
            ),
          ],
        ),
      ],
    );
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
}

class LatencyGraph extends StatelessWidget {
  final List<int> history;
  const LatencyGraph({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    // ... (Keep existing implementation logic but wrapped properly)
    // For brevity in this thought trace, I will use the code from previous step.
    if (history.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: "NETWORK LATENCY"),
          const SizedBox(height: 10),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                "NO DATA",
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.5),
                    fontSize: 10),
              ),
            ),
          ),
        ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: "NETWORK LATENCY"),
        const SizedBox(height: 10),
        Container(
          height: 200,
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
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 30)),
                  bottomTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false))),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 29,
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
        ),
      ],
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
    if (widget.logs.length != oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: "TERMINAL LOGS"),
        const SizedBox(height: 10),
        Container(
          height: 250,
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
        ),
      ],
    );
  }
}
