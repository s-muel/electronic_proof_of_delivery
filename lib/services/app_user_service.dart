import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/app_user_model.dart';

class AppUserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'users';
  static const String _secondaryAppName = 'admin-user-create';
  static FirebaseApp? _secondaryApp;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(_collectionName);

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

  static Future<List<AppUserModel>> getActiveDrivers() async {
    final snapshot = await _users.where('role', isEqualTo: 'driver').get();

    return snapshot.docs
        .map((doc) => AppUserModel.fromMap(doc.data()))
        .where((user) => user.isActive)
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  static Future<AppUserModel> createUser({
    required String fullName,
    required String email,
    required String password,
    required String role,
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
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      try {
        await _users.doc(user.uid).set(appUser.toMap());
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
    await _users.doc(user.userId).set(user.toMap(), SetOptions(merge: true));
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
}
