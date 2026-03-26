import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../models/attendance.dart';
import '../screens/history_screen.dart';
import '../services/api_service.dart';
import '../widgets/animated_clock_button.dart';
import '../widgets/status_indicator.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  final String userName;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();

  bool _isLoading = true;
  bool _isClockedIn = false;
  Attendance? _lastAttendance;

  @override
  void initState() {
    super.initState();
    _fetchTodayStatus();
  }

  Future<void> _fetchTodayStatus() async {
    setState(() => _isLoading = true);
    try {
      final records = await _apiService.getTodayAttendance(widget.userId);
      if (!mounted) return;
      setState(() {
        if (records.isNotEmpty) {
          _lastAttendance = records.first;
          _isClockedIn = _lastAttendance!.isClockedIn;
        } else {
          _lastAttendance = null;
          _isClockedIn = false;
        }
        _isLoading = false;
      });
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
      final record = await _apiService.clockIn(widget.userId);
      if (!mounted) return;
      setState(() {
        _lastAttendance = record;
        _isClockedIn = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
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
      final record = await _apiService.clockOut(widget.userId);
      if (!mounted) return;
      setState(() {
        _lastAttendance = record;
        _isClockedIn = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
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
              child: Text(message,
                  style: TextStyle(color: colors.onErrorContainer)),
            ),
          ],
        ),
        backgroundColor: colors.errorContainer,
      ),
    );
  }

  void _navigateToHistory() {
    Navigator.of(context).push(
      SlideFadeRoute(
        page: HistoryScreen(userId: widget.userId),
      ),
    );
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
    return ClipRRect(
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
                      _isClockedIn ? 'Clocked In' : 'Not Clocked In',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _isClockedIn && _lastAttendance?.clockIn != null
                          ? 'Since ${_formatTime(_lastAttendance!.clockIn)}'
                          : 'Tap the button below to clock in',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isClockedIn && _lastAttendance != null)
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
                    _formatDuration(_lastAttendance!.duration),
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
    return AnimatedSwitcher(
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
                  gradientColors: [
                    Colors.green.shade500,
                    Colors.teal.shade400,
                  ],
                  onPressed: _handleClockIn,
                ),
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
              Icon(Icons.event_available_rounded,
                  size: 40, color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
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
                Flexible(
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
                Flexible(
                  child: _timeChip(
                    icon: Icons.logout_rounded,
                    label: 'Out',
                    time: _formatTime(att.clockOut),
                    color: att.clockOut != null ? Colors.red : colors.outline,
                    colors: colors,
                    textTheme: textTheme,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
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
                      _formatDuration(att.duration),
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                time,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
