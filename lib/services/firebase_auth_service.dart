import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user_model.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentFirebaseUser => _auth.currentUser;

  static Future<AppUserModel?> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      return null;
    }

    return getUserProfile(user.uid);
  }

  static Future<AppUserModel?> getCurrentUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    return getUserProfile(user.uid);
  }

  static Future<AppUserModel?> getUserProfile(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return AppUserModel.fromMap(snapshot.data()!);
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
