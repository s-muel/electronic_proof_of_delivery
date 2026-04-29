import 'package:flutter/material.dart';
import 'login_screen.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingWaybills = [
      {
        'waybillNumber': '0000239',
        'bajNumber': 'BAJ-2026-001',
        'client': 'Sample Client',
        'status': 'Pending Delivery',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pendingWaybills.length,
        itemBuilder: (context, index) {
          final waybill = pendingWaybills[index];

          return Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping, color: Colors.blue),
              title: Text('Waybill No: ${waybill['waybillNumber']}'),
              subtitle: Text(
                'BAJ No: ${waybill['bajNumber']}\nClient: ${waybill['client']}',
              ),
              trailing: Chip(
                label: Text('${waybill['status']}'),
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}