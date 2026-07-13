import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/app_user_model.dart';
import '../models/user_stats_model.dart';

class AppUserPage {
  final List<AppUserModel> users;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const AppUserPage({
    required this.users,
    required this.lastDocument,
    required this.hasMore,
  });
}

class AppUserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'users';
  static const String _userStatsDocumentPath = 'appStats/usersSummary';
  static const String _driverIndexDocumentPath = 'appStats/drivers';
  static const String _secondaryAppName = 'admin-user-create';
  static FirebaseApp? _secondaryApp;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(_collectionName);

  static DocumentReference<Map<String, dynamic>> get _userStatsDoc =>
      _firestore.doc(_userStatsDocumentPath);

  static DocumentReference<Map<String, dynamic>> get _driverIndexDoc =>
      _firestore.doc(_driverIndexDocumentPath);

  static Future<FirebaseAuth> _getSecondaryAuth() async {
    for (final app in Firebase.apps) {
      if (app.name == _secondaryAppName) {
        _secondaryApp = app;
        return FirebaseAuth.instanceFor(app: app);
      }
    }

    _secondaryApp = await Firebase.initializeApp(
      name: _secondaryAppName,
      options: Firebase.app().options,
    );

    return FirebaseAuth.instanceFor(app: _secondaryApp!);
  }

  static Future<List<AppUserModel>> getAllUsers() async {
    final snapshot = await _users.get();

    return snapshot.docs.map((doc) => AppUserModel.fromMap(doc.data())).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<AppUserPage> getUsersPage({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    String? roleFilter,
  }) async {
    Query<Map<String, dynamic>> query = _users.orderBy(
      'createdAt',
      descending: true,
    );

    final normalizedRole = _roleValueForFilter(roleFilter);
    if (normalizedRole != null) {
      query = _users
          .where('role', isEqualTo: normalizedRole)
          .orderBy('createdAt', descending: true);
    }

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(limit + 1).get();
    final docs = snapshot.docs;
    final pageDocs = docs.take(limit).toList();
    final users = pageDocs
        .map((doc) => AppUserModel.fromMap(doc.data()))
        .toList();

    return AppUserPage(
      users: users,
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: docs.length > limit,
    );
  }

  static String? _roleValueForFilter(String? roleLabel) {
    switch (roleLabel?.trim().toLowerCase()) {
      case 'super user':
        return 'super_user';
      case 'officer':
        return 'officer';
      case 'driver':
        return 'driver';
      case 'accounts':
      case 'account':
        return 'accounts';
      case 'management':
        return 'management';
      case 'manager':
        return 'manager';
      default:
        return null;
    }
  }

  static Future<UserStatsModel?> getUserStats() async {
    final snapshot = await _userStatsDoc.get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return null;

    return UserStatsModel.fromMap(data);
  }

  static Future<UserStatsModel> rebuildUserStats() async {
    final users = await getAllUsers();
    final stats = UserStatsModel.fromUsers(users);

    await _userStatsDoc.set(stats.toMap());
    await _writeDriverIndexFromUsers(users);
    return stats;
  }

  static String? _statsFieldForRole(String role) {
    switch (role.trim().toLowerCase()) {
      case 'officer':
      case 'officer in charge':
        return 'officers';
      case 'driver':
        return 'drivers';
      case 'accounts':
      case 'account':
        return 'accounts';
      case 'management':
        return 'management';
      case 'manager':
        return 'managers';
      case 'super_user':
      case 'super user':
      case 'superuser':
      case 'admin':
        return 'superUsers';
      default:
        return null;
    }
  }

  static Map<String, dynamic> _userStatsDelta({
    AppUserModel? oldUser,
    required AppUserModel newUser,
  }) {
    final deltas = <String, int>{};

    void add(String field, int amount) {
      if (amount == 0) return;
      deltas[field] = (deltas[field] ?? 0) + amount;
      if (deltas[field] == 0) {
        deltas.remove(field);
      }
    }

    void applyUser(AppUserModel user, int direction) {
      add(user.isActive ? 'active' : 'inactive', direction);
      final roleField = _statsFieldForRole(user.role);
      if (roleField != null) {
        add(roleField, direction);
      }
    }

    if (oldUser == null) {
      add('total', 1);
    } else {
      applyUser(oldUser, -1);
    }

    applyUser(newUser, 1);

    return {
      for (final entry in deltas.entries)
        entry.key: FieldValue.increment(entry.value),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  static Future<List<AppUserModel>> getActiveDrivers() async {
    final snapshot = await _driverIndexDoc.get();
    final data = snapshot.data();
    final driversData = data?['drivers'];

    if (!snapshot.exists || driversData is! List) {
      throw StateError('Driver index has not been built.');
    }

    return driversData.whereType<Map>().map((driver) {
      return AppUserModel.fromMap(Map<String, dynamic>.from(driver));
    }).toList()..sort(_sortUsersByName);
  }

  static Future<List<AppUserModel>> _getActiveDriversFromUsers() async {
    final snapshot = await _users.where('role', isEqualTo: 'driver').get();

    return snapshot.docs
        .map((doc) => AppUserModel.fromMap(doc.data()))
        .where((user) => user.isActive)
        .toList()
      ..sort(_sortUsersByName);
  }

  static Future<List<AppUserModel>> rebuildDriverIndex() async {
    final drivers = await _getActiveDriversFromUsers();

    await _driverIndexDoc.set({
      'drivers': drivers.map(_driverIndexEntry).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    return drivers;
  }

  static Future<AppUserModel> createUser({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String department = '',
  }) async {
    final secondaryAuth = await _getSecondaryAuth();

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-create-failed',
          message: 'Could not create login account.',
        );
      }

      await user.updateDisplayName(fullName.trim());

      final now = DateTime.now().toIso8601String();
      final appUser = AppUserModel(
        userId: user.uid,
        fullName: fullName.trim(),
        email: email.trim(),
        role: role.trim(),
        department: department.trim(),
        tempPass: password,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      try {
        final batch = _firestore.batch();
        batch.set(_users.doc(user.uid), appUser.toMap());
        batch.set(
          _userStatsDoc,
          _userStatsDelta(newUser: appUser),
          SetOptions(merge: true),
        );
        if (_isActiveDriver(appUser)) {
          batch.set(_driverIndexDoc, {
            'drivers': FieldValue.arrayUnion([_driverIndexEntry(appUser)]),
            'updatedAt': now,
          }, SetOptions(merge: true));
        }
        await batch.commit();
      } catch (_) {
        await user.delete();
        rethrow;
      }

      return appUser;
    } finally {
      await secondaryAuth.signOut();
    }
  }

  static Future<void> updateUser(AppUserModel user) async {
    final userRef = _users.doc(user.userId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final oldUser = snapshot.exists && snapshot.data() != null
          ? AppUserModel.fromMap(snapshot.data()!)
          : null;
      final shouldUpdateDriverIndex = _driverIndexShouldChange(oldUser, user);
      final driverIndexSnapshot = shouldUpdateDriverIndex
          ? await transaction.get(_driverIndexDoc)
          : null;
      final driverIndexEntries = shouldUpdateDriverIndex
          ? _updatedDriverIndexEntries(
              driverIndexSnapshot?.data()?['drivers'],
              oldUser: oldUser,
              newUser: user,
            )
          : null;

      transaction.set(userRef, user.toMap(), SetOptions(merge: true));
      transaction.set(
        _userStatsDoc,
        _userStatsDelta(oldUser: oldUser, newUser: user),
        SetOptions(merge: true),
      );

      if (driverIndexEntries != null) {
        transaction.set(_driverIndexDoc, {
          'drivers': driverIndexEntries,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }
    });
  }

  static Future<void> setUserActive({
    required AppUserModel user,
    required bool isActive,
  }) async {
    await updateUser(
      user.copyWith(
        isActive: isActive,
        updatedAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> _writeDriverIndexFromUsers(
    List<AppUserModel> users,
  ) async {
    final drivers = users.where(_isActiveDriver).toList()
      ..sort(_sortUsersByName);

    await _driverIndexDoc.set({
      'drivers': drivers.map(_driverIndexEntry).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  static bool _driverIndexShouldChange(
    AppUserModel? oldUser,
    AppUserModel newUser,
  ) {
    if (_isActiveDriver(oldUser) != _isActiveDriver(newUser)) return true;
    if (!_isActiveDriver(newUser)) return false;

    return oldUser?.fullName.trim() != newUser.fullName.trim() ||
        oldUser?.email.trim() != newUser.email.trim() ||
        oldUser?.department.trim() != newUser.department.trim();
  }

  static List<Map<String, dynamic>> _updatedDriverIndexEntries(
    dynamic rawDrivers, {
    required AppUserModel? oldUser,
    required AppUserModel newUser,
  }) {
    final entries = rawDrivers is List
        ? rawDrivers
              .whereType<Map>()
              .map((driver) => Map<String, dynamic>.from(driver))
              .toList()
        : <Map<String, dynamic>>[];

    final oldUserId = oldUser?.userId.trim();
    final newUserId = newUser.userId.trim();
    entries.removeWhere((driver) {
      final driverUserId = (driver['userId'] ?? '').toString().trim();
      return driverUserId == oldUserId || driverUserId == newUserId;
    });

    if (_isActiveDriver(newUser)) {
      entries.add(_driverIndexEntry(newUser));
    }

    entries.sort((a, b) {
      final aName = (a['fullName'] ?? a['email'] ?? '').toString();
      final bName = (b['fullName'] ?? b['email'] ?? '').toString();
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });

    return entries;
  }

  static bool _isActiveDriver(AppUserModel? user) {
    if (user == null || !user.isActive) return false;
    return user.role.trim().toLowerCase() == 'driver';
  }

  static Map<String, dynamic> _driverIndexEntry(AppUserModel user) {
    return {
      'userId': user.userId.trim(),
      'fullName': user.fullName.trim(),
      'email': user.email.trim(),
      'department': user.department.trim(),
      'role': 'driver',
      'isActive': true,
      'createdAt': user.createdAt,
      'updatedAt': user.updatedAt,
    };
  }

  static int _sortUsersByName(AppUserModel a, AppUserModel b) {
    final aName = a.fullName.trim().isEmpty ? a.email : a.fullName;
    final bName = b.fullName.trim().isEmpty ? b.email : b.fullName;
    return aName.toLowerCase().compareTo(bName.toLowerCase());
  }
}
