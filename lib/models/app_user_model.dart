class AppUserModel {
  final String userId;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const AppUserModel({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
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
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return AppUserModel(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
