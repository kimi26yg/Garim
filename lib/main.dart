import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dashboard_screen.dart';

void main() {
  runApp(const ProviderScope(child: GarimAttackApp()));
}

// GoRouter Configuration
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
  ],
);

class GarimAttackApp extends StatelessWidget {
  const GarimAttackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Garim Eye V2 - Attacker',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00FF41), // Neon Green
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF00FF41),
          secondary: const Color(0xFFFF0000), // Red
          surface: Colors.black,
          onSurface: const Color(0xFF00FF41),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            color: Color(0xFF00FF41),
            fontFamily: 'Courier',
          ),
          titleLarge: TextStyle(
            color: Color(0xFF00FF41),
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
