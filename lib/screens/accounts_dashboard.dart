import 'package:flutter/material.dart';
import 'login_screen.dart';

class AccountsDashboard extends StatelessWidget {
  const AccountsDashboard({super.key});

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deliveredWaybills = [
      {
        'waybillNumber': '0000239',
        'bajNumber': 'BAJ-2026-001',
        'client': 'Sample Client',
        'status': 'Delivered',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: deliveredWaybills.length,
        itemBuilder: (context, index) {
          final waybill = deliveredWaybills[index];

          return Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.green),
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