import 'attendance.dart';

class AttendanceSummaryTotals {
  final double dailyHours;
  final double weeklyHours;
  final double monthlyHours;
  final int dailySessions;
  final int weeklySessions;
  final int monthlySessions;

  const AttendanceSummaryTotals({
    required this.dailyHours,
    required this.weeklyHours,
    required this.monthlyHours,
    required this.dailySessions,
    required this.weeklySessions,
    required this.monthlySessions,
  });

  factory AttendanceSummaryTotals.fromJson(Map<String, dynamic> json) {
    return AttendanceSummaryTotals(
      dailyHours: (json['dailyHours'] as num?)?.toDouble() ?? 0,
      weeklyHours: (json['weeklyHours'] as num?)?.toDouble() ?? 0,
      monthlyHours: (json['monthlyHours'] as num?)?.toDouble() ?? 0,
      dailySessions: (json['dailySessions'] as num?)?.toInt() ?? 0,
      weeklySessions: (json['weeklySessions'] as num?)?.toInt() ?? 0,
      monthlySessions: (json['monthlySessions'] as num?)?.toInt() ?? 0,
    );
  }

  static const zero = AttendanceSummaryTotals(
    dailyHours: 0,
    weeklyHours: 0,
    monthlyHours: 0,
    dailySessions: 0,
    weeklySessions: 0,
    monthlySessions: 0,
  );
}

class AttendanceHistoryResponse {
  final DateTime rangeStartUtc;
  final DateTime rangeEndUtc;
  final List<Attendance> records;
  final AttendanceSummaryTotals totals;

  const AttendanceHistoryResponse({
    required this.rangeStartUtc,
    required this.rangeEndUtc,
    required this.records,
    required this.totals,
  });

  factory AttendanceHistoryResponse.fromJson(Map<String, dynamic> json) {
    final recordsJson = json['records'] as List<dynamic>? ?? const [];
    return AttendanceHistoryResponse(
      rangeStartUtc: _parseApiUtcDateTime(json['rangeStartUtc'] as String?),
      rangeEndUtc: _parseApiUtcDateTime(json['rangeEndUtc'] as String?),
      records: recordsJson
          .map((e) => Attendance.fromJson(e as Map<String, dynamic>))
          .toList(),
      totals: AttendanceSummaryTotals.fromJson(
        (json['totals'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  static DateTime _parseApiUtcDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    final raw = value.trim();
    final hasTimezone =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);

    final normalized = hasTimezone ? raw : '${raw}Z';
    return DateTime.parse(normalized).toUtc();
  }
}

class AttendanceHistoryDetailResponse {
  final DateTime periodStartUtc;
  final DateTime periodEndUtc;
  final List<AttendanceHistoryDetailItem> items;

  const AttendanceHistoryDetailResponse({
    required this.periodStartUtc,
    required this.periodEndUtc,
    required this.items,
  });

  factory AttendanceHistoryDetailResponse.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? const <dynamic>[];
    return AttendanceHistoryDetailResponse(
      periodStartUtc: _parseApiUtcDateTime(json['periodStartUtc'] as String?),
      periodEndUtc: _parseApiUtcDateTime(json['periodEndUtc'] as String?),
      items: itemsJson
          .whereType<Map<String, dynamic>>()
          .map(AttendanceHistoryDetailItem.fromJson)
          .toList(growable: false),
    );
  }

  List<Attendance> toAttendanceRecords({required int userId}) {
    return items
        .map(
          (item) => Attendance(
            id: item.attendanceId,
            userId: userId,
            officeId: item.officeId,
            officeName: item.officeName,
            clockIn: item.clockInTimeUtc,
            clockOut: item.clockOutTimeUtc,
            latitude: item.clockInLatitude,
            longitude: item.clockInLongitude,
            clockOutLatitude: item.clockOutLatitude,
            clockOutLongitude: item.clockOutLongitude,
            hasPendingCorrection: item.hasPendingCorrection,
          ),
        )
        .toList(growable: false);
  }

  static DateTime _parseApiUtcDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    final raw = value.trim();
    final hasTimezone =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);

    final normalized = hasTimezone ? raw : '${raw}Z';
    return DateTime.parse(normalized).toUtc();
  }
}

class AttendanceHistoryDetailItem {
  final int attendanceId;
  final int? officeId;
  final String? officeName;
  final DateTime? clockInTimeUtc;
  final DateTime? clockOutTimeUtc;
  final int durationMinutes;
  final double? clockInLatitude;
  final double? clockInLongitude;
  final double? clockOutLatitude;
  final double? clockOutLongitude;
  final bool hasPendingCorrection;

  const AttendanceHistoryDetailItem({
    required this.attendanceId,
    required this.officeId,
    required this.officeName,
    required this.clockInTimeUtc,
    required this.clockOutTimeUtc,
    required this.durationMinutes,
    required this.clockInLatitude,
    required this.clockInLongitude,
    required this.clockOutLatitude,
    required this.clockOutLongitude,
    required this.hasPendingCorrection,
  });

  factory AttendanceHistoryDetailItem.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryDetailItem(
      attendanceId: (json['attendanceId'] as num?)?.toInt() ?? 0,
      officeId: (json['officeId'] as num?)?.toInt(),
      officeName: json['officeName']?.toString(),
      clockInTimeUtc: _parseOptionalApiUtcDateTime(
        json['clockInTimeUtc']?.toString(),
      ),
      clockOutTimeUtc: _parseOptionalApiUtcDateTime(
        json['clockOutTimeUtc']?.toString(),
      ),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      clockInLatitude: (json['clockInLatitude'] as num?)?.toDouble(),
      clockInLongitude: (json['clockInLongitude'] as num?)?.toDouble(),
      clockOutLatitude: (json['clockOutLatitude'] as num?)?.toDouble(),
      clockOutLongitude: (json['clockOutLongitude'] as num?)?.toDouble(),
      hasPendingCorrection: json['hasPendingCorrection'] as bool? ?? false,
    );
  }

  static DateTime _parseApiUtcDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    final raw = value.trim();
    final hasTimezone =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);

    final normalized = hasTimezone ? raw : '${raw}Z';
    return DateTime.parse(normalized).toUtc();
  }

  static DateTime? _parseOptionalApiUtcDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return _parseApiUtcDateTime(value);
  }
}
