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
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Officer Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF4F7FB),
        foregroundColor: const Color(0xFF172033),
        elevation: 0,
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F5FB8), Color(0xFF1D8BE8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 16,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Officer Control Center',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Create, track, and manage BAJ waybills.',
                              style: TextStyle(color: Color(0xFFEAF3FF)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _HeroPill(
                          label: 'Pending',
                          value: pendingCount.toString(),
                          icon: Icons.pending_actions,
                        ),
                        _HeroPill(
                          label: 'Delivered',
                          value: deliveredCount.toString(),
                          icon: Icons.local_shipping,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              NetworkStatusBar(onSyncNow: syncNow, isSyncing: isSyncing),

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
                childAspectRatio: isWideScreen ? 3.7 : 3.8,
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
                childAspectRatio: isWideScreen ? 2.7 : 3.2,
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

class _HeroPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFFEAF3FF))),
        ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF172033),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE8F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF4F9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(16),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172033),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
