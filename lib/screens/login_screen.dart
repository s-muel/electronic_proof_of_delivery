import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user_model.dart';
import '../services/firebase_auth_service.dart';
import 'accounts_dashboard.dart';
import 'driver_dashboard.dart';
import 'officer_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => isLoading = true);

    try {
      final appUser = await FirebaseAuthService.signIn(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      if (appUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No user profile found for this account.'),
          ),
        );
        return;
      }

      if (!appUser.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This user account is inactive.')),
        );
        return;
      }

      _openDashboard(appUser);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyLoginError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _openDashboard(AppUserModel appUser) {
    final role = appUser.role.trim().toLowerCase();
    Widget dashboard;

    if (role == 'officer' || role == 'officer in charge') {
      dashboard = const OfficerDashboard();
    } else if (role == 'driver') {
      dashboard = const DriverDashboard();
    } else if (role == 'accounts') {
      dashboard = const AccountsDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unsupported user role: ${appUser.role}')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => dashboard),
    );
  }

  String _friendlyLoginError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'network-request-failed':
          return 'No internet connection. Please connect and try again.';
        case 'too-many-requests':
          return 'Too many login attempts. Please wait and try again.';
        case 'user-disabled':
          return 'This login account has been disabled.';
        default:
          return 'Auth error (${error.code}): ${error.message ?? 'Please try again.'}';
      }
    }

    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Permission denied. Check Firestore rules for users collection.';
      }

      return 'Firebase error (${error.code}): ${error.message ?? 'Please try again.'}';
    }

    final message = error.toString().toLowerCase();

    if (message.contains('user-not-found') ||
        message.contains('wrong-password') ||
        message.contains('invalid-credential')) {
      return 'Invalid email or password.';
    }

    if (message.contains('network-request-failed')) {
      return 'No internet connection. Please connect and try again.';
    }

    if (message.contains('too-many-requests')) {
      return 'Too many login attempts. Please wait and try again.';
    }

    return 'Login failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: isWideScreen ? 450 : double.infinity,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_shipping_rounded,
                    size: 64,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'BAJ E-POD System',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Electronic Proof of Delivery',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';

                      if (email.isEmpty) {
                        return 'Email address is required';
                      }

                      if (!email.contains('@')) {
                        return 'Enter a valid email address';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => obscurePassword = !obscurePassword);
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : login,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(isLoading ? 'Signing in...' : 'Sign In'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
