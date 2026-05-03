import 'package:flutter/material.dart';
import '../services/delivery_sync_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_waybill_service.dart';
import '../services/waybill_service.dart';
import '../utils/platform_flags.dart';
import '../widgets/network_status_bar.dart';
import 'login_screen.dart';
import 'create_waybill_screen.dart';
import 'view_waybills_screen.dart';

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  int pendingCount = 0;
  int deliveredCount = 0;
  int invoicedCount = 0;
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    if (shouldSkipAutomaticFirebaseRefresh) {
      setState(() {
        pendingCount = WaybillService.getPendingWaybills().length;
        deliveredCount = WaybillService.getDeliveredWaybills().length;
        invoicedCount = WaybillService.getInvoicedWaybills().length;
      });
    } else {
      loadDashboardCounts();
    }
  }

  Future<void> loadDashboardCounts() async {
    if (shouldUseFirestoreData) {
      try {
        final allWaybills = await FirestoreWaybillService.getAllWaybills();
        await WaybillService.replaceCachedWaybills(allWaybills);
      } catch (_) {
        // Keep using the local cache when Firestore is unavailable.
      }
    }

    if (!mounted) return;

    setState(() {
      pendingCount = WaybillService.getPendingWaybills().length;
      deliveredCount = WaybillService.getDeliveredWaybills().length;
      invoicedCount = WaybillService.getInvoicedWaybills().length;
    });
  }

  Future<void> syncNow() async {
    if (isSyncing) return;

    if (!shouldUseFirestoreData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Online sync is disabled on Windows desktop. Please use Chrome or Android for Firebase sync.',
          ),
        ),
      );
      return;
    }

    setState(() => isSyncing = true);

    final syncedCount = await DeliverySyncService.syncPendingDeliveries();

    if (!mounted) return;

    setState(() => isSyncing = false);
    await loadDashboardCounts();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          syncedCount > 0
              ? '$syncedCount offline delivery sync completed'
              : 'No offline deliveries were synced',
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuthService.signOut();

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _openCreateWaybill(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateWaybillScreen()),
    );

    await loadDashboardCounts();
  }

  Future<void> _openViewWaybills(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ViewWaybillsScreen()),
    );

    await loadDashboardCounts();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer In Charge Dashboard'),
        actions: [
          IconButton(
            onPressed: () => loadDashboardCounts(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Dashboard',
          ),
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await loadDashboardCounts();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetworkStatusBar(
                onSyncNow: syncNow,
                isSyncing: isSyncing,
              ),

              const SizedBox(height: 20),

              const Text(
                'Waybill Summary',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isWideScreen ? 3 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isWideScreen ? 3.2 : 3.8,
                children: [
                  _SummaryCard(
                    title: 'Pending Delivery',
                    count: pendingCount,
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                  ),
                  _SummaryCard(
                    title: 'Delivered',
                    count: deliveredCount,
                    icon: Icons.local_shipping,
                    color: Colors.green,
                  ),
                  _SummaryCard(
                    title: 'Invoiced',
                    count: invoicedCount,
                    icon: Icons.receipt_long,
                    color: Colors.blue,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isWideScreen ? 3 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isWideScreen ? 2.2 : 3.2,
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
                  _DashboardCard(
                    icon: Icons.search,
                    title: 'Search',
                    subtitle: 'Find by BAJ Number or Waybill No.',
                    onTap: () => _openViewWaybills(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1,
                    ),
                  ),
                ],
              ),
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
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 30, color: Colors.blue),
              ),
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
                    const SizedBox(height: 4),
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
