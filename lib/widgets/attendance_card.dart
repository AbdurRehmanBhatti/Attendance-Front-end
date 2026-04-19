import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../models/attendance.dart';

/// Expandable Material 3 card showing clock-in/out times and duration.
/// Supports tap-to-expand with animated arrow rotation and crossfade detail section.
class AttendanceCard extends StatefulWidget {
  final Attendance attendance;

  const AttendanceCard({super.key, required this.attendance});

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard> {
  bool _expanded = false;

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return DateFormat.jm().format(dt.toLocal());
  }

  String _fmtDuration(Duration? d) {
    if (d == null) return '--';
    final days = d.inDays;
    final h = d.inHours.remainder(24);
    final m = d.inMinutes.remainder(60);
    if (days > 0) return '${days}d ${h}h ${m}m';
    if (d.inHours > 0) return '${d.inHours}h ${m}m';
    return '${m}m';
  }

  String _fmtCoordinate(double? value) {
    if (value == null) return 'N/A';
    return value.toStringAsFixed(5);
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.attendance;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isActive = att.isClockedIn;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              // ── Main row ──
              Row(
                children: [
                  // Leading icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (isActive
                              ? Colors.green
                              : colors.primary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      isActive
                          ? Icons.timer_rounded
                          : Icons.timer_off_rounded,
                      color: isActive ? Colors.green : colors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Times
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_fmtTime(att.clockIn)}  →  ${_fmtTime(att.clockOut)}',
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isActive ? 'In progress' : 'Completed',
                          style: textTheme.bodySmall?.copyWith(
                            color: isActive
                                ? Colors.green
                                : colors.onSurfaceVariant,
                          ),
                        ),
                        if (att.hasPendingCorrection) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.errorContainer,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              'Pending correction',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onErrorContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Duration chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _fmtDuration(att.duration),
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onTertiaryContainer,
                      ),
                    ),
                  ),

                  // Expand arrow
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: AppDurations.fast,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              // ── Expandable detail ──
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Column(
                    children: [
                      Divider(color: colors.outlineVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: AppSpacing.sm),
                      _detailRow(
                        'Clock In',
                        _fmtTime(att.clockIn),
                        Icons.login_rounded,
                        Colors.green,
                        textTheme,
                        colors,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _detailRow(
                        'Clock Out',
                        _fmtTime(att.clockOut),
                        Icons.logout_rounded,
                        att.clockOut != null ? Colors.red : colors.outline,
                        textTheme,
                        colors,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _detailRow(
                        'Duration',
                        _fmtDuration(att.duration),
                        Icons.hourglass_bottom_rounded,
                        colors.tertiary,
                        textTheme,
                        colors,
                      ),
                      if (att.officeName != null || att.officeId != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _detailRow(
                          'Office',
                          att.officeName ?? att.officeId.toString(),
                          Icons.business_rounded,
                          colors.primary,
                          textTheme,
                          colors,
                        ),
                      ],
                      if (att.hasPendingCorrection) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _detailRow(
                          'Correction',
                          'Pending review',
                          Icons.pending_actions_rounded,
                          colors.error,
                          textTheme,
                          colors,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      _detailRow(
                        'Clock In GPS',
                        '${_fmtCoordinate(att.latitude)}, ${_fmtCoordinate(att.longitude)}',
                        Icons.location_on_outlined,
                        colors.primary,
                        textTheme,
                        colors,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _detailRow(
                        'Clock Out GPS',
                        '${_fmtCoordinate(att.clockOutLatitude)}, ${_fmtCoordinate(att.clockOutLongitude)}',
                        Icons.location_on_rounded,
                        colors.primary,
                        textTheme,
                        colors,
                      ),
                    ],
                  ),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: AppDurations.standard,
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    TextTheme textTheme,
    ColorScheme colors,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}
