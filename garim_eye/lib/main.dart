import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/call_ended_screen.dart';
import 'screens/calling_screen.dart';
import 'screens/home_screen.dart';
import 'screens/video_call_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/incoming_call_overlay.dart';
import 'providers/socket_provider.dart';
import 'providers/call_provider.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

final _router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return Stack(
          children: [
            child,
            const _CallGlobalObserver(),
            const IncomingCallOverlay(),
            const _SocketInitializer(),
          ],
        );
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/calling',
          builder: (context, state) => const CallingScreen(),
        ),
        GoRoute(
          path: '/call',
          builder: (context, state) => const VideoCallScreen(),
        ),
        GoRoute(
          path: '/ended',
          builder: (context, state) => const CallEndedScreen(),
        ),
      ],
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Garim Eye V2',
      theme: AppTheme.darkTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// Global observer for call state changes (Remote Hangup, etc.)
class _CallGlobalObserver extends ConsumerWidget {
  const _CallGlobalObserver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(callProvider, (previous, next) {
      // Handle Remote Hangup
      if (next.status == CallStatus.ended) {
        // If we were in a call (connected/calling/connecting), go to summary screen.
        // If we were just receiving a call (incoming), STAY on current screen (Overlay handles UI).
        if (previous?.status == CallStatus.connected ||
            previous?.status == CallStatus.calling ||
            previous?.status == CallStatus.connecting) {
          debugPrint('GlobalObserver: Call Ended -> Navigating to /ended');
          context.go('/ended');
        }
      }
    });
    return const SizedBox.shrink();
  }
}

// Helper widget to init socket service once
class _SocketInitializer extends ConsumerStatefulWidget {
  const _SocketInitializer();
  @override
  ConsumerState<_SocketInitializer> createState() => _SocketInitializerState();
}

class _SocketInitializerState extends ConsumerState<_SocketInitializer> {
  @override
  void initState() {
    super.initState();
    // Just watching/reading it initializes it because of the provider definition
    ref.read(socketServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
