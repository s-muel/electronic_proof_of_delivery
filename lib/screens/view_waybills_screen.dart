import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../services/firestore_waybill_service.dart';
import '../services/waybill_service.dart';

import 'edit_waybill_screen.dart';
import 'waybill_details_screen.dart';

class ViewWaybillsScreen extends StatefulWidget {
  const ViewWaybillsScreen({super.key});

  @override
  State<ViewWaybillsScreen> createState() => _ViewWaybillsScreenState();
}

class _ViewWaybillsScreenState extends State<ViewWaybillsScreen> {
  List<WaybillModel> waybills = [];
  List<WaybillModel> allWaybills = [];
  List<WaybillModel> filteredWaybills = [];

  final searchController = TextEditingController();

  void editWaybill(int index, WaybillModel waybill) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditWaybillScreen(waybill: waybill, index: index),
      ),
    );

    if (result == true) {
      setState(() {
        allWaybills = WaybillService.getAllWaybills();
      });

      filterWaybills(searchController.text);
    }
  }

  void openWaybillDetails(int index, WaybillModel waybill) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaybillDetailsScreen(waybill: waybill, index: index),
      ),
    );

    setState(() {
      waybills = WaybillService.getAllWaybills();
    });
  }

  Future<void> loadWaybills() async {
    try {
      allWaybills = await FirestoreWaybillService.getAllWaybills();
      await WaybillService.replaceCachedWaybills(allWaybills);
    } catch (_) {
      allWaybills = WaybillService.getAllWaybills();
    }

    if (!mounted) return;

    setState(() {
      filteredWaybills = allWaybills;
    });
  }

  void filterWaybills(String query) {
    final searchText = query.toLowerCase().trim();

    setState(() {
      if (searchText.isEmpty) {
        filteredWaybills = allWaybills;
      } else {
        filteredWaybills = allWaybills.where((waybill) {
          return waybill.waybillNumber.toLowerCase().contains(searchText) ||
              waybill.bajNumber.toLowerCase().contains(searchText) ||
              waybill.shippingVendor.toLowerCase().contains(searchText) ||
              waybill.consigneeReceiver.toLowerCase().contains(searchText) ||
              waybill.status.toLowerCase().contains(searchText);
        }).toList();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    waybills = WaybillService.getAllWaybills();
    loadWaybills();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
    final pendingCount = filteredWaybills
        .where((waybill) => waybill.status == 'Pending Delivery')
        .length;
    final deliveredCount = filteredWaybills
        .where((waybill) => waybill.status == 'Delivered')
        .length;
    final invoicedCount = filteredWaybills
        .where((waybill) => waybill.status == 'Invoiced')
        .length;
    final syncCount = filteredWaybills
        .where((waybill) => waybill.status == 'Pending Sync')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEAF3FF), Color(0xFFFFFFFF)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD7E7FB)),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD7E7FB),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Waybill Register',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF172033),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Search, open, and manage created waybills.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _SummaryPill(
                        label: 'Total',
                        value: filteredWaybills.length.toString(),
                        color: Colors.blue,
                        icon: Icons.list_alt,
                      ),
                      _SummaryPill(
                        label: 'Pending',
                        value: pendingCount.toString(),
                        color: Colors.orange,
                        icon: Icons.schedule,
                      ),
                      _SummaryPill(
                        label: 'Delivered',
                        value: deliveredCount.toString(),
                        color: Colors.green,
                        icon: Icons.check_circle,
                      ),
                      _SummaryPill(
                        label: 'Invoiced',
                        value: invoicedCount.toString(),
                        color: Colors.blue,
                        icon: Icons.receipt_long,
                      ),
                      _SummaryPill(
                        label: 'Pending Sync',
                        value: syncCount.toString(),
                        color: Colors.deepOrange,
                        icon: Icons.cloud_sync,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText:
                      'Search waybill, BAJ number, client, receiver or status',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            filterWaybills('');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Colors.blue,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: filterWaybills,
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: filteredWaybills.isEmpty
                  ? _buildEmptyState()
                  : isWideScreen
                  ? _buildTableView()
                  : _buildListView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: filteredWaybills.length,
      itemBuilder: (context, index) {
        final waybill = filteredWaybills[index];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE1E8F0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => openWaybillDetails(index, waybill),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          waybill.waybillNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF172033),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'BAJ No: ${waybill.bajNumber}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          waybill.shippingVendor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 10),
                        _StatusChip(
                          status: waybill.status,
                          color: getStatusColor(waybill.status),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        tooltip: 'View',
                        icon: const Icon(Icons.visibility, color: Colors.blue),
                        onPressed: () => openWaybillDetails(index, waybill),
                      ),
                      if (waybill.status == 'Pending Delivery')
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit, color: Colors.blueGrey),
                          onPressed: () => editWaybill(index, waybill),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFFEAF3FF),
              ),
              dataRowMinHeight: 58,
              dataRowMaxHeight: 68,
              columnSpacing: 28,
              horizontalMargin: 18,
              columns: const [
                DataColumn(label: Text('Waybill No.')),
                DataColumn(label: Text('BAJ No.')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Shipping/Vendor')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Action')),
              ],
              rows: filteredWaybills.map((waybill) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        waybill.waybillNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(Text(waybill.bajNumber)),
                    DataCell(Text(waybill.date)),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          waybill.shippingVendor,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      _StatusChip(
                        status: waybill.status,
                        color: getStatusColor(waybill.status),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {
                              final index =
                                  WaybillService.getIndexByWaybillNumber(
                                    waybill.waybillNumber,
                                  );
                              openWaybillDetails(index, waybill);
                            },
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('View'),
                          ),
                          if (waybill.status == 'Pending Delivery') ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                final index =
                                    WaybillService.getIndexByWaybillNumber(
                                      waybill.waybillNumber,
                                    );
                                editWaybill(index, waybill);
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE1E8F0)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.blueGrey),
            SizedBox(height: 12),
            Text(
              'No waybills found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Try another waybill number, BAJ number, vendor, or status.',
              style: TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
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
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(Icons.circle, size: 12, color: color),
      label: Text(status),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.24)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}
