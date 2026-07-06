import 'app_user_model.dart';

class UserStatsModel {
  final int total;
  final int active;
  final int inactive;
  final int officers;
  final int drivers;
  final int accounts;
  final int management;
  final int managers;
  final int superUsers;
  final String updatedAt;

  const UserStatsModel({
    required this.total,
    required this.active,
    required this.inactive,
    required this.officers,
    required this.drivers,
    required this.accounts,
    required this.management,
    required this.managers,
    required this.superUsers,
    required this.updatedAt,
  });

  factory UserStatsModel.empty() {
    return const UserStatsModel(
      total: 0,
      active: 0,
      inactive: 0,
      officers: 0,
      drivers: 0,
      accounts: 0,
      management: 0,
      managers: 0,
      superUsers: 0,
      updatedAt: '',
    );
  }

  factory UserStatsModel.fromMap(Map<String, dynamic> map) {
    return UserStatsModel(
      total: (map['total'] as num?)?.toInt() ?? 0,
      active: (map['active'] as num?)?.toInt() ?? 0,
      inactive: (map['inactive'] as num?)?.toInt() ?? 0,
      officers: (map['officers'] as num?)?.toInt() ?? 0,
      drivers: (map['drivers'] as num?)?.toInt() ?? 0,
      accounts: (map['accounts'] as num?)?.toInt() ?? 0,
      management: (map['management'] as num?)?.toInt() ?? 0,
      managers: (map['managers'] as num?)?.toInt() ?? 0,
      superUsers: (map['superUsers'] as num?)?.toInt() ?? 0,
      updatedAt: map['updatedAt'] ?? '',
    );
  }

  factory UserStatsModel.fromUsers(List<AppUserModel> users) {
    var active = 0;
    var officers = 0;
    var drivers = 0;
    var accounts = 0;
    var management = 0;
    var managers = 0;
    var superUsers = 0;

    for (final user in users) {
      if (user.isActive) active++;

      switch (user.role.trim().toLowerCase()) {
        case 'officer':
        case 'officer in charge':
          officers++;
          break;
        case 'driver':
          drivers++;
          break;
        case 'accounts':
          accounts++;
          break;
        case 'management':
          management++;
          break;
        case 'manager':
          managers++;
          break;
        case 'super_user':
        case 'super user':
        case 'superuser':
        case 'admin':
          superUsers++;
          break;
      }
    }

    return UserStatsModel(
      total: users.length,
      active: active,
      inactive: users.length - active,
      officers: officers,
      drivers: drivers,
      accounts: accounts,
      management: management,
      managers: managers,
      superUsers: superUsers,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'active': active,
      'inactive': inactive,
      'officers': officers,
      'drivers': drivers,
      'accounts': accounts,
      'management': management,
      'managers': managers,
      'superUsers': superUsers,
      'updatedAt': updatedAt,
    };
  }
}
