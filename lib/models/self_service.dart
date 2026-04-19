class MeProfile {
  final int userId;
  final int companyId;
  final String companyName;
  final String name;
  final String email;
  final bool isActive;
  final DateTime? lastActivityAtUtc;

  const MeProfile({
    required this.userId,
    required this.companyId,
    required this.companyName,
    required this.name,
    required this.email,
    required this.isActive,
    required this.lastActivityAtUtc,
  });

  factory MeProfile.fromJson(Map<String, dynamic> json) {
    return MeProfile(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      companyId: (json['companyId'] as num?)?.toInt() ?? 0,
      companyName: json['companyName']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isActive: json['isActive'] as bool? ?? false,
      lastActivityAtUtc: DateTime.tryParse(json['lastActivityAtUtc']?.toString() ?? ''),
    );
  }
}

class MeLeaveBalanceResponse {
  final DateTime? asOfUtc;
  final int year;
  final List<MeLeaveBalanceItem> items;

  const MeLeaveBalanceResponse({
    required this.asOfUtc,
    required this.year,
    required this.items,
  });

  factory MeLeaveBalanceResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const <dynamic>[];
    return MeLeaveBalanceResponse(
      asOfUtc: DateTime.tryParse(json['asOfUtc']?.toString() ?? ''),
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(MeLeaveBalanceItem.fromJson)
          .toList(growable: false),
    );
  }
}

class MeLeaveBalanceItem {
  final String leaveType;
  final int entitledDays;
  final int approvedDays;
  final int pendingDays;
  final int remainingDays;

  const MeLeaveBalanceItem({
    required this.leaveType,
    required this.entitledDays,
    required this.approvedDays,
    required this.pendingDays,
    required this.remainingDays,
  });

  factory MeLeaveBalanceItem.fromJson(Map<String, dynamic> json) {
    return MeLeaveBalanceItem(
      leaveType: json['leaveType']?.toString() ?? 'unknown',
      entitledDays: (json['entitledDays'] as num?)?.toInt() ?? 0,
      approvedDays: (json['approvedDays'] as num?)?.toInt() ?? 0,
      pendingDays: (json['pendingDays'] as num?)?.toInt() ?? 0,
      remainingDays: (json['remainingDays'] as num?)?.toInt() ?? 0,
    );
  }
}

class MeScheduleResponse {
  final DateTime? periodStartUtc;
  final DateTime? periodEndUtc;
  final List<MeScheduleDay> days;

  const MeScheduleResponse({
    required this.periodStartUtc,
    required this.periodEndUtc,
    required this.days,
  });

  factory MeScheduleResponse.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? const <dynamic>[];
    return MeScheduleResponse(
      periodStartUtc: DateTime.tryParse(json['periodStartUtc']?.toString() ?? ''),
      periodEndUtc: DateTime.tryParse(json['periodEndUtc']?.toString() ?? ''),
      days: rawDays
          .whereType<Map<String, dynamic>>()
          .map(MeScheduleDay.fromJson)
          .toList(growable: false),
    );
  }
}

class MeScheduleDay {
  final DateTime? dateUtc;
  final String status;
  final String source;
  final int? shiftTemplateId;
  final String? shiftName;
  final int? startMinuteOfDayUtc;
  final int? endMinuteOfDayUtc;
  final int? lateGraceMinutes;
  final int? overtimeThresholdMinutes;
  final String? notes;

  const MeScheduleDay({
    required this.dateUtc,
    required this.status,
    required this.source,
    required this.shiftTemplateId,
    required this.shiftName,
    required this.startMinuteOfDayUtc,
    required this.endMinuteOfDayUtc,
    required this.lateGraceMinutes,
    required this.overtimeThresholdMinutes,
    required this.notes,
  });

  factory MeScheduleDay.fromJson(Map<String, dynamic> json) {
    return MeScheduleDay(
      dateUtc: DateTime.tryParse(json['dateUtc']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'unknown',
      source: json['source']?.toString() ?? 'unknown',
      shiftTemplateId: (json['shiftTemplateId'] as num?)?.toInt(),
      shiftName: json['shiftName']?.toString(),
      startMinuteOfDayUtc: (json['startMinuteOfDayUtc'] as num?)?.toInt(),
      endMinuteOfDayUtc: (json['endMinuteOfDayUtc'] as num?)?.toInt(),
      lateGraceMinutes: (json['lateGraceMinutes'] as num?)?.toInt(),
      overtimeThresholdMinutes: (json['overtimeThresholdMinutes'] as num?)?.toInt(),
      notes: json['notes']?.toString(),
    );
  }
}
