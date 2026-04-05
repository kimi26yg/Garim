import 'package:flutter/material.dart';
import '../services/detection/deepfake_inference_service.dart';

class DeepfakeInsightPanel extends StatelessWidget {
  final DeepfakeState state;
  final VoidCallback? onClose;

  const DeepfakeInsightPanel({Key? key, required this.state, this.onClose})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        border: Border(left: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildGaugeSection(),
          const Divider(color: Colors.white24, height: 30),
          _buildDetailSection(),
          const Divider(color: Colors.white24, height: 30),
          _buildSystemStatsSection(),
          const Divider(color: Colors.white24, height: 30),
          _buildIntervalSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.shield, color: _getStatusColor(state.status)),
            const SizedBox(width: 8),
            Text(
              "SECURITY INSIGHT",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        if (onClose != null)
          GestureDetector(
            onTap: onClose,
            child: Icon(Icons.close, color: Colors.white54, size: 20),
          ),
      ],
    );
  }

  Widget _buildGaugeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("TRUST SCORE (20s Avg)", style: _labelStyle()),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              (state.confidence * 100.0).toStringAsFixed(1),
              style: TextStyle(
                color: _getStatusColor(state.status),
                fontSize: 48,
                fontWeight: FontWeight.w200, // Thin font for futuristic look
                fontFamily: 'Courier', // Monospace-ish
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text("/ 100.0", style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildProgressBar(state.confidence, _getStatusColor(state.status)),
        const SizedBox(height: 4),
        Text(
          _getStatusText(state.status, state.confidence * 100.0),
          style: TextStyle(color: _getStatusColor(state.status), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDetailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("ENGINE BREAKDOWN", style: _labelStyle()),
        const SizedBox(height: 12),
        _buildStatRow("FFT Signal (10)", state.fftScore.toStringAsFixed(1)),
        if (state.isPenalized)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Text(
              "⚠️ Variance Penalty Applied",
              style: TextStyle(color: Colors.orange, fontSize: 10),
            ),
          ),
        _buildStatRow("Variance", state.fftVariance.toStringAsFixed(0)),
        const SizedBox(height: 8),
        _buildStatRow("AI Vision (90)", state.aiScore.toStringAsFixed(1)),
        const SizedBox(height: 8),
        _buildStatRow(
          "Instant Score (Raw)",
          state.finalScore.toStringAsFixed(1),
        ),
      ],
    );
  }

  Widget _buildIntervalSection() {
    String modeName;
    Color modeColor;
    IconData modeIcon;

    if (state.interval >= 60.0) {
      modeName = "DEEP SLEEP (Ultra-Low Power)";
      modeColor = Colors.blueAccent;
      modeIcon = Icons.nights_stay;
    } else if (state.interval >= 10.0) {
      modeName = "TRUSTED (Zero Impact)";
      modeColor = Colors.green;
      modeIcon = Icons.verified_user;
    } else if (state.interval >= 5.0) {
      modeName = "STABLE (Low Power)";
      modeColor = Colors.tealAccent;
      modeIcon = Icons.shield_moon;
    } else {
      modeName = "ACTIVE (High Perf)";
      modeColor = Colors.orangeAccent;
      modeIcon = Icons.bolt;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("THERMAL MODE (v5.0)", style: _labelStyle()),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: modeColor.withOpacity(0.1),
            border: Border.all(color: modeColor.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(modeIcon, color: modeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modeName,
                      style: TextStyle(
                        color: modeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Interval: ${state.interval}s",
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double value, Color color) {
    return Container(
      height: 4,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle() => TextStyle(
    color: Colors.white38,
    fontSize: 10,
    fontWeight: FontWeight.bold,
  );

  Color _getStatusColor(DetectionStatus status) {
    if (status.name == 'safe') return Colors.greenAccent;
    if (status.name == 'warning') return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _getStatusText(DetectionStatus status, double score) {
    if (score >= 95.0) return "ULTRA HD SAFE";
    if (status.name == 'safe') return "SAFE";
    if (status.name == 'warning') return "LOW SIGNAL QUALITY";
    return "DANGER DETECTED";
  }

  Widget _buildSystemStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("SYSTEM PERFORMANCE", style: _labelStyle()),
        const SizedBox(height: 12),
        _buildStatRow("CPU Usage", "${state.cpuUsage.toStringAsFixed(1)}%"),
        const SizedBox(height: 8),
        _buildStatRow("Memory", "${state.memoryUsage.toStringAsFixed(0)} MB"),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Thermal",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getThermalColor(state.thermalState).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getThermalColor(state.thermalState).withOpacity(0.5),
                ),
              ),
              child: Text(
                state.thermalState.toUpperCase(),
                style: TextStyle(
                  color: _getThermalColor(state.thermalState),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getThermalColor(String state) {
    switch (state) {
      case 'nominal':
        return Colors.greenAccent;
      case 'fair':
        return Colors.yellowAccent;
      case 'serious':
        return Colors.orangeAccent;
      case 'critical':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
