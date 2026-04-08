class SelfDeleteAccountResponse {
  final bool forceLogout;
  final DateTime deletedAtUtc;
  final String status;
  final String message;

  const SelfDeleteAccountResponse({
    required this.forceLogout,
    required this.deletedAtUtc,
    required this.status,
    required this.message,
  });

  factory SelfDeleteAccountResponse.fromJson(Map<String, dynamic> json) {
    final deletedAtRaw = (json['deletedAtUtc'] as String?) ?? '';
    final deletedAt =
        DateTime.tryParse(deletedAtRaw)?.toUtc() ?? DateTime.now().toUtc();

    return SelfDeleteAccountResponse(
      forceLogout: (json['forceLogout'] as bool?) ?? true,
      deletedAtUtc: deletedAt,
      status: (json['status'] as String?) ?? 'Unknown',
      message:
          (json['message'] as String?) ??
          'Your account was deleted successfully. You have been signed out.',
    );
  }
}
