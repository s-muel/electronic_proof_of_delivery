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
            'Online sync is disabled on Windows desktop. Please use Chrome or Android for Firebase sync.',
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
        SnackBar(
          content: Text('$syncedCount offline delivery sync completed'),
        ),
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
        const SnackBar(
          content: Text('Could not find this waybill record'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverDeliveryScreen(
          waybill: waybill,
          index: index,
        ),
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
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            onPressed: isSyncing ? null : refreshDashboard,
            icon: isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pendingWaybills.isEmpty && pendingSyncWaybills.isEmpty
          ? const Center(
              child: Text(
                'No pending delivery waybills available',
                style: TextStyle(fontSize: 18),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NetworkStatusBar(
                    onSyncNow: refreshDashboard,
                    isSyncing: isSyncing,
                  ),
                  const SizedBox(height: 12),
                  if (pendingSyncWaybills.isNotEmpty) _buildPendingSyncBanner(),
                  Expanded(
                    child: isWideScreen ? _buildTableView() : _buildListView(),
                  ),
                ],
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
      itemCount: pendingWaybills.length,
      itemBuilder: (context, index) {
        final waybill = pendingWaybills[index];
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
        rows: pendingWaybills.map((waybill) {
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
