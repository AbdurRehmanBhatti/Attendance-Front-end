class AccountDeletionRequestResponse {
  final int requestId;
  final String status;
  final String message;
  final bool verificationRequired;
  final DateTime requestedAtUtc;

  const AccountDeletionRequestResponse({
    required this.requestId,
    required this.status,
    required this.message,
    required this.verificationRequired,
    required this.requestedAtUtc,
  });

  factory AccountDeletionRequestResponse.fromJson(Map<String, dynamic> json) {
    return AccountDeletionRequestResponse(
      requestId: (json['requestId'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'Unknown',
      message: (json['message'] as String?) ?? 'Request submitted.',
      verificationRequired: (json['verificationRequired'] as bool?) ?? false,
      requestedAtUtc: DateTime.parse(
        (json['requestedAtUtc'] as String?) ?? '',
      ).toUtc(),
    );
  }
}

class AccountDeletionMyRequestStatusResponse {
  final int requestId;
  final String status;
  final String source;
  final DateTime requestedAtUtc;
  final DateTime? reviewedAtUtc;
  final DateTime? completedAtUtc;
  final String? adminDecisionNote;

  const AccountDeletionMyRequestStatusResponse({
    required this.requestId,
    required this.status,
    required this.source,
    required this.requestedAtUtc,
    required this.reviewedAtUtc,
    required this.completedAtUtc,
    required this.adminDecisionNote,
  });

  bool get isTerminal =>
      status == 'Completed' ||
      status == 'Rejected' ||
      status == 'Cancelled' ||
      status == 'Expired';

  factory AccountDeletionMyRequestStatusResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    DateTime? parseOptionalDate(String key) {
      final raw = json[key] as String?;
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }

      return DateTime.parse(raw).toUtc();
    }

    return AccountDeletionMyRequestStatusResponse(
      requestId: (json['requestId'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'Unknown',
      source: (json['source'] as String?) ?? 'Unknown',
      requestedAtUtc: DateTime.parse(
        (json['requestedAtUtc'] as String?) ?? '',
      ).toUtc(),
      reviewedAtUtc: parseOptionalDate('reviewedAtUtc'),
      completedAtUtc: parseOptionalDate('completedAtUtc'),
      adminDecisionNote: json['adminDecisionNote']?.toString(),
    );
  }
}
