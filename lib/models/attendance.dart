class Attendance {
  final int id;
  final int userId;
  final int? officeId;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final double? latitude;
  final double? longitude;
  final double? clockOutLatitude;
  final double? clockOutLongitude;

  Attendance({
    required this.id,
    required this.userId,
    this.officeId,
    this.clockIn,
    this.clockOut,
    this.latitude,
    this.longitude,
    this.clockOutLatitude,
    this.clockOutLongitude,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['attendanceId'] as int,
      userId: json['userId'] as int,
      officeId: json['officeId'] as int?,
      clockIn: json['clockInTime'] != null
          ? _parseApiUtcDateTime(json['clockInTime'] as String)
          : null,
      clockOut: json['clockOutTime'] != null
          ? _parseApiUtcDateTime(json['clockOutTime'] as String)
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      clockOutLatitude: (json['clockOutLatitude'] as num?)?.toDouble(),
      clockOutLongitude: (json['clockOutLongitude'] as num?)?.toDouble(),
    );
  }

  static DateTime _parseApiUtcDateTime(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    // ASP.NET may serialize UTC values without a timezone suffix.
    // If timezone info is missing, force UTC by appending 'Z'.
    final hasTimezone =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);

    final normalized = hasTimezone ? raw : '${raw}Z';
    return DateTime.parse(normalized).toUtc();
  }

  bool get isClockedIn => clockIn != null && clockOut == null;

  Duration? get duration {
    if (clockIn == null) return null;
    final end = clockOut ?? DateTime.now().toUtc();
    return end.difference(clockIn!);
  }
}
