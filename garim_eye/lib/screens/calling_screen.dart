// lib/screens/calling_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class CallingScreen extends StatefulWidget {
  const CallingScreen({super.key});

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // 조금 더 여유로운 박동
    )..repeat(reverse: true);

    // 2초 후 자동으로 통화 화면으로 전환
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/call');
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        // 핵심 수정: 가로 너비를 화면 전체로 확장
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a2b45), Color(0xFF0B1221)],
          ),
        ),
        child: Column(
          // 중앙 정렬 보장
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // Avatar with Pulse (보안 스캔 느낌 연출)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(
                          alpha: 0.2 + (_pulseController.value * 0.4),
                        ),
                        blurRadius: 30 + (_pulseController.value * 20),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 80,
                    backgroundColor: Color(0xFF2A3B55),
                    child: Icon(Icons.person, size: 80, color: Colors.white54),
                  ),
                );
              },
            ),
            const SizedBox(height: 48),
            // 사용자 정보 (/또롱님)
            Text(
              '배용성',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '안심 통화 연결중...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.primary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(flex: 3),
            // 종료 버튼
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: GestureDetector(
                onTap: () => context.go('/'),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.riskHigh,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.riskHigh.withValues(alpha: 0.4),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
