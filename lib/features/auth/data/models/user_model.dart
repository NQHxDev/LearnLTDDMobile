enum UserRoleType {
  admin,
  staff,
  user;

  static UserRoleType fromString(String? role) {
    if (role == null) return UserRoleType.user;
    final r = role.trim().toLowerCase();
    if (r == 'admin') return UserRoleType.admin;
    if (r == 'staff') return UserRoleType.staff;
    return UserRoleType.user;
  }

  String get label {
    switch (this) {
      case UserRoleType.admin:
        return 'ADMIN';
      case UserRoleType.staff:
        return 'STAFF';
      case UserRoleType.user:
        return 'USER';
    }
  }

  String get displayName {
    switch (this) {
      case UserRoleType.admin:
        return 'Quản trị viên (ADMIN)';
      case UserRoleType.staff:
        return 'Nhân viên vận hành (STAFF)';
      case UserRoleType.user:
        return 'Người dùng / Phụ huynh (USER)';
    }
  }

  String get shortName {
    switch (this) {
      case UserRoleType.admin:
        return 'Quản trị viên';
      case UserRoleType.staff:
        return 'Nhân viên';
      case UserRoleType.user:
        return 'Phụ huynh';
    }
  }
}

class User {
  final int id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String role;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.role,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final email = json['email']?.toString() ?? '';
    final rawRole = json['role']?.toString().trim();
    // Mặc định gán Role là User nếu chưa được chỉ định
    final resolvedRole = (rawRole == null || rawRole.isEmpty) ? 'User' : rawRole;

    return User(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      email: email,
      fullName: json['fullName']?.toString() ?? email,
      phoneNumber: json['phoneNumber']?.toString(),
      role: resolvedRole,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  UserRoleType get roleType => UserRoleType.fromString(role);
  bool get isAdmin => roleType == UserRoleType.admin;
  bool get isStaff => roleType == UserRoleType.staff;
  bool get isUser => roleType == UserRoleType.user;

  User copyWith({
    int? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    String? role,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
