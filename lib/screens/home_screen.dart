import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../config/prefs_keys.dart';
import '../models/attendance.dart';
import '../models/attendance_history.dart';
import '../main.dart';
import '../screens/change_password_screen.dart';
import '../screens/history_screen.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../services/auth_session_storage.dart';
import '../services/location_service.dart';
import '../widgets/animated_clock_button.dart';
import '../widgets/status_indicator.dart';

enum _HeaderAction {
  myAccount,
  changePassword,
  deleteAccount,
  logoutAll,
  logout,
}

class HomeScreen extends StatefulWidget {
  final int userId;
  final int companyId;
  final String companyName;
  final String userName;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.companyId,
    required this.companyName,
    required this.userName,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();
  final _locationService = LocationService();
  final GlobalKey _clockActionKey = GlobalKey();
  final GlobalKey _statusCardKey = GlobalKey();
  final GlobalKey _historyEntryKey = GlobalKey();
  final GlobalKey _moreMenuKey = GlobalKey();

  bool _isLoading = true;
  bool _isAcquiringLocation = false;
  bool _isClockedIn = false;
  List<Attendance> _todayRecords = [];
  AttendanceSummaryTotals _totals = AttendanceSummaryTotals.zero;
  Attendance? _lastAttendance;
  Timer? _liveTicker;
  bool _hasScheduledHomeTutorial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enforcePasswordChangeGate();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowHomeTutorial();
    });
    _fetchTodayStatus();
  }

  Future<void> _checkAndShowHomeTutorial() async {
    if (_hasScheduledHomeTutorial) {
      return;
    }

    var seen = false;
    var onboardingSeen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(AppPrefsKeys.tutorialHomeV1Seen) ?? false;
      onboardingSeen = prefs.getBool(AppPrefsKeys.onboardingSeen) ?? false;
    } catch (_) {
      seen = false;
      onboardingSeen = false;
    }

    if (!mounted || seen || !onboardingSeen) {
      return;
    }

    if (_isLoading ||
        _clockActionKey.currentContext == null ||
        _statusCardKey.currentContext == null ||
        _historyEntryKey.currentContext == null ||
        _moreMenuKey.currentContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowHomeTutorial();
      });
      return;
    }

    _hasScheduledHomeTutorial = true;
    _showHomeTutorial();
  }

  Future<void> _markHomeTutorialSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppPrefsKeys.tutorialHomeV1Seen, true);
      await prefs.setBool(AppPrefsKeys.tutorialSeen, true);
    } catch (_) {
      // Ignore local persistence failures for non-critical tutorial state.
    }
  }

  void _showHomeTutorial() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.black87;

    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'home_clock_action_key',
          keyTarget: _clockActionKey,
          shape: ShapeLightFocus.RRect,
          radius: AppRadius.lg,
          paddingFocus: AppSpacing.sm,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _TutorialContentCard(
                title: 'Clock In Here',
                body:
                    'Tap this button when you arrive at your workplace to record your attendance.',
                surfaceColor: colors.surface,
                textColor: colors.onSurface,
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'home_status_card_key',
          keyTarget: _statusCardKey,
          shape: ShapeLightFocus.RRect,
          radius: AppRadius.xl,
          paddingFocus: AppSpacing.xs,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: _TutorialContentCard(
                title: 'Your Live Status',
                body:
                    'This card shows whether you are clocked in and your Today and Week totals.',
                surfaceColor: colors.surface,
                textColor: colors.onSurface,
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'home_history_entry_key',
          keyTarget: _historyEntryKey,
          shape: ShapeLightFocus.RRect,
          radius: AppRadius.md,
          paddingFocus: AppSpacing.xs,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _TutorialContentCard(
                title: 'View Attendance History',
                body:
                    'Open History to check your records, hours, and recent activity.',
                surfaceColor: colors.surface,
                textColor: colors.onSurface,
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'home_more_menu_key',
          keyTarget: _moreMenuKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: AppSpacing.sm,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: _TutorialContentCard(
                title: 'Account and Settings',
                body:
                    'Manage your account, change password, request deletion, or log out from here.',
                surfaceColor: colors.surface,
                textColor: colors.onSurface,
              ),
            ),
          ],
        ),
      ],
      colorShadow: shadowColor,
      hideSkip: false,
      textSkip: 'Skip',
      onFinish: () async {
        await _markHomeTutorialSeen();
      },
      onSkip: () {
        unawaited(_markHomeTutorialSeen());
        return true;
      },
    ).show(context: context);
  }

  Future<void> _showLocationGuidanceHintOnce() async {
    var shouldShow = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen =
          prefs.getBool(AppPrefsKeys.locationFailureHintV1Seen) ?? false;
      if (!seen) {
        shouldShow = true;
        await prefs.setBool(AppPrefsKeys.locationFailureHintV1Seen, true);
      }
    } catch (_) {
      shouldShow = false;
    }

    if (!mounted || !shouldShow) {
      return;
    }

    _showWarning(
      'Location Needed: Clock actions require GPS and location permission. Enable location services and retry.',
    );
  }

  void _enforcePasswordChangeGate() {
    final user = ApiService.currentUser;
    if (user == null || !user.requirePasswordChangeOnNextLogin || !mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      SlideFadeRoute(
        page: const ChangePasswordScreen(),
        direction: SlideDirection.up,
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    super.dispose();
  }

  Attendance? get _activeSession {
    for (final record in _todayRecords) {
      if (record.isClockedIn) {
        return record;
      }
    }
    return null;
  }

  Duration get _todayTotalDuration {
    var total = Duration.zero;
    for (final record in _todayRecords) {
      final duration = record.duration;
      if (duration == null || duration.isNegative) continue;
      total += duration;
    }
    return total;
  }

  Duration get _dailyTotalDuration {
    if (_totals.dailyHours > 0) {
      return _durationFromHours(_totals.dailyHours);
    }

    return _todayTotalDuration;
  }

  Duration get _weeklyTotalDuration => _durationFromHours(_totals.weeklyHours);

  Duration _durationFromHours(double hours) {
    return Duration(minutes: (hours * 60).round());
  }

  void _syncLiveTicker() {
    if (_activeSession != null) {
      _liveTicker ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        setState(() {});
      });
      return;
    }

    _liveTicker?.cancel();
    _liveTicker = null;
  }

  void _applyTodayRecords(List<Attendance> records) {
    _todayRecords = records;
    _lastAttendance = records.isNotEmpty ? records.first : null;
    _isClockedIn = _activeSession != null;
    _syncLiveTicker();
  }

  Future<void> _fetchTodayStatus() async {
    if (ApiService.isPasswordChangeRequired) {
      if (mounted) {
        _enforcePasswordChangeGate();
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final nowUtc = DateTime.now().toUtc();
      final startUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final endUtc = startUtc.add(const Duration(days: 1));
      final response = await _apiService.getAttendanceHistory(
        startUtc: startUtc,
        endUtc: endUtc,
      );

      if (!mounted) return;

      setState(() {
        _applyTodayRecords(response.records);
        _totals = response.totals;
        _isLoading = false;
      });
    } on PasswordChangeRequiredApiException {
      if (!mounted) return;
      _enforcePasswordChangeGate();
    } on UnauthorizedApiException catch (e) {
      if (!mounted) return;
      await _handleUnauthorized(e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Connection timed out. Pull to retry.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Network error. Check your connection.');
    }
  }

  Future<void> _handleClockIn() async {
    HapticFeedback.mediumImpact();
    try {
      final location = await _acquireLocationForClockAction();
      await _apiService.clockIn(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      await _fetchTodayStatus();
    } on PasswordChangeRequiredApiException {
      if (!mounted) return;
      _enforcePasswordChangeGate();
      rethrow;
    } on UnauthorizedApiException catch (e) {
      if (!mounted) return;
      await _handleUnauthorized(e.message);
      rethrow;
    } on _LocationRequirementException {
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      _showApiFailure(e);
      rethrow;
    } catch (_) {
      if (!mounted) return;
      _showError('Network error. Check your connection.');
      rethrow;
    }
  }

  Future<void> _handleClockOut() async {
    HapticFeedback.mediumImpact();
    try {
      final location = await _acquireLocationForClockAction();
      await _apiService.clockOut(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      await _fetchTodayStatus();
    } on PasswordChangeRequiredApiException {
      if (!mounted) return;
      _enforcePasswordChangeGate();
      rethrow;
    } on UnauthorizedApiException catch (e) {
      if (!mounted) return;
      await _handleUnauthorized(e.message);
      rethrow;
    } on _LocationRequirementException {
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      _showApiFailure(e);
      rethrow;
    } catch (_) {
      if (!mounted) return;
      _showError('Network error. Check your connection.');
      rethrow;
    }
  }

  void _showError(String message) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
        backgroundColor: colors.errorContainer,
      ),
    );
  }

  void _showWarning(String message) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors.secondaryContainer,
      ),
    );
  }

  Future<ClockLocationResult> _acquireLocationForClockAction() async {
    setState(() => _isAcquiringLocation = true);
    try {
      var remainingAttempts = 2;

      while (remainingAttempts > 0) {
        final result = await _locationService.getClockLocation();
        if (!mounted) {
          return const ClockLocationResult();
        }

        final warning = result.warning;
        if (warning != null && warning.trim().isNotEmpty) {
          _showWarning(warning);
        }

        if (result.hasCoordinates) {
          return result;
        }

        remainingAttempts -= 1;
        if (remainingAttempts <= 0) {
          throw _LocationRequirementException();
        }

        final shouldRetry = await _handleLocationFailure(result);
        if (!mounted) {
          return const ClockLocationResult();
        }

        if (!shouldRetry) {
          throw _LocationRequirementException();
        }
      }

      throw _LocationRequirementException();
    } finally {
      if (mounted) {
        setState(() => _isAcquiringLocation = false);
      }
    }
  }

  Future<bool> _handleLocationFailure(ClockLocationResult result) async {
    await _showLocationGuidanceHintOnce();

    final reason = result.failureReason;
    final action = await _showLocationRecoveryDialog(reason);
    if (!mounted) return false;

    switch (action) {
      case _LocationRecoveryAction.retry:
        return true;
      case _LocationRecoveryAction.openLocationSettings:
        await Geolocator.openLocationSettings();
        return false;
      case _LocationRecoveryAction.openAppSettings:
        await Geolocator.openAppSettings();
        return false;
      case _LocationRecoveryAction.cancel:
      case null:
        return false;
    }
  }

  Future<_LocationRecoveryAction?> _showLocationRecoveryDialog(
    ClockLocationFailureReason? reason,
  ) async {
    String title;
    String message;
    List<_LocationRecoveryAction> actions;

    switch (reason) {
      case ClockLocationFailureReason.serviceDisabled:
        title = 'Location service is off';
        message =
            'Turn on device location service to continue clock in/out. You can retry after enabling it.';
        actions = const [
          _LocationRecoveryAction.openLocationSettings,
          _LocationRecoveryAction.retry,
          _LocationRecoveryAction.cancel,
        ];
        break;
      case ClockLocationFailureReason.permissionDenied:
        title = 'Location permission required';
        message =
            'Clock actions require location permission. Grant permission and retry.';
        actions = const [
          _LocationRecoveryAction.retry,
          _LocationRecoveryAction.cancel,
        ];
        break;
      case ClockLocationFailureReason.permissionDeniedForever:
        title = 'Permission blocked';
        message =
            'Location permission is permanently denied. Open app settings to allow location access, then retry.';
        actions = const [
          _LocationRecoveryAction.openAppSettings,
          _LocationRecoveryAction.retry,
          _LocationRecoveryAction.cancel,
        ];
        break;
      case ClockLocationFailureReason.timeout:
        title = 'Location timed out';
        message =
            'GPS is taking too long. Move to an open area or stronger signal, then retry.';
        actions = const [
          _LocationRecoveryAction.retry,
          _LocationRecoveryAction.cancel,
        ];
        break;
      case ClockLocationFailureReason.unavailable:
      case null:
        title = 'Location unavailable';
        message = 'Unable to fetch location right now. Please retry.';
        actions = const [
          _LocationRecoveryAction.retry,
          _LocationRecoveryAction.cancel,
        ];
        break;
    }

    return showDialog<_LocationRecoveryAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            for (final action in actions)
              TextButton(
                onPressed: () => Navigator.of(context).pop(action),
                child: Text(_locationRecoveryLabel(action)),
              ),
          ],
        );
      },
    );
  }

  String _locationRecoveryLabel(_LocationRecoveryAction action) {
    switch (action) {
      case _LocationRecoveryAction.retry:
        return 'Retry';
      case _LocationRecoveryAction.openLocationSettings:
        return 'Location Settings';
      case _LocationRecoveryAction.openAppSettings:
        return 'App Settings';
      case _LocationRecoveryAction.cancel:
        return 'Cancel';
    }
  }

  void _showApiFailure(ApiException error) {
    switch (error.code) {
      case 'outside_allowed_area':
        _showError(_buildOutsideAreaMessage(error));
        return;
      case 'employee_office_not_assigned':
        _showError(
          'You are not assigned to any office yet. Contact your admin.',
        );
        return;
      case 'gps_required':
        _showWarning(
          'Location is required for clock in/out. Turn on GPS and retry.',
        );
        return;
      case 'office_location_not_configured':
        _showError(
          'Office geofence is not configured yet. Contact your admin.',
        );
        return;
      default:
        _showError(error.message);
    }
  }

  Future<void> _navigateToChangePassword() async {
    await Navigator.of(context).push(
      SlideFadeRoute(
        page: const ChangePasswordScreen(),
        direction: SlideDirection.up,
      ),
    );
  }

  Future<void> _handleLogoutAllDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out all devices'),
          content: const Text(
            'This will revoke all active sessions. You will need to sign in again on every device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Log out all'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _apiService.logoutAll();
      await AuthSessionStorage.clear();
      ApiService.clearSession();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        SlideFadeRoute(
          page: const LoginScreen(),
          direction: SlideDirection.down,
        ),
        (route) => false,
      );
    } on PasswordChangeRequiredApiException {
      if (!mounted) return;
      _enforcePasswordChangeGate();
    } on UnauthorizedApiException catch (e) {
      if (!mounted) return;
      await _handleUnauthorized(e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Unable to log out all devices right now.');
    }
  }

  String _buildOutsideAreaMessage(ApiException error) {
    final metadata = error.metadata;
    if (metadata == null) {
      return error.message;
    }

    final officeName =
        metadata['officeName']?.toString() ??
        metadata['nearestOfficeName']?.toString();
    final guidance = metadata['guidance']?.toString();
    final distanceMeters =
        _toDouble(metadata['distanceMeters']) ??
        _toDouble(metadata['nearestDistanceMeters']);
    final effectiveRadiusMeters = _toDouble(metadata['effectiveRadiusMeters']);
    final allowedRadiusMeters = _toDouble(metadata['allowedRadiusMeters']);

    final parts = <String>[];

    if (officeName != null && officeName.trim().isNotEmpty) {
      parts.add('Outside allowed area for $officeName.');
    } else {
      parts.add('You are outside the allowed office geofence.');
    }

    if (distanceMeters != null && effectiveRadiusMeters != null) {
      parts.add(
        'Current distance ${distanceMeters.toStringAsFixed(0)}m, allowed ${effectiveRadiusMeters.toStringAsFixed(0)}m.',
      );
    } else if (distanceMeters != null && allowedRadiusMeters != null) {
      parts.add(
        'Current distance ${distanceMeters.toStringAsFixed(0)}m, allowed ${allowedRadiusMeters.toStringAsFixed(0)}m.',
      );
    }

    if (guidance != null && guidance.trim().isNotEmpty) {
      parts.add(guidance);
    }

    if (parts.isEmpty) {
      return error.message;
    }

    return parts.join(' ');
  }

  double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  Future<void> _handleUnauthorized(String message) async {
    setState(() {
      _isLoading = false;
      _isClockedIn = false;
      _todayRecords = [];
      _totals = AttendanceSummaryTotals.zero;
      _lastAttendance = null;
    });
    _syncLiveTicker();
    await AuthSessionStorage.clear();
    ApiService.clearSession();
    _showError(message);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      SlideFadeRoute(page: const LoginScreen(), direction: SlideDirection.down),
      (route) => false,
    );
  }

  Future<void> _handleLogout() async {
    _liveTicker?.cancel();
    _liveTicker = null;
    ApiService.clearSession();
    await AuthSessionStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      SlideFadeRoute(page: const LoginScreen(), direction: SlideDirection.down),
      (route) => false,
    );
  }

  Future<void> _navigateToDeleteAccount() async {
    await Navigator.of(context).pushNamed(AttendanceApp.deleteAccountRoute);

    if (!mounted) {
      return;
    }

    await _fetchTodayStatus();
  }

  Future<void> _navigateToMyAccount() async {
    await Navigator.of(context).pushNamed(AttendanceApp.myAccountRoute);
  }

  Future<void> _onHeaderActionSelected(_HeaderAction action) async {
    switch (action) {
      case _HeaderAction.myAccount:
        await _navigateToMyAccount();
        return;
      case _HeaderAction.changePassword:
        await _navigateToChangePassword();
        return;
      case _HeaderAction.deleteAccount:
        await _navigateToDeleteAccount();
        return;
      case _HeaderAction.logoutAll:
        await _handleLogoutAllDevices();
        return;
      case _HeaderAction.logout:
        await _handleLogout();
        return;
    }
  }

  void _navigateToHistory() {
    Navigator.of(context).push(SlideFadeRoute(page: const HistoryScreen()));
  }

  // ── Helpers ──

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _todayDate => DateFormat.yMMMMd().format(DateTime.now());

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return DateFormat.jm().format(dt.toLocal());
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '--';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.primary,
          onRefresh: _fetchTodayStatus,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            children: [
              // ── Greeting Header ──
              _buildGreeting(colors, textTheme),
              const SizedBox(height: AppSpacing.lg),

              // ── Status Card ──
              _buildStatusCard(colors, textTheme),
              const SizedBox(height: AppSpacing.lg),

              // ── Clock Buttons ──
              _buildClockButtons(),
              const SizedBox(height: AppSpacing.lg),

              // ── Last Attendance Card ──
              _buildLastAttendanceCard(colors, textTheme),
              const SizedBox(height: AppSpacing.md),

              // ── History Link ──
              Center(
                child: TextButton.icon(
                  key: _historyEntryKey,
                  onPressed: _navigateToHistory,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('View Full History'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Greeting ──

  Widget _buildGreeting(ColorScheme colors, TextTheme textTheme) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'app-logo',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.access_time_filled_rounded,
                      size: 24,
                      color: colors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _navigateToHistory,
                  icon: const Icon(Icons.history_rounded),
                  tooltip: 'History',
                ),
                PopupMenuButton<_HeaderAction>(
                  key: _moreMenuKey,
                  tooltip: 'More actions',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (action) {
                    unawaited(_onHeaderActionSelected(action));
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<_HeaderAction>(
                      value: _HeaderAction.myAccount,
                      child: Text('My Account'),
                    ),
                    PopupMenuItem<_HeaderAction>(
                      value: _HeaderAction.changePassword,
                      child: Text('Change Password'),
                    ),
                    PopupMenuItem<_HeaderAction>(
                      value: _HeaderAction.deleteAccount,
                      child: Text('Delete Account'),
                    ),
                    PopupMenuItem<_HeaderAction>(
                      value: _HeaderAction.logoutAll,
                      child: Text('Log Out All Devices'),
                    ),
                    PopupMenuItem<_HeaderAction>(
                      value: _HeaderAction.logout,
                      child: Text('Logout'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '$_greeting,',
              style: textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            Text(
              widget.userName,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.companyName,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _todayDate,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: AppDurations.emphasis)
        .slideY(begin: -0.1, end: 0, duration: AppDurations.emphasis);
  }

  // ── Status Card (Glassmorphism) ──

  Widget _buildStatusCard(ColorScheme colors, TextTheme textTheme) {
    final activeSession = _activeSession;

    return ClipRRect(
          key: _statusCardKey,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryContainer.withValues(alpha: 0.7),
                    colors.primaryContainer.withValues(alpha: 0.4),
                  ],
                ),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  StatusIndicator(isActive: _isClockedIn),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isClockedIn ? 'Clocked In' : 'Not Clocked In Today',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _isClockedIn && activeSession?.clockIn != null
                              ? 'Since ${_formatTime(activeSession!.clockIn)}'
                              : 'Tap the button below to clock in',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onPrimaryContainer.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Today: ${_formatDuration(_dailyTotalDuration)}  |  Week: ${_formatDuration(_weeklyTotalDuration)}',
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.onPrimaryContainer.withValues(
                              alpha: 0.9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isClockedIn && activeSession != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        _formatDuration(activeSession.duration),
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: AppDurations.emphasis, delay: 100.ms)
        .slideY(begin: 0.15, end: 0, duration: AppDurations.emphasis);
  }

  // ── Clock Buttons ──

  Widget _buildClockButtons() {
    return Column(
      children: [
        AnimatedSwitcher(
          key: _clockActionKey,
          duration: AppDurations.standard,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 64,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _isClockedIn
              ? AnimatedClockButton(
                  key: const ValueKey('clock-out'),
                  label: 'Clock Out',
                  icon: Icons.logout_rounded,
                  gradientColors: [Colors.red.shade400, Colors.orange.shade600],
                  onPressed: _handleClockOut,
                )
              : AnimatedClockButton(
                  key: const ValueKey('clock-in'),
                  label: 'Clock In',
                  icon: Icons.login_rounded,
                  gradientColors: [Colors.green.shade500, Colors.teal.shade400],
                  onPressed: _handleClockIn,
                ),
        ),
        if (_isAcquiringLocation)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Acquiring location...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  // ── Last Attendance Card ──

  Widget _buildLastAttendanceCard(ColorScheme colors, TextTheme textTheme) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_lastAttendance == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Icon(
                Icons.event_available_rounded,
                size: 40,
                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No attendance recorded today',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final att = _lastAttendance!;
    return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last Attendance',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _timeChip(
                        icon: Icons.login_rounded,
                        label: 'In',
                        time: _formatTime(att.clockIn),
                        color: Colors.green,
                        colors: colors,
                        textTheme: textTheme,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _timeChip(
                        icon: Icons.logout_rounded,
                        label: 'Out',
                        time: _formatTime(att.clockOut),
                        color: att.clockOut != null
                            ? Colors.red
                            : colors.outline,
                        colors: colors,
                        textTheme: textTheme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      'Duration: ${_formatDuration(att.duration)}',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
                if (att.officeName != null || att.officeId != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Location: ${att.officeName ?? att.officeId}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: AppDurations.emphasis, delay: 200.ms)
        .slideY(begin: 0.2, end: 0, duration: AppDurations.emphasis);
  }

  Widget _timeChip({
    required IconData icon,
    required String label,
    required String time,
    required Color color,
    required ColorScheme colors,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialContentCard extends StatelessWidget {
  final String title;
  final String body;
  final Color surfaceColor;
  final Color textColor;

  const _TutorialContentCard({
    required this.title,
    required this.body,
    required this.surfaceColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: surfaceColor.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: textColor.withValues(alpha: 0.10)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style:
                    textTheme.titleMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                body,
                style:
                    textTheme.bodyMedium?.copyWith(color: textColor) ??
                    const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationRequirementException implements Exception {}

enum _LocationRecoveryAction {
  retry,
  openLocationSettings,
  openAppSettings,
  cancel,
}
