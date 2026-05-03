import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../services/delivery_sync_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_waybill_service.dart';
import '../services/waybill_service.dart';
import '../utils/platform_flags.dart';
import '../widgets/network_status_bar.dart';
import 'login_screen.dart';
//import 'waybill_details_screen.dart';

import 'driver_delivery_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  List<WaybillModel> pendingWaybills = [];
  List<WaybillModel> pendingSyncWaybills = [];
  bool isSyncing = false;

  List<WaybillModel> get visibleWaybills {
    return [...pendingSyncWaybills, ...pendingWaybills];
  }

  @override
  void initState() {
    super.initState();
    loadPendingWaybills();
    if (!shouldSkipAutomaticFirebaseRefresh) {
      loadPendingWaybillsFromFirestore();
      refreshDashboard();
    }
  }

  void loadPendingWaybills() {
    setState(() {
      pendingWaybills = WaybillService.getPendingWaybills();
      pendingSyncWaybills = WaybillService.getPendingSyncWaybills();
    });
  }

  Future<void> loadPendingWaybillsFromFirestore() async {
    if (shouldUseFirestoreData) {
      try {
        final allWaybills = await FirestoreWaybillService.getAllWaybills();
        await WaybillService.replaceCachedWaybills(allWaybills);
      } catch (_) {
        // Keep using the local cache when Firestore is unavailable.
      }
    }

    if (!mounted) return;

    loadPendingWaybills();
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

    setState(() {
      pendingWaybills = WaybillService.getPendingWaybills();
      pendingSyncWaybills = WaybillService.getPendingSyncWaybills();
      isSyncing = false;
    });

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
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text('Driver Dashboard')],
        ),
        actions: [
          NetworkStatusChip(onSyncNow: refreshDashboard, isSyncing: isSyncing),
          SizedBox(width: 8),
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
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
    );
  }

  Widget _buildSummaryCards({required bool isWideScreen}) {
    final cards = [
      _DriverSummaryCard(
        title: 'Pending Delivery',
        count: pendingWaybills.length,
        icon: Icons.pending_actions,
        color: Colors.orange,
      ),
      _DriverSummaryCard(
        title: 'Pending Sync',
        count: pendingSyncWaybills.length,
        icon: Icons.cloud_sync,
        color: Colors.deepOrange,
      ),
    ];

    if (isWideScreen) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 12),
          Expanded(child: cards[1]),
        ],
      );
    }

    return Column(children: [cards[0], const SizedBox(height: 10), cards[1]]);
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
      itemCount: visibleWaybills.length,
      itemBuilder: (context, index) {
        final waybill = visibleWaybills[index];
        final originalIndex = WaybillService.getIndexByWaybillNumber(
          waybill.waybillNumber,
        );

        return Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping, color: Colors.blue),
            title: Text('Waybill No: ${waybill.waybillNumber}'),
            subtitle: Text(
              'BAJ No: ${waybill.bajNumber}\nClient: ${waybill.shippingVendor}',
            ),
            trailing: Chip(
              label: Text(waybill.status),
              backgroundColor: getStatusColor(
                waybill.status,
              ).withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: getStatusColor(waybill.status),
                fontWeight: FontWeight.bold,
              ),
            ),
            isThreeLine: true,
            onTap: () => openWaybillDetails(originalIndex, waybill),
          ),
        );
      },
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

  const _DriverSummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
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
