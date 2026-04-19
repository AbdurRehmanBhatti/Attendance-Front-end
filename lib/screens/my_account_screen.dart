import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../models/self_service.dart';
import '../screens/change_password_screen.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../services/auth_session_storage.dart';

class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key});

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  final _apiService = ApiService();

  bool _isLoading = true;
  String? _error;
  MeProfile? _profile;
  MeLeaveBalanceResponse? _leaveBalance;
  MeScheduleResponse? _schedule;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now().toUtc();
      final start = DateTime.utc(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 14));

      final results = await Future.wait<dynamic>([
        _apiService.getMyProfile(),
        _apiService.getMyLeaveBalance(year: now.year),
        _apiService.getMySchedule(startUtc: start, endUtc: end),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = results[0] as MeProfile;
        _leaveBalance = results[1] as MeLeaveBalanceResponse;
        _schedule = results[2] as MeScheduleResponse;
        _isLoading = false;
      });
    } on PasswordChangeRequiredApiException {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen()),
        (route) => false,
      );
    } on UnauthorizedApiException catch (error) {
      ApiService.clearSession();
      await AuthSessionStorage.clear();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Failed to load account details.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Account')),
        body: const Center(child: Text('Account details are unavailable right now.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAccountData,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: colors.primaryContainer,
                            child: Text(
                              (_profile?.name ?? user.name).trim().isEmpty
                                  ? 'U'
                                  : (_profile?.name ?? user.name)
                                      .trim()
                                      .substring(0, 1)
                                      .toUpperCase(),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profile?.name ?? user.name,
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _profile?.email ?? user.email,
                                  style: textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _MetaChip(
                            icon: Icons.verified_user_outlined,
                            label: _profile?.isActive == false
                                ? 'Inactive'
                                : 'Active',
                          ),
                          _MetaChip(
                            icon: Icons.business_outlined,
                            label: _profile?.companyName.isNotEmpty == true
                                ? _profile!.companyName
                                : user.companyName,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _isLoading
                            ? 'Loading your profile and account metrics...'
                            : 'Live account details are shown below, including leave balance and shift plan.',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading) ...[
                const SizedBox(height: AppSpacing.md),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _IdentitySection(
                employeeId: (_profile?.userId ?? user.id).toString(),
                companyId:
                    (_profile?.companyId ?? user.companyId)?.toString() ??
                    'Not assigned',
                companyName: _profile?.companyName.isNotEmpty == true
                    ? _profile!.companyName
                    : user.companyName,
                onCopy: (label, value) => _copyToClipboard(context, label, value),
              ),
              const SizedBox(height: AppSpacing.md),
              _LeaveBalanceSection(leaveBalance: _leaveBalance),
              const SizedBox(height: AppSpacing.md),
              _ScheduleSection(schedule: _schedule),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }

    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied.'),
        backgroundColor: colors.secondaryContainer,
      ),
    );
  }
}

class _LeaveBalanceSection extends StatelessWidget {
  final MeLeaveBalanceResponse? leaveBalance;

  const _LeaveBalanceSection({required this.leaveBalance});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final balance = leaveBalance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leave Balance ${balance?.year ?? DateTime.now().year}',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Approved and pending requests reflected live.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (balance == null || balance.items.isEmpty)
              Text('No leave balance data available yet.', style: textTheme.bodyMedium)
            else
              ...balance.items.map(
                (item) => _LeaveBalanceRow(item: item),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  final MeScheduleResponse? schedule;

  const _ScheduleSection({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final upcoming =
      schedule?.days.take(7).toList(growable: false) ?? const <MeScheduleDay>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upcoming Schedule',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Next 7 days', style: textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            if (upcoming.isEmpty)
              Text('No schedule assignments found.', style: textTheme.bodyMedium)
            else
              ...upcoming.map((day) => _ScheduleRow(day: day)),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? dateUtc) {
    if (dateUtc == null) {
      return 'Unknown date';
    }

    return DateFormat('EEE, d MMM').format(dateUtc.toLocal());
  }

  static String _formatShiftWindow(MeScheduleDay day) {
    if (day.startMinuteOfDayUtc == null || day.endMinuteOfDayUtc == null) {
      return '';
    }

    String toLabel(int minute) {
      final hours = ((minute ~/ 60) % 24).toString().padLeft(2, '0');
      final mins = (minute % 60).toString().padLeft(2, '0');
      return '$hours:$mins UTC';
    }

    return '${toLabel(day.startMinuteOfDayUtc!)}-${toLabel(day.endMinuteOfDayUtc!)}';
  }
}

class _IdentitySection extends StatelessWidget {
  final String employeeId;
  final String companyId;
  final String companyName;
  final Future<void> Function(String label, String value) onCopy;

  const _IdentitySection({
    required this.employeeId,
    required this.companyId,
    required this.companyName,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            _InfoTile(
              label: 'Employee ID',
              value: employeeId,
              onCopy: () => onCopy('Employee ID', employeeId),
            ),
            const Divider(height: 1),
            _InfoTile(
              label: 'Company ID',
              value: companyId,
              onCopy: () => onCopy('Company ID', companyId),
            ),
            const Divider(height: 1),
            _InfoTile(
              label: 'Company',
              value: companyName,
              onCopy: () => onCopy('Company', companyName),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.onSecondaryContainer),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: colors.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveBalanceRow extends StatelessWidget {
  final MeLeaveBalanceItem item;

  const _LeaveBalanceRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final total = item.entitledDays <= 0 ? 1 : item.entitledDays;
    final ratio = (item.remainingDays / total).clamp(0, 1).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.leaveType.toUpperCase(),
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${item.remainingDays} / ${item.entitledDays}',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(value: ratio, minHeight: 6),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Approved ${item.approvedDays}, Pending ${item.pendingDays}',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final MeScheduleDay day;

  const _ScheduleRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ScheduleSection._formatDate(day.dateUtc),
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  day.shiftName == null
                      ? 'No shift assigned'
                      : '${day.shiftName} ${_ScheduleSection._formatShiftWindow(day)}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatusPill(status: day.status),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final normalized = status.trim().toLowerCase();
    final isScheduled = normalized == 'scheduled';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isScheduled
            ? colors.tertiaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        status.toUpperCase(),
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: isScheduled ? colors.onTertiaryContainer : colors.onSurface,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(value, style: textTheme.bodyLarge),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: onCopy == null ? 'Not available' : 'Copy $label',
          ),
        ],
      ),
    );
  }
}
