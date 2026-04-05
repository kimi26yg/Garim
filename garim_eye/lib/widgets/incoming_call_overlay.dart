import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/call_provider.dart';
import '../theme/app_theme.dart';

class IncomingCallOverlay extends ConsumerStatefulWidget {
  const IncomingCallOverlay({super.key});

  @override
  ConsumerState<IncomingCallOverlay> createState() =>
      _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends ConsumerState<IncomingCallOverlay> {
  CallStatus? _lastStatus;

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);

    // Prevent unnecessary rebuilds - only rebuild on status change
    if (_lastStatus == callState.status &&
        callState.status != CallStatus.incoming) {
      return const SizedBox.shrink();
    }
    _lastStatus = callState.status;

    // Reactive Navigation Logic
    ref.listen(callProvider, (previous, next) {
      if (previous?.status == CallStatus.incoming &&
          next.status == CallStatus.connecting) {
        // Accepted -> Navigate to 'Connecting/Calling' animation screen first
        context.go('/calling');
        // Note: CallingScreen automatically navigates to '/call' after delay
      }
    });

    if (callState.status != CallStatus.incoming &&
        callState.status != CallStatus.ended) {
      return const SizedBox.shrink();
    }

    final isEnded = callState.status == CallStatus.ended;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 1. Premium Dark Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0F172A), // Slate 900
                    Color(0xFF000000), // Black
                  ],
                ),
              ),
            ),

            // 1.5 Ambient Glow Effect
            if (!isEnded)
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.2),
                        blurRadius: 100,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),

            // 2. Main Content (Centered)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 120),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar with Ripple/Glow hint
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isEnded
                              ? Colors.grey.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color(0xFF1E293B),
                        child: Icon(
                          Icons.person,
                          size: 64,
                          color: isEnded ? Colors.grey : Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name
                    Text(
                      callState.callerName ?? 'Unknown',
                      style: TextStyle(
                        color: isEnded ? Colors.white38 : Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Call Type / Label
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isEnded ? Icons.call_end : Icons.shield_outlined,
                            color: isEnded ? Colors.grey : AppTheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEnded ? '통화 종료됨' : '보안 통화 요청',
                            style: TextStyle(
                              color: isEnded
                                  ? Colors.grey
                                  : AppTheme.primary.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Action Buttons (Bottom)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Decline Button
                    _buildCallButton(
                      context,
                      label: 'Decline',
                      icon: Icons.call_end,
                      color: AppTheme.riskHigh,
                      onTap: () {
                        if (!isEnded)
                          ref.read(callProvider.notifier).rejectCall();
                      },
                      enabled: !isEnded,
                    ),

                    // Accept Button
                    _buildCallButton(
                      context,
                      label: 'Accept',
                      icon: Icons.call,
                      color: const Color(0xFF4ADE80), // Bright Green
                      onTap: () {
                        if (!isEnded)
                          ref.read(callProvider.notifier).acceptCall();
                      },
                      enabled: !isEnded,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: enabled ? color : Colors.grey.withOpacity(0.3),
              shape: BoxShape.circle,
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: enabled ? Colors.white : Colors.white38,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.white38,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
