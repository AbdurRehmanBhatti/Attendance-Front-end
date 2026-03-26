import 'package:flutter/material.dart';

import 'config/app_theme.dart';
import 'config/page_transitions.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  static const String loginRoute = '/login';
  static const String homeRoute = '/home';
  static const String historyRoute = '/history';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: loginRoute,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case loginRoute:
        return SlideFadeRoute(
          page: const LoginScreen(),
          direction: SlideDirection.up,
        );

      case homeRoute:
        final args = settings.arguments as Map<String, dynamic>;
        return SlideFadeRoute(
          page: HomeScreen(
            userId: args['userId'] as int,
            userName: args['userName'] as String,
          ),
          direction: SlideDirection.up,
        );

      case historyRoute:
        final args = settings.arguments as Map<String, dynamic>;
        return SlideFadeRoute(
          page: HistoryScreen(userId: args['userId'] as int),
        );

      default:
        return SlideFadeRoute(page: const LoginScreen());
    }
  }
}

