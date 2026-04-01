class User {
  final int id;
  final int? companyId;
  final String companyName;
  final String name;
  final String email;
  final String token;
  final DateTime accessTokenExpiresAtUtc;
  final String refreshToken;
  final DateTime refreshTokenExpiresAtUtc;
  final bool requirePasswordChangeOnNextLogin;
  final List<String> roles;

  User({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.name,
    required this.email,
    required this.token,
    required this.accessTokenExpiresAtUtc,
    required this.refreshToken,
    required this.refreshTokenExpiresAtUtc,
    required this.requirePasswordChangeOnNextLogin,
    required this.roles,
  });

  User copyWith({
    int? id,
    int? companyId,
    String? companyName,
    String? name,
    String? email,
    String? token,
    DateTime? accessTokenExpiresAtUtc,
    String? refreshToken,
    DateTime? refreshTokenExpiresAtUtc,
    bool? requirePasswordChangeOnNextLogin,
    List<String>? roles,
  }) {
    return User(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      name: name ?? this.name,
      email: email ?? this.email,
      token: token ?? this.token,
      accessTokenExpiresAtUtc:
          accessTokenExpiresAtUtc ?? this.accessTokenExpiresAtUtc,
      refreshToken: refreshToken ?? this.refreshToken,
      refreshTokenExpiresAtUtc:
          refreshTokenExpiresAtUtc ?? this.refreshTokenExpiresAtUtc,
      requirePasswordChangeOnNextLogin: requirePasswordChangeOnNextLogin ??
          this.requirePasswordChangeOnNextLogin,
      roles: roles ?? this.roles,
    );
  }

  bool get isAdmin =>
      roles.any((role) => role.toLowerCase() == 'admin');

  bool get isEmployee =>
      roles.any((role) => role.toLowerCase() == 'employee');

  static DateTime _parseUtcDateTime(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed.toUtc();
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final userIdValue = json['userId'] ?? json['id'];
    final companyIdValue = json['companyId'];
    final companyId = companyIdValue as int?;
    final companyNameValue = json['companyName'];
    final rolesValue = json['roles'];

    final roles = rolesValue is List
        ? rolesValue.map((role) => role.toString()).toList(growable: false)
        : const <String>[];

    return User(
      id: userIdValue as int,
      companyId: companyId,
      companyName: (companyNameValue is String &&
              companyNameValue.trim().isNotEmpty)
          ? companyNameValue
          : (companyId != null ? 'Company $companyId' : 'Unknown Company'),
      name: json['name'] as String,
      email: json['email'] as String,
      token: json['token'] as String,
      accessTokenExpiresAtUtc:
          _parseUtcDateTime(json['accessTokenExpiresAtUtc']),
      refreshToken: (json['refreshToken'] as String?) ?? '',
      refreshTokenExpiresAtUtc:
          _parseUtcDateTime(json['refreshTokenExpiresAtUtc']),
      requirePasswordChangeOnNextLogin:
          (json['requirePasswordChangeOnNextLogin'] as bool?) ?? false,
      roles: roles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': id,
      'companyId': companyId,
      'companyName': companyName,
      'name': name,
      'email': email,
      'token': token,
      'accessTokenExpiresAtUtc': accessTokenExpiresAtUtc.toUtc().toIso8601String(),
      'refreshToken': refreshToken,
      'refreshTokenExpiresAtUtc':
          refreshTokenExpiresAtUtc.toUtc().toIso8601String(),
      'requirePasswordChangeOnNextLogin': requirePasswordChangeOnNextLogin,
      'roles': roles,
    };
  }
}
