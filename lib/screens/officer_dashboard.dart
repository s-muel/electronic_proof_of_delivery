import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../models/waybill_stats_model.dart';
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
  int rejectedCount = 0;

  bool _isRejectedWaybill(WaybillModel waybill) =>
      waybill.invoiceStatus == WaybillService.invoiceRejectedStatus;

  void _applyDashboardCounts(List<WaybillModel> officerWaybills) {
    pendingCount = officerWaybills
        .where(
          (waybill) =>
              waybill.status == WaybillService.pendingDeliveryStatus &&
              !_isRejectedWaybill(waybill),
        )
        .length;
    rejectedCount = officerWaybills.where(_isRejectedWaybill).length;
    deliveredCount = officerWaybills
        .where(
          (waybill) =>
              waybill.status == WaybillService.deliveredStatus &&
              !_isRejectedWaybill(waybill),
        )
        .length;
    invoicedCount = officerWaybills
        .where(
          (waybill) =>
              waybill.status == WaybillService.invoicedStatus &&
              !_isRejectedWaybill(waybill),
        )
        .length;
  }

  void _applyStatsCounts(WaybillStatsModel stats) {
    pendingCount = stats.pendingDelivery;
    deliveredCount = stats.delivered;
    invoicedCount = stats.invoiced;
    rejectedCount = stats.rejected;
  }

  bool _hasInvalidStats(WaybillStatsModel? stats) {
    if (stats == null) return true;

    return stats.total < 0 ||
        stats.pendingDelivery < 0 ||
        stats.delivered < 0 ||
        stats.invoiced < 0 ||
        stats.rejected < 0;
  }

  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    if (shouldSkipAutomaticFirebaseRefresh) {
      setState(() {
        final userId = FirebaseAuthService.currentFirebaseUser?.uid ?? '';
        _applyDashboardCounts(WaybillService.getWaybillsCreatedBy(userId));
      });
    } else {
      loadDashboardCounts();
    }
  }

  Future<void> loadDashboardCounts() async {
    final userId = FirebaseAuthService.currentFirebaseUser?.uid ?? '';
    final firebaseUser = FirebaseAuthService.currentFirebaseUser;
    final cachedOfficerWaybills = WaybillService.getWaybillsCreatedBy(userId);
    WaybillStatsModel? officerStats;
    var loadedOfficerName =
        firebaseUser?.displayName ?? firebaseUser?.email ?? '';

    try {
      final profile = await FirebaseAuthService.getCurrentUserProfile();
      loadedOfficerName = profile?.fullName ?? loadedOfficerName;
    } catch (_) {
      // Use Firebase Auth display data if the profile cannot be refreshed.
    }

    if (shouldUseFirestoreData) {
      try {
        officerStats = await FirestoreWaybillService.getUserWaybillStats(
          userId,
        );
        if (_hasInvalidStats(officerStats)) {
          officerStats = await FirestoreWaybillService.rebuildUserWaybillStats(
            userId,
          );
        }
      } catch (_) {
        // Keep using the local cache when Firestore stats are unavailable.
      }
    }

    if (!mounted) return;

    setState(() {
      officerName = loadedOfficerName;
      if (officerStats != null) {
        _applyStatsCounts(officerStats);
      } else {
        _applyDashboardCounts(cachedOfficerWaybills);
      }
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

    if (!mounted) return;

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

  Future<void> _openRejectedWaybills(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ViewWaybillsScreen(
          title: 'Rejected Waybills',
          showRejectedOnly: true,
        ),
      ),
    );

    await loadDashboardCounts();
  }

  Future<void> _openWaybillsByStatus({
    required BuildContext context,
    required String title,
    required String status,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewWaybillsScreen(title: title, statusFilter: status),
      ),
    );

    await loadDashboardCounts();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;
    final isTablet = screenWidth >= 600 && !isWideScreen;
    final summaryColumns = isWideScreen ? 4 : (isTablet ? 2 : 1);
    final actionColumns = isWideScreen ? 3 : (isTablet ? 2 : 1);

    final dashboardContent = RefreshIndicator(
      onRefresh: loadDashboardCounts,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isWideScreen ? 22 : 14,
          16,
          isWideScreen ? 22 : 14,
          18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OfficerHero(
              officerName: officerName,
              pendingCount: pendingCount,
              deliveredCount: deliveredCount,
              rejectedCount: rejectedCount,
              onRefresh: loadDashboardCounts,
              onLogout: () => _logout(context),
            ),
            const SizedBox(height: 16),
            NetworkStatusBar(onSyncNow: syncNow, isSyncing: isSyncing),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Waybill Summary',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172033),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openViewWaybills(context),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: summaryColumns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWideScreen ? 2.55 : (isTablet ? 2.7 : 4.0),
              children: [
                _SummaryCard(
                  title: 'Pending Delivery',
                  count: pendingCount,
                  icon: Icons.pending_actions,
                  color: Colors.orange,
                  onTap: () => _openWaybillsByStatus(
                    context: context,
                    title: 'Pending Delivery',
                    status: WaybillService.pendingDeliveryStatus,
                  ),
                ),
                _SummaryCard(
                  title: 'Delivered Waybills',
                  count: deliveredCount,
                  icon: Icons.local_shipping,
                  color: Colors.blue,
                  onTap: () => _openWaybillsByStatus(
                    context: context,
                    title: 'Delivered Waybills',
                    status: WaybillService.deliveredStatus,
                  ),
                ),
                _SummaryCard(
                  title: 'Invoiced Waybills',
                  count: invoicedCount,
                  icon: Icons.receipt_long,
                  color: Colors.green,
                  onTap: () => _openWaybillsByStatus(
                    context: context,
                    title: 'Invoiced Waybills',
                    status: WaybillService.invoicedStatus,
                  ),
                ),
                _SummaryCard(
                  title: 'Rejected',
                  count: rejectedCount,
                  icon: Icons.report_problem,
                  color: Colors.red,
                  onTap: () => _openRejectedWaybills(context),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172033),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: actionColumns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWideScreen ? 3.2 : (isTablet ? 2.7 : 3.1),
              children: [
                _DashboardCard(
                  icon: Icons.note_add,
                  title: 'Create Waybill',
                  subtitle: 'Enter new waybill details',
                  color: Colors.blue,
                  onTap: () => _openCreateWaybill(context),
                ),
                _DashboardCard(
                  icon: Icons.list_alt,
                  title: 'View Waybills',
                  subtitle: 'View all created waybills',
                  color: Colors.indigo,
                  onTap: () => _openViewWaybills(context),
                ),
                _DashboardCard(
                  icon: Icons.report_problem,
                  title: 'Rejected Waybills',
                  subtitle: 'Review rejected waybills and notes',
                  color: Colors.red,
                  onTap: () => _openRejectedWaybills(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Row(
        children: [
          if (isWideScreen) _buildSidebar(context),
          Expanded(child: SafeArea(child: dashboardContent)),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 214,
      decoration: const BoxDecoration(
        color: Color(0xFFEAF3FF),
        border: Border(right: BorderSide(color: Color(0xFFD6E4F5))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F5FB8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BAJ E-POD',
                          style: TextStyle(
                            color: Color(0xFF0A467F),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Officer Desk',
                          style: TextStyle(
                            color: Color(0xFF5B718C),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SidebarItem(
                icon: Icons.dashboard_customize,
                label: 'Dashboard',
                isActive: true,
                onTap: () {},
              ),
              _SidebarItem(
                icon: Icons.note_add,
                label: 'Create Waybill',
                onTap: () => _openCreateWaybill(context),
              ),
              _SidebarItem(
                icon: Icons.list_alt,
                label: 'View Waybills',
                onTap: () => _openViewWaybills(context),
              ),
              _SidebarItem(
                icon: Icons.report_problem,
                label: 'Rejected',
                onTap: () => _openRejectedWaybills(context),
              ),
              _SidebarItem(
                icon: Icons.refresh,
                label: 'Refresh',
                onTap: loadDashboardCounts,
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD6E4F5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Logged in as',
                      style: TextStyle(color: Color(0xFF6B7D90), fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      officerName.trim().isEmpty ? 'Officer User' : officerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout, size: 17),
                      label: const Text('Logout'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0F5FB8),
                        padding: EdgeInsets.zero,
                      ),
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

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: isActive
                  ? Border.all(color: const Color(0xFFD6E4F5))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive
                      ? const Color(0xFF0F5FB8)
                      : const Color(0xFF34465C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF0F5FB8)
                          : const Color(0xFF34465C),
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                    ),
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

class _OfficerHero extends StatelessWidget {
  final String officerName;
  final int pendingCount;
  final int deliveredCount;
  final int rejectedCount;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const _OfficerHero({
    required this.officerName,
    required this.pendingCount,
    required this.deliveredCount,
    required this.rejectedCount,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE1E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD6E4F5)),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Color(0xFF0F5FB8),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Officer Control Center',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (officerName.trim().isNotEmpty) ...[
                      Text(
                        'Welcome, $officerName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF172033),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    const Text(
                      'Create, track, and manage BAJ waybills.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xFF5B718C)),
                    ),
                  ],
                ),
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
              _HeroPill(
                label: 'Rejected',
                value: rejectedCount.toString(),
                icon: Icons.report_problem,
                color: Colors.red,
              ),
              IconButton.filledTonal(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Dashboard',
              ),
              IconButton.filledTonal(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HeroPill({
    required this.label,
    required this.value,
    required this.icon,
    this.color = const Color(0xFF0F5FB8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
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
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
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
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: color, size: 26),
                ],
              ],
            ),
          ),
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
  final Color color;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = Colors.blue,
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
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 30, color: color),
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
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.arrow_forward, size: 18, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
