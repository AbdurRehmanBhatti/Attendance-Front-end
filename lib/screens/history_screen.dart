import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/app_theme.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';
import '../widgets/attendance_card.dart';
import '../widgets/shimmer_list.dart';

class HistoryScreen extends StatefulWidget {
  final int userId;

  const HistoryScreen({super.key, required this.userId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _apiService = ApiService();

  List<Attendance> _records = [];
  bool _isLoading = true;
  String? _error;

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
      final records = await _apiService.getTodayAttendance(widget.userId);
      if (!mounted) return;
      setState(() {
        _records = records;
        _isLoading = false;
      });
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
      appBar: AppBar(
        title: const Text("Today's Attendance"),
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: _fetchRecords,
        child: _buildBody(colors),
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
      return _buildEmptyState(colors);
    }

    // List
    return _buildList();
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        return AttendanceCard(attendance: _records[index])
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

  Widget _buildEmptyState(ColorScheme colors) {
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
                    Icons.event_busy_rounded,
                    size: 80,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No attendance records today',
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Pull down to refresh',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
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
}
