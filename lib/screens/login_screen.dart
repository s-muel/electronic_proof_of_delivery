import 'package:flutter/material.dart';
import 'officer_dashboard.dart';
import 'driver_dashboard.dart';
import 'accounts_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String selectedRole = 'Officer In Charge';

  void login() {
    if (selectedRole == 'Officer In Charge') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OfficerDashboard()),
      );
    } else if (selectedRole == 'Driver') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DriverDashboard()),
      );
    } else if (selectedRole == 'Accounts') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AccountsDashboard()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      body: Center(
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

              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Select User Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Officer In Charge',
                    child: Text('Officer In Charge'),
                  ),
                  DropdownMenuItem(
                    value: 'Driver',
                    child: Text('Driver'),
                  ),
                  DropdownMenuItem(
                    value: 'Accounts',
                    child: Text('Accounts'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedRole = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: login,
                  icon: const Icon(Icons.login),
                  label: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}