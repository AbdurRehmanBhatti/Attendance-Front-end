class User {
  final int id;
  final int companyId;
  final String companyName;
  final String name;
  final String email;
  final String token;
  final List<String> roles;

  User({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.name,
    required this.email,
    required this.token,
    required this.roles,
  });

  bool get isAdmin =>
      roles.any((role) => role.toLowerCase() == 'admin');

  bool get isEmployee =>
      roles.any((role) => role.toLowerCase() == 'employee');

  factory User.fromJson(Map<String, dynamic> json) {
    final userIdValue = json['userId'] ?? json['id'];
    final companyIdValue = json['companyId'];
    final companyId = companyIdValue as int;
    final companyNameValue = json['companyName'];
    final rolesValue = json['roles'];

    final roles = rolesValue is List
        ? rolesValue.map((role) => role.toString()).toList(growable: false)
        : const <String>[];

    return User(
      id: userIdValue as int,
      companyId: companyId,
        companyName: (companyNameValue is String && companyNameValue.trim().isNotEmpty)
          ? companyNameValue
        : 'Company $companyId',
      name: json['name'] as String,
      email: json['email'] as String,
      token: json['token'] as String,
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
      'roles': roles,
    };
  }
}
