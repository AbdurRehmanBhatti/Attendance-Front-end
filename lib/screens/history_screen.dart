import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../models/attendance.dart';
import '../models/attendance_history.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../services/auth_session_storage.dart';
import '../widgets/attendance_card.dart';
import '../widgets/shimmer_list.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _apiService = ApiService();

  List<Attendance> _records = [];
  AttendanceSummaryTotals _totals = AttendanceSummaryTotals.zero;
  bool _isLoading = true;
  String? _error;
  HistoryTab _selectedTab = HistoryTab.today;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final nowUtc = DateTime.now().toUtc();
      final range = _selectedTab.toDateRange(nowUtc);
      final response = await _apiService.getAttendanceHistory(
        startUtc: range.start,
        endUtc: range.end,
      );

      if (!mounted) return;
      setState(() {
        _records = response.records;
        _totals = response.totals;
        _isLoading = false;
      });
    } on UnauthorizedApiException catch (e) {
      if (!mounted) return;
      ApiService.clearSession();
      await AuthSessionStorage.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = 'Connection timed out.';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: _fetchRecords,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: SegmentedButton<HistoryTab>(
                segments: const [
                  ButtonSegment(value: HistoryTab.today, label: Text('Today')),
                  ButtonSegment(
                    value: HistoryTab.last7Days,
                    label: Text('Last 7 Days'),
                  ),
                  ButtonSegment(
                    value: HistoryTab.thisMonth,
                    label: Text('This Month'),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (selection) {
                  final tab = selection.first;
                  if (tab == _selectedTab) return;
                  setState(() => _selectedTab = tab);
                  _fetchRecords();
                },
                showSelectedIcon: false,
              ),
            ),
            Expanded(child: _buildBody(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colors) {
    // Loading
    if (_isLoading) {
      return const ShimmerList();
    }

    // Error
    if (_error != null) {
      return _buildErrorState(colors);
    }

    // Empty
    if (_records.isEmpty) {
      return _buildEmptyState(colors, _selectedTab.emptyMessage);
    }

    // List
    return _buildList(colors);
  }

  Widget _buildList(ColorScheme colors) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      itemCount: _records.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSummaryCard(colors)
              .animate()
              .fadeIn(duration: AppDurations.standard)
              .slideY(
                begin: 0.1,
                end: 0,
                duration: AppDurations.standard,
                curve: Curves.easeOutCubic,
              );
        }

        final record = _records[index - 1];
        return AttendanceCard(attendance: record)
            .animate()
            .fadeIn(
              duration: AppDurations.standard,
              delay: Duration(milliseconds: 100 * index),
            )
            .slideX(
              begin: 0.15,
              end: 0,
              duration: AppDurations.standard,
              delay: Duration(milliseconds: 100 * index),
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  Widget _buildSummaryCard(ColorScheme colors) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat.yMMMM().format(DateTime.now())} Summary',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Monthly: ${_formatHours(_totals.monthlyHours)}  |  Weekly: ${_formatHours(_totals.weeklyHours)}  |  Daily: ${_formatHours(_totals.dailyHours)}',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colors, String message) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child:
                  Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 80,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            message,
                            style: textTheme.titleMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Pull down to refresh',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: AppDurations.emphasis)
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1, 1),
                        duration: AppDurations.emphasis,
                      ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(ColorScheme colors) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 64,
                    color: colors.error.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _fetchRecords,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatHours(double hours) {
    final duration = Duration(minutes: (hours * 60).round());
    final days = duration.inDays;
    final h = duration.inHours.remainder(24);
    final m = duration.inMinutes.remainder(60);
    if (days > 0) return '${days}d ${h}h ${m}m';
    if (duration.inHours > 0) return '${duration.inHours}h ${m}m';
    return '${m}m';
  }
}

enum HistoryTab { today, last7Days, thisMonth }

extension on HistoryTab {
  ({DateTime start, DateTime end}) toDateRange(DateTime nowUtc) {
    final todayStart = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    switch (this) {
      case HistoryTab.today:
        return (
          start: todayStart,
          end: todayStart.add(const Duration(days: 1)),
        );
      case HistoryTab.last7Days:
        final start = todayStart.subtract(const Duration(days: 6));
        return (start: start, end: todayStart.add(const Duration(days: 1)));
      case HistoryTab.thisMonth:
        final start = DateTime.utc(nowUtc.year, nowUtc.month, 1);
        return (
          start: start,
          end: DateTime.utc(nowUtc.year, nowUtc.month + 1, 1),
        );
    }
  }

  String get emptyMessage {
    switch (this) {
      case HistoryTab.today:
        return 'No attendance records today';
      case HistoryTab.last7Days:
        return 'No attendance records in the last 7 days';
      case HistoryTab.thisMonth:
        return 'No attendance records this month';
    }
  }
}
