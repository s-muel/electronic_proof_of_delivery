import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../models/waybill_stats_model.dart';
import '../services/delivery_sync_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_waybill_service.dart';
import '../services/settings_service.dart';
import '../services/waybill_service.dart';
import '../utils/platform_flags.dart';
import '../widgets/network_status_bar.dart';
import 'login_screen.dart';
//import 'waybill_details_screen.dart';

import 'driver_assigned_waybills_screen.dart';
import 'driver_delivery_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  List<WaybillModel> pendingWaybills = [];
  List<WaybillModel> pendingSyncWaybills = [];
  int assignedWaybillCount = 0;
  int pendingDeliveryCount = 0;
  String driverName = '';
  bool isSyncing = false;

  List<WaybillModel> get visibleWaybills {
    return [...pendingSyncWaybills, ...pendingWaybills];
  }

  @override
  void initState() {
    super.initState();
    loadDriverProfile();
    loadPendingWaybills();
    if (!shouldSkipAutomaticFirebaseRefresh) {
      refreshDashboard();
    }
  }

  Future<void> loadDriverProfile() async {
    final firebaseUser = FirebaseAuthService.currentFirebaseUser;
    final fallbackName = firebaseUser?.displayName?.trim().isNotEmpty == true
        ? firebaseUser!.displayName!.trim()
        : firebaseUser?.email ?? '';

    try {
      final profile = await FirebaseAuthService.getCurrentUserProfile();
      final profileName = profile?.fullName.trim() ?? '';

      if (!mounted) return;

      setState(() {
        driverName = profileName.isNotEmpty ? profileName : fallbackName;
      });
    } catch (error) {
      debugPrint('DRIVER PROFILE LOAD ERROR: $error');
      if (!mounted) return;

      setState(() => driverName = fallbackName);
    }
  }

  void loadPendingWaybills() {
    final driverId = FirebaseAuthService.currentFirebaseUser?.uid ?? '';

    setState(() {
      pendingWaybills = WaybillService.getPendingWaybillsAssignedToDriver(
        driverId,
      );
      pendingSyncWaybills =
          WaybillService.getPendingSyncWaybillsAssignedToDriver(driverId);
      pendingDeliveryCount = pendingWaybills.length;
      assignedWaybillCount = WaybillService.getWaybillsAssignedToDriver(
        driverId,
      ).length;
    });
  }

  bool _hasInvalidStats(WaybillStatsModel? stats) {
    if (stats == null) return true;

    return stats.total < 0 ||
        stats.pendingDelivery < 0 ||
        stats.delivered < 0 ||
        stats.invoiced < 0 ||
        stats.rejected < 0;
  }

  Future<void> loadPendingWaybillsFromFirestore() async {
    final driverId = FirebaseAuthService.currentFirebaseUser?.uid ?? '';

    if (!shouldUseFirestoreData) {
      loadPendingWaybills();
      return;
    }

    WaybillStatsModel? stats;
    Object? statsError;

    try {
      stats = await FirestoreWaybillService.getAssignedDriverWaybillStats(
        driverId,
      );
      if (_hasInvalidStats(stats)) {
        stats = await FirestoreWaybillService.rebuildAssignedDriverWaybillStats(
          driverId,
        );
      }
    } catch (error) {
      statsError = error;
      debugPrint('DRIVER STATS LOAD ERROR: $error');
    }

    try {
      final page =
          await FirestoreWaybillService.getWaybillsAssignedToDriverPage(
            driverId,
            limit: 25,
            statusFilter: WaybillService.pendingDeliveryStatus,
          );
      await WaybillService.mergeCachedWaybills(page.waybills);

      if (!mounted) return;

      setState(() {
        pendingWaybills = page.waybills;
        pendingSyncWaybills =
            WaybillService.getPendingSyncWaybillsAssignedToDriver(driverId);
        pendingDeliveryCount = stats?.pendingDelivery ?? page.waybills.length;
        assignedWaybillCount = stats?.total ?? page.waybills.length;
      });

      if (statsError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Driver stats unavailable: $statsError')),
        );
      }
    } catch (error) {
      debugPrint('DRIVER WAYBILL QUERY ERROR: $error');
      try {
        final assignedWaybills =
            await FirestoreWaybillService.getWaybillsAssignedToDriver(driverId);
        final pendingAssignedWaybills = assignedWaybills
            .where(
              (waybill) =>
                  waybill.status == WaybillService.pendingDeliveryStatus,
            )
            .take(25)
            .toList();
        await WaybillService.mergeCachedWaybills(assignedWaybills);

        if (!mounted) return;

        setState(() {
          pendingWaybills = pendingAssignedWaybills;
          pendingSyncWaybills =
              WaybillService.getPendingSyncWaybillsAssignedToDriver(driverId);
          pendingDeliveryCount =
              stats?.pendingDelivery ?? pendingAssignedWaybills.length;
          assignedWaybillCount = stats?.total ?? assignedWaybills.length;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Driver data loaded with fallback: $error')),
        );
      } catch (fallbackError) {
        debugPrint('DRIVER WAYBILL FALLBACK ERROR: $fallbackError');
        if (!mounted) return;
        loadPendingWaybills();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load driver data: $fallbackError')),
        );
      }
    }
  }

  Future<void> refreshDashboard() async {
    if (isSyncing) return;

    if (!shouldUseFirestoreData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Online sync is disabled on Windows desktop. Please use Chrome or Android for DataBase sync.',
          ),
        ),
      );
      loadPendingWaybills();
      return;
    }

    setState(() => isSyncing = true);

    final syncedCount = await DeliverySyncService.syncPendingDeliveries();
    await loadPendingWaybillsFromFirestore();

    if (!mounted) return;

    setState(() => isSyncing = false);

    if (syncedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$syncedCount offline delivery sync completed')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuthService.signOut();

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void openWaybillDetails(int index, WaybillModel waybill) async {
    if (index == -1) {
      index = await WaybillService.ensureCachedIndex(waybill);
    }

    if (!mounted) return;

    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find this waybill record')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverDeliveryScreen(waybill: waybill, index: index),
      ),
    );

    await refreshDashboard();
  }

  Future<void> openAssignedWaybills() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriverAssignedWaybillsScreen()),
    );

    await refreshDashboard();
  }

  Future<void> showSenderEmail() async {
    final settings = await SettingsService().loadSmtpSettings();

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mail Sender'),
          content: Text(
            settings.senderEmail.trim().isEmpty
                ? 'No sender email configured.'
                : settings.senderEmail,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Pending Delivery':
        return Colors.orange;
      case 'Pending Sync':
        return Colors.deepOrange;
      case 'Delivered':
        return Colors.green;
      case 'Invoiced':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;
    final isCompactAppBar = screenWidth < 560;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isCompactAppBar ? 142 : 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Driver Dashboard',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: isCompactAppBar ? 16 : null),
              ),
              if (driverName.trim().isNotEmpty)
                Text(
                  driverName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompactAppBar ? 10 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          NetworkStatusChip(onSyncNow: refreshDashboard, isSyncing: isSyncing),
          SizedBox(width: isCompactAppBar ? 2 : 8),
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCards(isWideScreen: isWideScreen),
              const SizedBox(height: 12),
              if (pendingSyncWaybills.isNotEmpty) _buildPendingSyncBanner(),
              Expanded(
                child: visibleWaybills.isEmpty
                    ? _buildEmptyTableMessage()
                    : isWideScreen
                    ? _buildTableView()
                    : _buildListView(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: showSenderEmail,
        tooltip: 'Mail sender',
        child: const Icon(Icons.settings),
      ),
    );
  }

  Widget _buildSummaryCards({required bool isWideScreen}) {
    final cards = [
      _DriverSummaryCard(
        title: 'Pending Delivery',
        count: pendingDeliveryCount,
        icon: Icons.pending_actions,
        color: Colors.orange,
      ),
      _DriverSummaryCard(
        title: 'Pending Sync',
        count: pendingSyncWaybills.length,
        icon: Icons.cloud_sync,
        color: Colors.deepOrange,
      ),
      _DriverSummaryCard(
        title: 'All Assigned',
        count: assignedWaybillCount,
        icon: Icons.assignment,
        color: Colors.blue,
        onTap: openAssignedWaybills,
      ),
    ];

    return Row(
      children: [
        Expanded(child: cards[0]),
        SizedBox(width: isWideScreen ? 12 : 6),
        Expanded(child: cards[1]),
        SizedBox(width: isWideScreen ? 12 : 6),
        Expanded(child: cards[2]),
      ],
    );
  }

  Widget _buildEmptyTableMessage() {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.inbox_outlined, size: 52, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No pending delivery waybills available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6),
              Text(
                'New assigned deliveries will appear here.',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingSyncBanner() {
    return Card(
      color: Colors.deepOrange.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.cloud_sync, color: Colors.deepOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${pendingSyncWaybills.length} delivered waybill(s) saved offline and waiting to sync.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: isSyncing ? null : refreshDashboard,
              icon: const Icon(Icons.sync),
              label: const Text('Retry Sync'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 2, bottom: 12),
      itemCount: visibleWaybills.length,
      itemBuilder: (context, index) {
        final waybill = visibleWaybills[index];
        final originalIndex = WaybillService.getIndexByWaybillNumber(
          waybill.waybillNumber,
        );
        final statusColor = getStatusColor(waybill.status);
        final isPendingDelivery =
            waybill.status == WaybillService.pendingDeliveryStatus;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFDDE6F2)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => openWaybillDetails(originalIndex, waybill),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Text(
                                  waybill.waybillNumber,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF172033),
                                  ),
                                ),
                                _buildCardStatusChip(
                                  waybill.status,
                                  statusColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 12,
                              runSpacing: 5,
                              children: [
                                _buildCardInfoText('BAJ No', waybill.bajNumber),
                                _buildCardInfoText(
                                  'Client',
                                  waybill.shippingVendor,
                                ),
                                _buildCardIconText(
                                  Icons.calendar_today,
                                  waybill.date,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () =>
                          openWaybillDetails(originalIndex, waybill),
                      icon: Icon(
                        isPendingDelivery ? Icons.task_alt : Icons.open_in_new,
                        size: 16,
                      ),
                      label: Text(isPendingDelivery ? 'Pending' : 'Open'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardStatusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildCardInfoText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Color(0xFF34465C), fontSize: 13),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value.isEmpty ? '-' : value,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardIconText(IconData icon, String text, {Color? color}) {
    final effectiveColor = color ?? const Color(0xFF34465C);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: effectiveColor),
        const SizedBox(width: 4),
        Text(
          text.isEmpty ? '-' : text,
          style: TextStyle(
            color: effectiveColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          Colors.blue.withValues(alpha: 0.08),
        ),
        columns: const [
          DataColumn(label: Text('Waybill No.')),
          DataColumn(label: Text('BAJ No.')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Shipping/Vendor')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Action')),
        ],
        rows: visibleWaybills.map((waybill) {
          final originalIndex = WaybillService.getIndexByWaybillNumber(
            waybill.waybillNumber,
          );

          return DataRow(
            cells: [
              DataCell(Text(waybill.waybillNumber)),
              DataCell(Text(waybill.bajNumber)),
              DataCell(Text(waybill.date)),
              DataCell(Text(waybill.shippingVendor)),
              DataCell(
                Chip(
                  label: Text(waybill.status),
                  backgroundColor: getStatusColor(
                    waybill.status,
                  ).withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: getStatusColor(waybill.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataCell(
                TextButton(
                  onPressed: () => openWaybillDetails(originalIndex, waybill),
                  child: const Text('Open'),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DriverSummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _DriverSummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 150;
        final iconSize = isCompact ? 28.0 : 42.0;
        final displayTitle = isCompact ? title.replaceFirst(' ', '\n') : title;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 6 : 14,
            vertical: isCompact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: isCompact ? 18 : 24),
              ),
              SizedBox(width: isCompact ? 5 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      count.toString(),
                      style: TextStyle(
                        color: color,
                        fontSize: isCompact ? 18 : 24,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displayTitle,
                      maxLines: isCompact ? 2 : 1,
                      overflow: TextOverflow.visible,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: isCompact ? 10 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: isCompact ? 1.05 : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: isCompact ? 11 : 16,
                ),
            ],
          ),
        );
      },
    );

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: onTap == null
          ? cardContent
          : InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: cardContent,
            ),
    );
  }
}
