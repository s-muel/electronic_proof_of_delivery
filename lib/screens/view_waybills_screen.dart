import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
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

  void loadWaybills() {
    allWaybills = WaybillService.getAllWaybills();
    filteredWaybills = allWaybills;
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
      appBar: AppBar(title: const Text('View Waybills')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
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
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: filterWaybills,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: filteredWaybills.isEmpty
                  ? const Center(
                      child: Text(
                        'No waybills found',
                        style: TextStyle(fontSize: 18),
                      ),
                    )
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
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.blue),
            title: Text('Waybill No: ${waybill.waybillNumber}'),
            subtitle: Text(
              'BAJ No: ${waybill.bajNumber}\nClient: ${waybill.shippingVendor}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
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
                if (waybill.status == 'Pending Delivery')
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => editWaybill(index, waybill),
                  ),
              ],
            ),
            isThreeLine: true,
            onTap: () => openWaybillDetails(index, waybill),
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
        rows: filteredWaybills.map((waybill) {
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
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        final index = WaybillService.getIndexByWaybillNumber(
                          waybill.waybillNumber,
                        );
                        openWaybillDetails(index, waybill);
                      },
                      child: const Text('View'),
                    ),
                    if (waybill.status == 'Pending Delivery')
                      TextButton.icon(
                        onPressed: () {
                          final index = waybills.indexOf(waybill);
                          editWaybill(index, waybill);
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
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
