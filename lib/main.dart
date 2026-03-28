import 'package:flutter/material.dart';

import 'config/app_theme.dart';
import 'config/page_transitions.dart';
import 'models/user.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/auth_session_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});

  static const String loginRoute = '/login';
  static const String homeRoute = '/home';
  static const String historyRoute = '/history';

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  bool _isInitializing = true;
  String _initialRoute = AttendanceApp.loginRoute;
  Map<String, dynamic>? _initialArgs;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await AuthSessionStorage.loadUser();

    if (user != null && user.token.trim().isNotEmpty) {
      ApiService.restoreSession(user);
      _initialRoute = AttendanceApp.homeRoute;
      _initialArgs = _homeArgsFromUser(user);
    }

    if (!mounted) return;
    setState(() => _isInitializing = false);
  }

  Map<String, dynamic> _homeArgsFromUser(User user) {
    return {
      'userId': user.id,
      'userName': user.name,
    };
  }

  Route<dynamic> _buildHomeOrLogin({SlideDirection direction = SlideDirection.up}) {
    final args = _initialArgs;
    final currentUser = ApiService.currentUser;

    final userId = (args?['userId'] as int?) ?? currentUser?.id;
    final userName = (args?['userName'] as String?) ?? currentUser?.name;

    if (userId == null || userName == null || userName.trim().isEmpty) {
      return SlideFadeRoute(
        page: const LoginScreen(),
        direction: direction,
      );
    }

    return SlideFadeRoute(
      page: HomeScreen(userId: userId, userName: userName),
      direction: direction,
    );
  }

  Widget _buildStartupHome() {
    final args = _initialArgs;
    final currentUser = ApiService.currentUser;

    final userId = (args?['userId'] as int?) ?? currentUser?.id;
    final userName = (args?['userName'] as String?) ?? currentUser?.name;

    if (userId == null || userName == null || userName.trim().isEmpty) {
      return const LoginScreen();
    }

    return HomeScreen(userId: userId, userName: userName);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Attendance App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: _buildStartupHome(),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name;

    switch (settings.name) {
      case AttendanceApp.loginRoute:
        return SlideFadeRoute(
          page: const LoginScreen(),
          direction: SlideDirection.up,
        );

      case AttendanceApp.homeRoute:
        final providedArgs = settings.arguments;
        if (providedArgs is Map<String, dynamic>) {
          _initialArgs = providedArgs;
        }
        return _buildHomeOrLogin(direction: SlideDirection.up);

      case AttendanceApp.historyRoute:
        return SlideFadeRoute(
          page: const HistoryScreen(),
        );

      default:
        if (routeName == Navigator.defaultRouteName &&
            _initialRoute == AttendanceApp.homeRoute) {
          return _buildHomeOrLogin(direction: SlideDirection.up);
        }
        return SlideFadeRoute(page: const LoginScreen());
    }
  }
}

