class Attendance {
  final int id;
  final int userId;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final double? latitude;
  final double? longitude;

  Attendance({
    required this.id,
    required this.userId,
    this.clockIn,
    this.clockOut,
    this.latitude,
    this.longitude,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['attendanceId'] as int,
      userId: json['userId'] as int,
      clockIn: json['clockInTime'] != null
          ? DateTime.parse(json['clockInTime'] as String)
          : null,
      clockOut: json['clockOutTime'] != null
          ? DateTime.parse(json['clockOutTime'] as String)
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  bool get isClockedIn => clockIn != null && clockOut == null;

  Duration? get duration {
    if (clockIn == null) return null;
    final end = clockOut ?? DateTime.now();
    return end.difference(clockIn!);
  }
}
