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
