import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/detection/deepfake_inference_service.dart';

class InteractionGuideOverlay extends StatefulWidget {
  final DeepfakeState state;

  const InteractionGuideOverlay({super.key, required this.state});

  @override
  State<InteractionGuideOverlay> createState() =>
      _InteractionGuideOverlayState();
}

class _InteractionGuideOverlayState extends State<InteractionGuideOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStepIndex = 0;
  Timer? _rotationTimer;
  late AnimationController _fadeController;

  // NOTE: Interaction Guide
  // Only 2 items requested by user: Occlusion & Profile Check.
  // Lighting Shift removed.
  final List<Map<String, String>> _guides = [
    {
      "title": "얼굴을 가려보세요",
      "desc": "얼굴 앞에서 손을 흔들어주세요.",
      "icon": "assets/guide_hand Background Removed.png",
    },
    {
      "title": "고개를 돌려보세요",
      "desc": "고개를 좌우로 천천히 흔들어주세요.",
      "icon": "assets/guide_turn Background Removed.png",
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Check initial state
    _checkVisibility();
  }

  @override
  void didUpdateWidget(InteractionGuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkVisibility();
  }

  void _checkVisibility() {
    // Show only when Warning or Danger (Reliability < 80 roughly, or specifically status)
    // Actually, logic said "Warning or Danger"
    final shouldShow =
        widget.state.status == DetectionStatus.warning ||
        widget.state.status == DetectionStatus.danger;

    if (shouldShow &&
        !_fadeController.isCompleted &&
        !_fadeController.isAnimating) {
      _fadeController.forward();
      _startRotation();
    } else if (!shouldShow &&
        (_fadeController.isCompleted || _fadeController.isAnimating)) {
      _fadeController.reverse();
      _stopRotation();
    }
  }

  void _startRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentStepIndex = (_currentStepIndex + 1) % _guides.length;
        });
      }
    });
  }

  void _stopRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Always render structure, only control opacity
    // This prevents layout shifts in parent Stack
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          final guide = _guides[_currentStepIndex];

          return Opacity(
            opacity: _fadeController.value, // Will be 0.0 when safe
            child: Center(
              child: Container(
                width: 300,
                // Box removed, just padding for layout
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                // No decoration - fully transparent
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Section - Increased size
                    SizedBox(
                      height: 150, // Much larger
                      width: 150,
                      child: _buildIcon(guide['title']!),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      guide['title']!.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28, // Larger text
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      guide['desc']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                        shadows: [
                          Shadow(
                            blurRadius: 8.0,
                            color: Colors.black, // Strong shaodw for contrast
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIcon(String title) {
    // Use Image.asset with the icon path from the map
    // We access the icon path directly from the _guides list in build method, but here we passed 'title'.
    // Better to just look it up or change signature.
    // Simpler: Just map title to asset here since I don't want to change call sites in build.
    String assetPath;
    if (title.contains("얼굴"))
      assetPath = "assets/guide_hand Background Removed.png";
    else if (title.contains("고개"))
      assetPath = "assets/guide_turn Background Removed.png";
    else
      assetPath = "assets/guide_light.png";

    return Image.asset(
      assetPath,
      width: 50,
      height: 50,
      fit: BoxFit.contain,
      errorBuilder: (ctx, _, __) =>
          const Icon(Icons.warning, color: Colors.white),
    );
  }
}
