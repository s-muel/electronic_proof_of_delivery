import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../services/delivery_sync_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_waybill_service.dart';
import '../services/waybill_service.dart';
import '../utils/platform_flags.dart';
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
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    if (shouldSkipAutomaticFirebaseRefresh) {
      setState(() {
        pendingWaybills = WaybillService.getPendingWaybills();
        deliveredWaybills = WaybillService.getDeliveredWaybills();
        invoicedWaybills = WaybillService.getInvoicedWaybills();
      });
    } else {
      loadWaybills();
    }
  }

  Future<void> loadWaybills() async {
    if (shouldUseFirestoreData) {
      try {
        final allWaybills = await FirestoreWaybillService.getAllWaybills();
        await WaybillService.replaceCachedWaybills(allWaybills);
      } catch (_) {
        // Keep using local cached data when Firestore is unavailable.
      }
    }

    if (!mounted) return;

    setState(() {
      pendingWaybills = WaybillService.getPendingWaybills();
      deliveredWaybills = WaybillService.getDeliveredWaybills();
      invoicedWaybills = WaybillService.getInvoicedWaybills();
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
    await loadWaybills();

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

    await loadWaybills();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts Dashboard'),
        actions: [
          IconButton(
            onPressed: () => loadWaybills(),
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
          await loadWaybills();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                childAspectRatio: isWideScreen ? 3.2 : 3.8,
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
    if (shouldUseFirestoreData) {
      try {
        await FirestoreWaybillService.updateWaybill(updatedWaybill);
      } catch (_) {
        // Keep the local invoiced update if Firestore is temporarily unavailable.
      }
    }

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
    const Color pageColor = Colors.blue;
    final IconData pageIcon = widget.showMarkInvoicedButton
        ? Icons.receipt_long
        : Icons.done_all;

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
                border: Border.all(color: pageColor.withValues(alpha: 0.22)),
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
                                color: pageColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Icon(Icons.arrow_back, color: pageColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: pageColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(pageIcon, color: pageColor, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF172033),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.showMarkInvoicedButton
                                ? 'Delivered waybills waiting for invoice processing.'
                                : 'Waybills already marked as invoiced.',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _AccountsSummaryPill(
                        label: 'Showing',
                        value: filteredWaybills.length.toString(),
                        color: pageColor,
                        icon: Icons.filter_list,
                      ),
                      _AccountsSummaryPill(
                        label: widget.showMarkInvoicedButton
                            ? 'Ready'
                            : 'Invoiced',
                        value: allWaybills.length.toString(),
                        color: pageColor,
                        icon: pageIcon,
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
                    borderSide: BorderSide(color: pageColor, width: 1.5),
                  ),
                ),
                onChanged: filterWaybills,
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: filteredWaybills.isEmpty
                  ? _buildEmptyState(pageColor)
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

        final statusColor = getStatusColor(waybill.status);

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
            onTap: () => openWaybillDetails(originalIndex, waybill),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      waybill.status == 'Delivered'
                          ? Icons.receipt_long
                          : Icons.done_all,
                      color: statusColor,
                    ),
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
                        const SizedBox(height: 3),
                        Text(
                          'Delivered: ${_formatDateTime(waybill.deliveredAt)}',
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _AccountsStatusChip(
                          status: waybill.status,
                          color: statusColor,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        tooltip: 'View',
                        icon: const Icon(Icons.visibility, color: Colors.blue),
                        onPressed: () =>
                            openWaybillDetails(originalIndex, waybill),
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1180),
              child: DataTable(
                columnSpacing: 24,
                horizontalMargin: 18,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 68,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFEAF3FF),
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
                  final statusColor = getStatusColor(waybill.status);

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
                          width: 190,
                          child: Text(
                            waybill.shippingVendor,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(_formatDateTime(waybill.deliveredAt))),
                      DataCell(
                        _AccountsStatusChip(
                          status: waybill.status,
                          color: statusColor,
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: widget.showMarkInvoicedButton ? 275 : 120,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    openWaybillDetails(originalIndex, waybill),
                                icon: const Icon(Icons.visibility, size: 16),
                                label: const Text('View'),
                              ),
                              if (widget.showMarkInvoicedButton &&
                                  waybill.status == 'Delivered')
                                FilledButton.icon(
                                  onPressed: () => confirmMarkAsInvoiced(
                                    originalIndex,
                                    waybill,
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.done_all, size: 16),
                                  label: const Text('Mark Invoiced'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color color) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE1E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              'No ${widget.title.toLowerCase()} found',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try refreshing the dashboard or searching with another value.',
              style: TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsSummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _AccountsSummaryPill({
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

class _AccountsStatusChip extends StatelessWidget {
  final String status;
  final Color color;

  const _AccountsStatusChip({required this.status, required this.color});

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1,
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
