class HolidayEntry {
  final int holidayId;
  final String name;
  final DateTime dateUtc;
  final bool isRecurringAnnual;
  final String? notes;

  const HolidayEntry({
    required this.holidayId,
    required this.name,
    required this.dateUtc,
    required this.isRecurringAnnual,
    this.notes,
  });

  factory HolidayEntry.fromJson(Map<String, dynamic> json) {
    return HolidayEntry(
      holidayId: json['holidayId'] as int,
      name: (json['name'] as String?) ?? '',
      dateUtc: DateTime.parse((json['dateUtc'] as String?) ?? '').toUtc(),
      isRecurringAnnual: (json['isRecurringAnnual'] as bool?) ?? false,
      notes: json['notes'] as String?,
    );
  }
}

class MyLeaveRequest {
  final int leaveRequestId;
  final int employeeId;
  final String leaveType;
  final DateTime startDateUtc;
  final DateTime endDateUtc;
  final String status;
  final String? reason;
  final String? reviewNotes;
  final DateTime? reviewedAtUtc;
  final DateTime requestedAtUtc;

  const MyLeaveRequest({
    required this.leaveRequestId,
    required this.employeeId,
    required this.leaveType,
    required this.startDateUtc,
    required this.endDateUtc,
    required this.status,
    this.reason,
    this.reviewNotes,
    this.reviewedAtUtc,
    required this.requestedAtUtc,
  });

  factory MyLeaveRequest.fromJson(Map<String, dynamic> json) {
    return MyLeaveRequest(
      leaveRequestId: json['leaveRequestId'] as int,
      employeeId: json['employeeId'] as int,
      leaveType: (json['leaveType'] as String?) ?? '',
      startDateUtc: DateTime.parse(
        (json['startDateUtc'] as String?) ?? '',
      ).toUtc(),
      endDateUtc: DateTime.parse((json['endDateUtc'] as String?) ?? '').toUtc(),
      status: (json['status'] as String?) ?? 'pending',
      reason: json['reason'] as String?,
      reviewNotes: json['reviewNotes'] as String?,
      reviewedAtUtc: json['reviewedAtUtc'] == null
          ? null
          : DateTime.parse(json['reviewedAtUtc'] as String).toUtc(),
      requestedAtUtc: DateTime.parse(
        (json['requestedAtUtc'] as String?) ?? '',
      ).toUtc(),
    );
  }
}

class MyAttendanceCorrection {
  final int attendanceCorrectionRequestId;
  final int employeeId;
  final int? attendanceId;
  final DateTime requestDateUtc;
  final DateTime? requestedClockInTimeUtc;
  final DateTime? requestedClockOutTimeUtc;
  final String status;
  final String reason;
  final String? reviewNotes;
  final DateTime? reviewedAtUtc;
  final DateTime requestedAtUtc;

  const MyAttendanceCorrection({
    required this.attendanceCorrectionRequestId,
    required this.employeeId,
    required this.attendanceId,
    required this.requestDateUtc,
    this.requestedClockInTimeUtc,
    this.requestedClockOutTimeUtc,
    required this.status,
    required this.reason,
    this.reviewNotes,
    this.reviewedAtUtc,
    required this.requestedAtUtc,
  });

  factory MyAttendanceCorrection.fromJson(Map<String, dynamic> json) {
    return MyAttendanceCorrection(
      attendanceCorrectionRequestId:
          json['attendanceCorrectionRequestId'] as int,
      employeeId: json['employeeId'] as int,
      attendanceId: json['attendanceId'] as int?,
      requestDateUtc: DateTime.parse(
        (json['requestDateUtc'] as String?) ?? '',
      ).toUtc(),
      requestedClockInTimeUtc: json['requestedClockInTimeUtc'] == null
          ? null
          : DateTime.parse(json['requestedClockInTimeUtc'] as String).toUtc(),
      requestedClockOutTimeUtc: json['requestedClockOutTimeUtc'] == null
          ? null
          : DateTime.parse(json['requestedClockOutTimeUtc'] as String).toUtc(),
      status: (json['status'] as String?) ?? 'pending',
      reason: (json['reason'] as String?) ?? '',
      reviewNotes: json['reviewNotes'] as String?,
      reviewedAtUtc: json['reviewedAtUtc'] == null
          ? null
          : DateTime.parse(json['reviewedAtUtc'] as String).toUtc(),
      requestedAtUtc: DateTime.parse(
        (json['requestedAtUtc'] as String?) ?? '',
      ).toUtc(),
    );
  }
}
