import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../services/waybill_service.dart';
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

  @override
  void initState() {
    super.initState();
    loadPendingWaybills();
  }

  void loadPendingWaybills() {
    setState(() {
      pendingWaybills = WaybillService.getPendingWaybills();
    });
  }

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void openWaybillDetails(int index, WaybillModel waybill) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverDeliveryScreen(waybill: waybill, index: index),
      ),
    );

    loadPendingWaybills();
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Pending Delivery':
        return Colors.orange;
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
            onPressed: loadPendingWaybills,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pendingWaybills.isEmpty
          ? const Center(
              child: Text(
                'No pending delivery waybills available',
                style: TextStyle(fontSize: 18),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: isWideScreen ? _buildTableView() : _buildListView(),
            ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: pendingWaybills.length,
      itemBuilder: (context, index) {
        final waybill = pendingWaybills[index];
        final originalIndex = WaybillService.getAllWaybills().indexOf(waybill);

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
          final originalIndex = WaybillService.getAllWaybills().indexOf(
            waybill,
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
