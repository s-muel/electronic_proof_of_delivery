import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'create_waybill_screen.dart';
import 'view_waybills_screen.dart';

class OfficerDashboard extends StatelessWidget {
  const OfficerDashboard({super.key});

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _openViewWaybills(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ViewWaybillsScreen()),
    );
  }

  void _openCreateWaybill(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateWaybillScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer In Charge Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            _DashboardCard(
              icon: Icons.note_add,
              title: 'Create Waybill',
              subtitle: 'Enter new waybill details',
              onTap: () => _openCreateWaybill(context),
            ),
            _DashboardCard(
              icon: Icons.list_alt,
              title: 'View Waybills',
              subtitle: 'View all created waybills',
              onTap: () => _openViewWaybills(context),
            ),
            const _DashboardCard(
              icon: Icons.search,
              title: 'Search',
              subtitle: 'Find by BAJ Number or Waybill No.',
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 38, color: Colors.blue),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
