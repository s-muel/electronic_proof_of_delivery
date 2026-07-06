class AppUserModel {
  final String userId;
  final String fullName;
  final String email;
  final String role;
  final String department;
  final String tempPass;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const AppUserModel({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    this.department = '',
    this.tempPass = '',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUserModel.fromMap(Map<String, dynamic> map) {
    return AppUserModel(
      userId: map['userId'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      department: map['department'] ?? '',
      tempPass: map['tempPass'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] ?? '',
      updatedAt: map['updatedAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'role': role,
      'department': department,
      'tempPass': tempPass,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  AppUserModel copyWith({
    String? userId,
    String? fullName,
    String? email,
    String? role,
    String? department,
    String? tempPass,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return AppUserModel(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      tempPass: tempPass ?? this.tempPass,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
