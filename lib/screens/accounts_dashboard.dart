import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../services/waybill_service.dart';
import '../widgets/network_status_bar.dart';
import 'login_screen.dart';
import 'waybill_details_screen.dart';

class AccountsDashboard extends StatefulWidget {
  const AccountsDashboard({super.key});

  @override
  State<AccountsDashboard> createState() => _AccountsDashboardState();
}

class _AccountsDashboardState extends State<AccountsDashboard> {
  List<WaybillModel> pendingWaybills = [];
  List<WaybillModel> deliveredWaybills = [];
  List<WaybillModel> invoicedWaybills = [];

  @override
  void initState() {
    super.initState();
    loadWaybills();
  }

  void loadWaybills() {
    setState(() {
      pendingWaybills = WaybillService.getPendingWaybills();
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

  Future<void> openAccountsList({
    required String title,
    required List<WaybillModel> waybills,
    required bool showMarkInvoicedButton,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountsWaybillListScreen(
          title: title,
          waybills: waybills,
          showMarkInvoicedButton: showMarkInvoicedButton,
        ),
      ),
    );

    loadWaybills();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts Dashboard'),
        actions: [
          IconButton(
            onPressed: loadWaybills,
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
          loadWaybills();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NetworkStatusBar(),

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
                childAspectRatio: isWideScreen ? 2.6 : 3.2,
                children: [
                  _SummaryCard(
                    title: 'Pending Delivery',
                    count: pendingWaybills.length,
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                  ),
                  _SummaryCard(
                    title: 'Delivered',
                    count: deliveredWaybills.length,
                    icon: Icons.local_shipping,
                    color: Colors.green,
                  ),
                  _SummaryCard(
                    title: 'Invoiced',
                    count: invoicedWaybills.length,
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
                    icon: Icons.receipt_long,
                    title: 'Ready for Invoice',
                    subtitle: 'View delivered waybills awaiting invoice',
                    color: Colors.green,
                    onTap: () {
                      openAccountsList(
                        title: 'Ready for Invoice',
                        waybills: WaybillService.getDeliveredWaybills(),
                        showMarkInvoicedButton: true,
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.done_all,
                    title: 'Invoiced',
                    subtitle: 'View already invoiced waybills',
                    color: Colors.blue,
                    onTap: () {
                      openAccountsList(
                        title: 'Invoiced Waybills',
                        waybills: WaybillService.getInvoicedWaybills(),
                        showMarkInvoicedButton: false,
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.visibility,
                    title: 'View Waybill',
                    subtitle: 'View delivered and invoiced waybills only',
                    color: Colors.purple,
                    onTap: () {
                      final viewableWaybills = [
                        ...WaybillService.getDeliveredWaybills(),
                        ...WaybillService.getInvoicedWaybills(),
                      ];

                      openAccountsList(
                        title: 'View Waybills',
                        waybills: viewableWaybills,
                        showMarkInvoicedButton: false,
                      );
                    },
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

class AccountsWaybillListScreen extends StatefulWidget {
  final String title;
  final List<WaybillModel> waybills;
  final bool showMarkInvoicedButton;

  const AccountsWaybillListScreen({
    super.key,
    required this.title,
    required this.waybills,
    required this.showMarkInvoicedButton,
  });

  @override
  State<AccountsWaybillListScreen> createState() =>
      _AccountsWaybillListScreenState();
}

class _AccountsWaybillListScreenState extends State<AccountsWaybillListScreen> {
  late List<WaybillModel> allWaybills;
  late List<WaybillModel> filteredWaybills;

  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    allWaybills = widget.waybills;
    filteredWaybills = allWaybills;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
        builder: (_) => WaybillDetailsScreen(waybill: waybill, index: index),
      ),
    );
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

    setState(() {
      allWaybills.removeWhere(
        (item) => item.waybillNumber == waybill.waybillNumber,
      );

      filteredWaybills.removeWhere(
        (item) => item.waybillNumber == waybill.waybillNumber,
      );
    });
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

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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

            const SizedBox(height: 20),

            Expanded(
              child: filteredWaybills.isEmpty
                  ? Center(
                      child: Text(
                        'No ${widget.title.toLowerCase()} found',
                        style: const TextStyle(fontSize: 18),
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
                if (widget.showMarkInvoicedButton &&
                    waybill.status == 'Delivered')
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
          DataColumn(label: Text('Delivered At')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: filteredWaybills.map((waybill) {
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
                    if (widget.showMarkInvoicedButton &&
                        waybill.status == 'Delivered')
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
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

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
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
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
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
                      overflow: TextOverflow.ellipsis,
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
