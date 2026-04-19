import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../models/leave_management.dart';
import '../services/api_service.dart';
import '../services/auth_session_storage.dart';
import 'login_screen.dart';

class LeaveManagementScreen extends StatefulWidget {
  final ApiService? apiService;

  const LeaveManagementScreen({super.key, this.apiService});

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  late final ApiService _apiService;
  final _leaveReasonController = TextEditingController();
  final _correctionReasonController = TextEditingController();

  bool _loading = true;
  bool _submittingLeave = false;
  bool _submittingCorrection = false;
  List<HolidayEntry> _holidays = [];
  List<MyLeaveRequest> _leaveRequests = [];
  List<MyAttendanceCorrection> _correctionRequests = [];

  String _leaveType = 'vacation';
  DateTime _leaveStartDate = DateTime.now();
  DateTime _leaveEndDate = DateTime.now();
  DateTime _correctionDate = DateTime.now();
  DateTime? _correctionClockIn;
  DateTime? _correctionClockOut;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadData();
  }

  @override
  void dispose() {
    _leaveReasonController.dispose();
    _correctionReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final results = await Future.wait<dynamic>([
        _apiService.getMyHolidays(),
        _apiService.getMyLeaveRequests(),
        _apiService.getMyAttendanceCorrections(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _holidays = results[0] as List<HolidayEntry>;
        _leaveRequests = results[1] as List<MyLeaveRequest>;
        _correctionRequests = results[2] as List<MyAttendanceCorrection>;
        _loading = false;
      });
    } on UnauthorizedApiException catch (error) {
      if (!mounted) {
        return;
      }
      await _handleUnauthorized(error.message);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      _showSnack(error.message, isError: true);
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      _showSnack('Connection timed out. Please try again.', isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      _showSnack('Unable to load leave management right now.', isError: true);
    }
  }

  Future<void> _handleUnauthorized(String message) async {
    await AuthSessionStorage.clear();
    ApiService.clearSession();

    if (!mounted) {
      return;
    }

    _showSnack(message, isError: true);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _pickLeaveDate({required bool isStart}) async {
    final initialDate = isStart ? _leaveStartDate : _leaveEndDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _leaveStartDate = picked;
        if (_leaveEndDate.isBefore(picked)) {
          _leaveEndDate = picked;
        }
      } else {
        _leaveEndDate = picked;
      }
    });
  }

  Future<void> _pickCorrectionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _correctionDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() => _correctionDate = picked);
  }

  Future<void> _pickCorrectionTime({required bool isClockIn}) async {
    final selected = isClockIn ? _correctionClockIn : _correctionClockOut;
    final localSeed =
        selected ??
        DateTime(
          _correctionDate.year,
          _correctionDate.month,
          _correctionDate.day,
          isClockIn ? 9 : 17,
        );

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(localSeed),
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    final combined = DateTime(
      _correctionDate.year,
      _correctionDate.month,
      _correctionDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isClockIn) {
        _correctionClockIn = combined;
      } else {
        _correctionClockOut = combined;
      }
    });
  }

  Future<void> _submitLeaveRequest() async {
    final reason = _leaveReasonController.text.trim();
    if (_leaveEndDate.isBefore(_leaveStartDate)) {
      _showSnack(
        'End date cannot be earlier than the start date.',
        isError: true,
      );
      return;
    }

    setState(() => _submittingLeave = true);
    try {
      await _apiService.createMyLeaveRequest(
        leaveType: _leaveType,
        startDateUtc: _leaveStartDate,
        endDateUtc: _leaveEndDate,
        reason: reason.isEmpty ? null : reason,
      );

      if (!mounted) {
        return;
      }

      _leaveReasonController.clear();
      await _loadData();
      _showSnack('Leave request submitted successfully.');
    } on UnauthorizedApiException catch (error) {
      if (!mounted) {
        return;
      }
      await _handleUnauthorized(error.message);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _submittingLeave = false);
      }
    }
  }

  Future<void> _submitCorrectionRequest() async {
    if (_correctionClockIn == null && _correctionClockOut == null) {
      _showSnack(
        'Select a corrected clock-in or clock-out time.',
        isError: true,
      );
      return;
    }

    final reason = _correctionReasonController.text.trim();
    if (reason.isEmpty) {
      _showSnack('Please provide a reason for the correction.', isError: true);
      return;
    }

    setState(() => _submittingCorrection = true);
    try {
      await _apiService.createMyAttendanceCorrection(
        requestDateUtc: _correctionDate,
        requestedClockInTimeUtc: _correctionClockIn,
        requestedClockOutTimeUtc: _correctionClockOut,
        reason: reason,
      );

      if (!mounted) {
        return;
      }

      _correctionReasonController.clear();
      setState(() {
        _correctionClockIn = null;
        _correctionClockOut = null;
      });
      await _loadData();
      _showSnack('Attendance correction request submitted successfully.');
    } on UnauthorizedApiException catch (error) {
      if (!mounted) {
        return;
      }
      await _handleUnauthorized(error.message);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _submittingCorrection = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? colors.errorContainer
            : colors.secondaryContainer,
      ),
    );
  }

  String _formatDate(DateTime value) =>
      DateFormat.yMMMd().format(value.toLocal());

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '—';
    }
    return DateFormat.yMMMd().add_jm().format(value.toLocal());
  }

  Color _statusColor(String status, ColorScheme colors) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return colors.error;
      default:
        return colors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leave & Corrections'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Holidays'),
              Tab(text: 'Leave'),
              Tab(text: 'Corrections'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        Text(
                          'Company Holidays',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'These dates are configured by your admin so you can plan leave more accurately.',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_holidays.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              child: Text(
                                'No company holidays have been published yet.',
                              ),
                            ),
                          )
                        else
                          ..._holidays.map(
                            (holiday) => Card(
                              child: ListTile(
                                leading: Icon(
                                  Icons.event_available_rounded,
                                  color: colors.primary,
                                ),
                                title: Text(holiday.name),
                                subtitle: Text(
                                  '${_formatDate(holiday.dateUtc)}${holiday.isRecurringAnnual ? ' • Repeats yearly' : ''}${holiday.notes != null && holiday.notes!.trim().isNotEmpty ? '\n${holiday.notes!}' : ''}',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Request Leave',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                DropdownButtonFormField<String>(
                                  initialValue: _leaveType,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Leave type',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'vacation',
                                      child: Text(
                                        'Vacation',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'sick',
                                      child: Text(
                                        'Sick',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'unpaid',
                                      child: Text(
                                        'Unpaid',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'remote',
                                      child: Text(
                                        'Remote / Work From Home',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    setState(() => _leaveType = value);
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _pickLeaveDate(isStart: true),
                                        icon: const Icon(
                                          Icons.date_range_rounded,
                                        ),
                                        label: Text(
                                          'Start: ${_formatDate(_leaveStartDate)}',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _pickLeaveDate(isStart: false),
                                        icon: const Icon(Icons.event_rounded),
                                        label: Text(
                                          'End: ${_formatDate(_leaveEndDate)}',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextField(
                                  controller: _leaveReasonController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Reason (optional)',
                                    hintText:
                                        'Add context for your manager or admin',
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _submittingLeave
                                        ? null
                                        : _submitLeaveRequest,
                                    icon: _submittingLeave
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.send_rounded),
                                    label: Text(
                                      _submittingLeave
                                          ? 'Submitting...'
                                          : 'Submit Leave Request',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'My Leave Requests',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (_leaveRequests.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              child: Text(
                                'You have not submitted any leave requests yet.',
                              ),
                            ),
                          )
                        else
                          ..._leaveRequests.map(
                            (request) => Card(
                              child: ListTile(
                                title: Text(
                                  '${request.leaveType.toUpperCase()} • ${_formatDate(request.startDateUtc)} - ${_formatDate(request.endDateUtc)}',
                                ),
                                subtitle: Text(
                                  request.reason?.trim().isNotEmpty == true
                                      ? request.reason!
                                      : 'No reason provided',
                                ),
                                trailing: Text(
                                  request.status.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor(request.status, colors),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Request Attendance Correction',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Use this if you missed a clock in or out because of network, battery, or device issues.',
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _pickCorrectionDate,
                                    icon: const Icon(Icons.date_range_rounded),
                                    label: Text(
                                      'Date: ${_formatDate(_correctionDate)}',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _pickCorrectionTime(isClockIn: true),
                                    icon: const Icon(Icons.login_rounded),
                                    label: Text(
                                      'Corrected Clock In: ${_formatDateTime(_correctionClockIn)}',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _pickCorrectionTime(isClockIn: false),
                                    icon: const Icon(Icons.logout_rounded),
                                    label: Text(
                                      'Corrected Clock Out: ${_formatDateTime(_correctionClockOut)}',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextField(
                                  controller: _correctionReasonController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Reason',
                                    hintText: 'Explain what happened',
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _submittingCorrection
                                        ? null
                                        : _submitCorrectionRequest,
                                    icon: _submittingCorrection
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.fact_check_rounded),
                                    label: Text(
                                      _submittingCorrection
                                          ? 'Submitting...'
                                          : 'Submit Correction Request',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'My Correction Requests',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (_correctionRequests.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              child: Text(
                                'You have not submitted any attendance correction requests yet.',
                              ),
                            ),
                          )
                        else
                          ..._correctionRequests.map(
                            (request) => Card(
                              child: ListTile(
                                title: Text(
                                  'For ${_formatDate(request.requestDateUtc)}',
                                ),
                                subtitle: Text(
                                  'In: ${_formatDateTime(request.requestedClockInTimeUtc)}\nOut: ${_formatDateTime(request.requestedClockOutTimeUtc)}\n${request.reason}',
                                ),
                                trailing: Text(
                                  request.status.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor(request.status, colors),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
