import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:async';
import 'dart:ui';

import 'config/app_theme.dart';
import 'firebase_options.dart';
import 'config/page_transitions.dart';
import 'config/prefs_keys.dart';
import 'models/user.dart';
import 'screens/change_password_screen.dart';
import 'screens/delete_account_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/leave_management_screen.dart';
import 'screens/login_screen.dart';
import 'screens/my_account_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/api_service.dart';
import 'services/auth_session_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const AttendanceApp());
}

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});

  static const String loginRoute = '/login';
  static const String homeRoute = '/home';
  static const String changePasswordRoute = '/change-password';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String resetPasswordRoute = '/reset-password';
  static const String historyRoute = '/history';
  static const String myAccountRoute = '/my-account';
  static const String leaveManagementRoute = '/leave-management';
  static const String deleteAccountRoute = '/delete-account';

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _deepLinkSubscription;
  AppLinks? _appLinks;
  Map<String, dynamic>? _pendingResetArgs;
  Map<String, dynamic>? _lastValidResetArgs;
  bool _isInitializing = true;
  bool _shouldShowOnboarding = false;
  String _initialRoute = AttendanceApp.loginRoute;
  Map<String, dynamic>? _initialArgs;

  @override
  void initState() {
    super.initState();
    _seedPendingResetFromDefaultRoute();
    _initDeepLinks();
    _restoreSession();
  }

  void _seedPendingResetFromDefaultRoute() {
    final defaultRouteName =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    if (defaultRouteName.trim().isEmpty ||
        defaultRouteName == Navigator.defaultRouteName) {
      return;
    }

    _queueResetArgsFromRawLink(defaultRouteName);
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        _handleIncomingResetLink(initialUri);
      }
    } catch (_) {
      // Ignore malformed deep links so app startup is not blocked.
    }

    _deepLinkSubscription = _appLinks!.uriLinkStream.listen(
      _handleIncomingResetLink,
      onError: (_) {
        // Ignore malformed deep links and keep app responsive.
      },
    );
  }

  void _handleIncomingResetLink(Uri uri) {
    final resetArgs = _extractResetArgs(uri);
    if (resetArgs == null) {
      return;
    }

    _lastValidResetArgs = resetArgs;
    _pendingResetArgs = resetArgs;
    _tryOpenPendingResetLink();
  }

  void _queueResetArgsFromRawLink(String rawLink) {
    final directUri = Uri.tryParse(rawLink);
    if (directUri != null) {
      final resetArgs = _extractResetArgs(directUri);
      if (resetArgs != null) {
        _lastValidResetArgs = resetArgs;
        _pendingResetArgs = resetArgs;
        _tryOpenPendingResetLink();
        return;
      }
    }

    final normalizedPathUri = Uri.tryParse('attendanceapp://auth$rawLink');
    if (normalizedPathUri == null) {
      return;
    }

    final fallbackArgs = _extractResetArgs(normalizedPathUri);
    if (fallbackArgs == null) {
      return;
    }

    _lastValidResetArgs = fallbackArgs;
    _pendingResetArgs = fallbackArgs;
    _tryOpenPendingResetLink();
  }

  Map<String, dynamic>? _extractResetArgsFromRawRoute(String? routeName) {
    if (routeName == null || routeName.trim().isEmpty) {
      return null;
    }

    final parsedRouteUri = Uri.tryParse(routeName);
    if (parsedRouteUri != null) {
      final args = _extractResetArgs(parsedRouteUri);
      if (args != null) {
        return args;
      }
    }

    final normalizedPathUri = Uri.tryParse('attendanceapp://auth$routeName');
    if (normalizedPathUri == null) {
      return null;
    }

    return _extractResetArgs(normalizedPathUri);
  }

  Map<String, dynamic>? _extractResetArgs(Uri uri) {
    final isResetLink =
        uri.path == AttendanceApp.resetPasswordRoute ||
        uri.path.endsWith(AttendanceApp.resetPasswordRoute) ||
        uri.path.contains('${AttendanceApp.resetPasswordRoute}/') ||
        uri.host == 'reset-password';

    if (!isResetLink) {
      return null;
    }

    var userId = int.tryParse(uri.queryParameters['userId'] ?? '');
    var token = uri.queryParameters['token'];

    if ((userId == null || token == null || token.trim().isEmpty) &&
        uri.fragment.trim().isNotEmpty) {
      final fragmentQuery = Uri.splitQueryString(uri.fragment);
      userId ??= int.tryParse(fragmentQuery['userId'] ?? '');
      token ??= fragmentQuery['token'];
    }

    if (userId == null || token == null || token.trim().isEmpty) {
      final segments = uri.pathSegments;
      final resetIndex = segments.indexOf('reset-password');
      if (resetIndex >= 0 && segments.length > resetIndex + 2) {
        userId = int.tryParse(segments[resetIndex + 1]);
        token = Uri.decodeComponent(segments[resetIndex + 2]);
      }
    }

    if (userId == null || token == null || token.trim().isEmpty) {
      return null;
    }

    return {'userId': userId, 'token': token};
  }

  void _tryOpenPendingResetLink() {
    final pendingArgs = _pendingResetArgs;
    if (pendingArgs == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isInitializing) {
        return;
      }

      final navigator = _navigatorKey.currentState;
      final currentPendingArgs = _pendingResetArgs;
      if (navigator == null || currentPendingArgs == null) {
        if (currentPendingArgs != null) {
          Future<void>.delayed(
            const Duration(milliseconds: 120),
            _tryOpenPendingResetLink,
          );
        }
        return;
      }

      _pendingResetArgs = null;
      navigator.pushNamed(
        AttendanceApp.resetPasswordRoute,
        arguments: currentPendingArgs,
      );
    });
  }

  Future<void> _restoreSession() async {
    var onboardingSeen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      onboardingSeen = prefs.getBool(AppPrefsKeys.onboardingSeen) ?? false;
    } catch (_) {
      onboardingSeen = false;
    }

    if (onboardingSeen == false) {
      if (!mounted) return;
      setState(() {
        _shouldShowOnboarding = true;
        _isInitializing = false;
      });
      return;
    }

    final user = await AuthSessionStorage.loadUser();

    if (user != null && user.token.trim().isNotEmpty && user.isEmployee) {
      ApiService.restoreSession(user);
      if (user.requirePasswordChangeOnNextLogin) {
        _initialRoute = AttendanceApp.changePasswordRoute;
      } else {
        _initialRoute = AttendanceApp.homeRoute;
        _initialArgs = _homeArgsFromUser(user);
      }
    } else if (user != null && !user.isEmployee) {
      await AuthSessionStorage.clear();
      ApiService.clearSession();
    }

    if (!mounted) return;
    setState(() => _isInitializing = false);
    _tryOpenPendingResetLink();
  }

  Map<String, dynamic> _homeArgsFromUser(User user) {
    return {
      'userId': user.id,
      'companyId': user.companyId,
      'companyName': user.companyName,
      'userName': user.name,
    };
  }

  Route<dynamic> _buildHomeOrLogin({
    SlideDirection direction = SlideDirection.up,
  }) {
    final args = _initialArgs;
    final currentUser = ApiService.currentUser;

    if (currentUser != null &&
        currentUser.isEmployee &&
        currentUser.requirePasswordChangeOnNextLogin) {
      return SlideFadeRoute(
        page: const ChangePasswordScreen(isMandatory: true),
        direction: direction,
      );
    }

    final userId = (args?['userId'] as int?) ?? currentUser?.id;
    final companyId = (args?['companyId'] as int?) ?? currentUser?.companyId;
    final companyName =
        (args?['companyName'] as String?) ?? currentUser?.companyName;
    final userName = (args?['userName'] as String?) ?? currentUser?.name;

    if (userId == null ||
        companyId == null ||
        companyName == null ||
        companyName.trim().isEmpty ||
        userName == null ||
        userName.trim().isEmpty ||
        (currentUser != null && !currentUser.isEmployee)) {
      return SlideFadeRoute(page: const LoginScreen(), direction: direction);
    }

    return SlideFadeRoute(
      page: HomeScreen(
        userId: userId,
        companyId: companyId,
        companyName: companyName,
        userName: userName,
      ),
      direction: direction,
    );
  }

  Widget _buildStartupHome() {
    if (_shouldShowOnboarding) {
      return const OnboardingScreen();
    }

    final args = _initialArgs;
    final currentUser = ApiService.currentUser;

    if (currentUser != null &&
        currentUser.isEmployee &&
        currentUser.requirePasswordChangeOnNextLogin) {
      return const ChangePasswordScreen(isMandatory: true);
    }

    final userId = (args?['userId'] as int?) ?? currentUser?.id;
    final companyId = (args?['companyId'] as int?) ?? currentUser?.companyId;
    final companyName =
        (args?['companyName'] as String?) ?? currentUser?.companyName;
    final userName = (args?['userName'] as String?) ?? currentUser?.name;

    if (userId == null ||
        companyId == null ||
        companyName == null ||
        companyName.trim().isEmpty ||
        userName == null ||
        userName.trim().isEmpty ||
        (currentUser != null && !currentUser.isEmployee)) {
      return const LoginScreen();
    }

    return HomeScreen(
      userId: userId,
      companyId: companyId,
      companyName: companyName,
      userName: userName,
    );
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'TimeSphere',
      navigatorKey: _navigatorKey,
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

    if (routeName != null &&
        (routeName.startsWith(AttendanceApp.resetPasswordRoute) ||
            routeName.contains('/reset-password?'))) {
      final parsedArgs =
          _extractResetArgsFromRawRoute(routeName) ?? _lastValidResetArgs;
      final userId = parsedArgs?['userId'] as int?;
      final token = parsedArgs?['token'] as String?;

      return SlideFadeRoute(
        page: ResetPasswordScreen(userId: userId, token: token),
        direction: SlideDirection.up,
      );
    }

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

      case AttendanceApp.changePasswordRoute:
        return SlideFadeRoute(
          page: const ChangePasswordScreen(),
          direction: SlideDirection.up,
        );

      case AttendanceApp.forgotPasswordRoute:
        return SlideFadeRoute(
          page: const ForgotPasswordScreen(),
          direction: SlideDirection.up,
        );

      case AttendanceApp.resetPasswordRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        final effectiveArgs = args ?? _lastValidResetArgs;
        if (effectiveArgs != null) {
          _lastValidResetArgs = effectiveArgs;
        }
        final userId = effectiveArgs?['userId'] as int?;
        final token = effectiveArgs?['token'] as String?;
        return SlideFadeRoute(
          page: ResetPasswordScreen(userId: userId, token: token),
          direction: SlideDirection.up,
        );

      case AttendanceApp.historyRoute:
        return SlideFadeRoute(page: const HistoryScreen());

      case AttendanceApp.myAccountRoute:
        return SlideFadeRoute(
          page: const MyAccountScreen(),
          direction: SlideDirection.up,
        );

      case AttendanceApp.leaveManagementRoute:
        return SlideFadeRoute(
          page: const LeaveManagementScreen(),
          direction: SlideDirection.up,
        );

      case AttendanceApp.deleteAccountRoute:
        return SlideFadeRoute(
          page: const DeleteAccountScreen(),
          direction: SlideDirection.up,
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
