import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../services/waybill_service.dart';
import 'login_screen.dart';
import 'waybill_details_screen.dart';

class AccountsDashboard extends StatefulWidget {
  const AccountsDashboard({super.key});

  @override
  State<AccountsDashboard> createState() => _AccountsDashboardState();
}

class _AccountsDashboardState extends State<AccountsDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<WaybillModel> deliveredWaybills = [];
  List<WaybillModel> invoicedWaybills = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    loadWaybills();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void loadWaybills() {
    setState(() {
      deliveredWaybills = WaybillService.getDeliveredWaybills();
      invoicedWaybills = WaybillService.getInvoicedWaybills();
    });
  }

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
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

  void openWaybillDetails(int index, WaybillModel waybill) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaybillDetailsScreen(waybill: waybill, index: index),
      ),
    );

    loadWaybills();
  }

  Future<void> markAsInvoiced(int index, WaybillModel waybill) async {
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find this waybill record')),
      );
      return;
    }

    final updatedWaybill = waybill.copyWith(
      status: 'Invoiced',
      invoicedAt: DateTime.now().toIso8601String(),
    );

    await WaybillService.updateWaybill(index, updatedWaybill);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Waybill marked as invoiced')));

    loadWaybills();

    _tabController.animateTo(1);
  }

  void confirmMarkAsInvoiced(int index, WaybillModel waybill) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Mark as Invoiced'),
          content: Text(
            'Are you sure you want to mark Waybill No. ${waybill.waybillNumber} as invoiced?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                markAsInvoiced(index, waybill);
              },
              icon: const Icon(Icons.check),
              label: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(String value) {
    if (value.isEmpty) return '-';

    try {
      final dateTime = DateTime.parse(value);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts Dashboard'),
        actions: [
          IconButton(
            onPressed: loadWaybills,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Ready for Invoice (${deliveredWaybills.length})'),
            Tab(text: 'Invoiced (${invoicedWaybills.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWaybillList(
            waybills: deliveredWaybills,
            emptyMessage: 'No waybills ready for invoicing',
            showMarkInvoicedButton: true,
          ),
          _buildWaybillList(
            waybills: invoicedWaybills,
            emptyMessage: 'No invoiced waybills yet',
            showMarkInvoicedButton: false,
          ),
        ],
      ),
    );
  }

  Widget _buildWaybillList({
    required List<WaybillModel> waybills,
    required String emptyMessage,
    required bool showMarkInvoicedButton,
  }) {
    final isWideScreen = MediaQuery.of(context).size.width > 850;

    if (waybills.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: const TextStyle(fontSize: 18)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: isWideScreen
          ? _buildTableView(
              waybills: waybills,
              showMarkInvoicedButton: showMarkInvoicedButton,
            )
          : _buildListView(
              waybills: waybills,
              showMarkInvoicedButton: showMarkInvoicedButton,
            ),
    );
  }

  Widget _buildListView({
    required List<WaybillModel> waybills,
    required bool showMarkInvoicedButton,
  }) {
    return ListView.builder(
      itemCount: waybills.length,
      itemBuilder: (context, index) {
        final waybill = waybills[index];

        final originalIndex = WaybillService.getIndexByWaybillNumber(
          waybill.waybillNumber,
        );

        return Card(
          child: ListTile(
            leading: Icon(
              waybill.status == 'Delivered'
                  ? Icons.receipt_long
                  : Icons.done_all,
              color: waybill.status == 'Delivered' ? Colors.green : Colors.blue,
            ),
            title: Text('Waybill No: ${waybill.waybillNumber}'),
            subtitle: Text(
              'BAJ No: ${waybill.bajNumber}\n'
              'Client: ${waybill.shippingVendor}\n'
              'Delivered: ${_formatDateTime(waybill.deliveredAt)}',
            ),
            trailing: Wrap(
              spacing: 8,
              children: [
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
                if (showMarkInvoicedButton)
                  IconButton(
                    icon: const Icon(Icons.done_all, color: Colors.blue),
                    tooltip: 'Mark Invoiced',
                    onPressed: () =>
                        confirmMarkAsInvoiced(originalIndex, waybill),
                  ),
              ],
            ),
            isThreeLine: true,
            onTap: () => openWaybillDetails(originalIndex, waybill),
          ),
        );
      },
    );
  }

  Widget _buildTableView({
    required List<WaybillModel> waybills,
    required bool showMarkInvoicedButton,
  }) {
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
          DataColumn(label: Text('Delivered At')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: waybills.map((waybill) {
          final originalIndex = WaybillService.getIndexByWaybillNumber(
            waybill.waybillNumber,
          );
          return DataRow(
            cells: [
              DataCell(Text(waybill.waybillNumber)),
              DataCell(Text(waybill.bajNumber)),
              DataCell(Text(waybill.date)),
              DataCell(Text(waybill.shippingVendor)),
              DataCell(Text(_formatDateTime(waybill.deliveredAt))),
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
                Row(
                  children: [
                    TextButton(
                      onPressed: () =>
                          openWaybillDetails(originalIndex, waybill),
                      child: const Text('View'),
                    ),
                    if (showMarkInvoicedButton)
                      TextButton.icon(
                        onPressed: () =>
                            confirmMarkAsInvoiced(originalIndex, waybill),
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text('Mark Invoiced'),
                      ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
