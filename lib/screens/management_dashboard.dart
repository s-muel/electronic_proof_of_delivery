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

class ManagementDashboard extends StatefulWidget {
  const ManagementDashboard({super.key});

  @override
  State<ManagementDashboard> createState() => _ManagementDashboardState();
}

class _ManagementDashboardState extends State<ManagementDashboard> {
  List<WaybillModel> waybills = [];
  bool isSyncing = false;
  String managerName = '';
  String? openingCardKey;

  @override
  void initState() {
    super.initState();
    if (shouldSkipAutomaticFirebaseRefresh) {
      setState(() => waybills = WaybillService.getAllWaybills());
    } else {
      loadDashboard();
    }
  }

  Future<void> loadDashboard() async {
    final firebaseUser = FirebaseAuthService.currentFirebaseUser;
    var loadedManagerName =
        firebaseUser?.displayName ?? firebaseUser?.email ?? '';

    try {
      final profile = await FirebaseAuthService.getCurrentUserProfile();
      loadedManagerName = profile?.fullName ?? loadedManagerName;
    } catch (_) {
      // Keep the dashboard usable even if the profile refresh fails.
    }

    if (shouldUseFirestoreData) {
      try {
        final allWaybills = await FirestoreWaybillService.getAllWaybills();
        await WaybillService.replaceCachedWaybills(allWaybills);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load management data: $error')),
          );
        }
      }
    }

    if (!mounted) return;

    setState(() {
      managerName = loadedManagerName;
      waybills = WaybillService.getAllWaybills();
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
    await loadDashboard();

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

  Future<void> _logout() async {
    await FirebaseAuthService.signOut();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _openWaybillList({
    required String title,
    required List<WaybillModel> selectedWaybills,
    required String cardKey,
  }) async {
    if (openingCardKey != null) return;

    setState(() => openingCardKey = cardKey);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManagementWaybillListScreen(
          title: title,
          waybills: selectedWaybills,
        ),
      ),
    );

    if (!mounted) return;

    setState(() => openingCardKey = null);
  }

  Future<void> _openExceptionWaybillList({
    required String title,
    required List<WaybillModel> selectedWaybills,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManagementWaybillListScreen(
          title: title,
          waybills: selectedWaybills,
        ),
      ),
    );
  }

  List<WaybillModel> get _pendingWaybills => waybills
      .where(
        (waybill) => waybill.status == WaybillService.pendingDeliveryStatus,
      )
      .toList();

  List<WaybillModel> get _deliveredWaybills => waybills
      .where((waybill) => waybill.status == WaybillService.deliveredStatus)
      .toList();

  List<WaybillModel> get _invoicedWaybills => waybills
      .where((waybill) => waybill.status == WaybillService.invoicedStatus)
      .toList();

  List<WaybillModel> get _issueWaybills => waybills.where((waybill) {
    return waybill.isShort ||
        waybill.isOver ||
        waybill.isDamaged ||
        waybill.isParkingUnsuitable ||
        waybill.isPartOrder;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Management Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF4F7FB),
        foregroundColor: const Color(0xFF172033),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Dashboard',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManagementHero(
                managerName: managerName,
                totalCount: waybills.length,
                deliveredCount: _deliveredWaybills.length,
                issueCount: _issueWaybills.length,
              ),
              const SizedBox(height: 18),
              NetworkStatusBar(onSyncNow: syncNow, isSyncing: isSyncing),
              const SizedBox(height: 22),
              const Text(
                'Company Waybill Overview',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isWideScreen ? 5 : 1,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: isWideScreen ? 2.2 : 3.8,
                children: [
                  _MetricCard(
                    title: 'Total Waybills',
                    value: waybills.length,
                    icon: Icons.inventory_2,
                    color: Colors.indigo,
                    isLoading: openingCardKey == 'total',
                    onTap: () => _openWaybillList(
                      title: 'All Waybills',
                      selectedWaybills: waybills,
                      cardKey: 'total',
                    ),
                  ),
                  _MetricCard(
                    title: 'Pending',
                    value: _pendingWaybills.length,
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                    isLoading: openingCardKey == 'pending',
                    onTap: () => _openWaybillList(
                      title: 'Pending Deliveries',
                      selectedWaybills: _pendingWaybills,
                      cardKey: 'pending',
                    ),
                  ),
                  _MetricCard(
                    title: 'Delivered',
                    value: _deliveredWaybills.length,
                    icon: Icons.local_shipping,
                    color: Colors.green,
                    isLoading: openingCardKey == 'delivered',
                    onTap: () => _openWaybillList(
                      title: 'Delivered Waybills',
                      selectedWaybills: _deliveredWaybills,
                      cardKey: 'delivered',
                    ),
                  ),
                  _MetricCard(
                    title: 'Invoiced',
                    value: _invoicedWaybills.length,
                    icon: Icons.receipt_long,
                    color: Colors.blue,
                    isLoading: openingCardKey == 'invoiced',
                    onTap: () => _openWaybillList(
                      title: 'Invoiced Waybills',
                      selectedWaybills: _invoicedWaybills,
                      cardKey: 'invoiced',
                    ),
                  ),
                  _MetricCard(
                    title: 'Issues',
                    value: _issueWaybills.length,
                    icon: Icons.report_problem,
                    color: Colors.red,
                    isLoading: openingCardKey == 'issues',
                    onTap: () => _openWaybillList(
                      title: 'Waybills With Issues',
                      selectedWaybills: _issueWaybills,
                      cardKey: 'issues',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 950) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ExceptionPanel(
                            waybills: waybills,
                            onOpenIssue: _openExceptionWaybillList,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _StatusGraphPanel(waybills: waybills)),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _ExceptionPanel(
                        waybills: waybills,
                        onOpenIssue: _openExceptionWaybillList,
                      ),
                      const SizedBox(height: 16),
                      _StatusGraphPanel(waybills: waybills),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ManagementWaybillListScreen extends StatefulWidget {
  final String title;
  final List<WaybillModel> waybills;

  const ManagementWaybillListScreen({
    super.key,
    required this.title,
    required this.waybills,
  });

  @override
  State<ManagementWaybillListScreen> createState() =>
      _ManagementWaybillListScreenState();
}

class _ManagementWaybillListScreenState
    extends State<ManagementWaybillListScreen> {
  late List<WaybillModel> filteredWaybills;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredWaybills = widget.waybills;
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
        filteredWaybills = widget.waybills;
      } else {
        filteredWaybills = widget.waybills.where((waybill) {
          return waybill.waybillNumber.toLowerCase().contains(searchText) ||
              waybill.bajNumber.toLowerCase().contains(searchText) ||
              waybill.shippingVendor.toLowerCase().contains(searchText) ||
              waybill.consigneeReceiver.toLowerCase().contains(searchText) ||
              waybill.status.toLowerCase().contains(searchText);
        }).toList();
      }
    });
  }

  Future<void> openWaybill(WaybillModel waybill) async {
    final index = WaybillService.getIndexByWaybillNumber(waybill.waybillNumber);

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

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEAF3FF), Color(0xFFFFFFFF)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
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
                          '${filteredWaybills.length} waybills showing',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText:
                    'Search waybill, BAJ number, client, receiver or status',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
                ),
              ),
              onChanged: filterWaybills,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredWaybills.isEmpty
                  ? const Center(child: Text('No waybills found.'))
                  : isWideScreen
                  ? _buildTableView()
                  : _buildCardList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardList() {
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
          child: ListTile(
            onTap: () => openWaybill(waybill),
            leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
            title: Text(
              waybill.waybillNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'BAJ: ${waybill.bajNumber}\nClient: ${waybill.consigneeReceiver}\nStatus: ${waybill.status}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
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
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1080),
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
                  DataColumn(label: Text('Client/Receiver')),
                  DataColumn(label: Text('Driver')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Center(child: Text('Actions'))),
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
                            waybill.consigneeReceiver,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: Text(
                            waybill.driverName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(_StatusChip(status: waybill.status)),
                      DataCell(
                        FilledButton.tonalIcon(
                          onPressed: () => openWaybill(waybill),
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('View'),
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
}

class _ManagementHero extends StatelessWidget {
  final String managerName;
  final int totalCount;
  final int deliveredCount;
  final int issueCount;

  const _ManagementHero({
    required this.managerName,
    required this.totalCount,
    required this.deliveredCount,
    required this.issueCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF063B78), Color(0xFF1484E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.22),
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.insights,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Management Control Center',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (managerName.trim().isNotEmpty) ...[
                    Text(
                      'Welcome, $managerName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  const Text(
                    'Monitor company deliveries, invoice movement, and exceptions.',
                    style: TextStyle(color: Color(0xFFEAF3FF)),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(
                label: 'Total',
                value: totalCount.toString(),
                icon: Icons.inventory_2,
              ),
              _HeroPill(
                label: 'Delivered',
                value: deliveredCount.toString(),
                icon: Icons.local_shipping,
              ),
              _HeroPill(
                label: 'Issues',
                value: issueCount.toString(),
                icon: Icons.report_problem,
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

  const _HeroPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFFEAF3FF))),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.toString(),
                      style: TextStyle(
                        color: color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF172033),
                      ),
                    ),
                  ],
                ),
              ),
              isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: color,
                      ),
                    )
                  : Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExceptionPanel extends StatelessWidget {
  final List<WaybillModel> waybills;
  final Future<void> Function({
    required String title,
    required List<WaybillModel> selectedWaybills,
  })
  onOpenIssue;

  const _ExceptionPanel({required this.waybills, required this.onOpenIssue});

  @override
  Widget build(BuildContext context) {
    final shortWaybills = waybills.where((waybill) => waybill.isShort).toList();
    final overWaybills = waybills.where((waybill) => waybill.isOver).toList();
    final damagedWaybills = waybills
        .where((waybill) => waybill.isDamaged)
        .toList();
    final parkingWaybills = waybills
        .where((waybill) => waybill.isParkingUnsuitable)
        .toList();
    final partOrderWaybills = waybills
        .where((waybill) => waybill.isPartOrder)
        .toList();

    return _Panel(
      title: 'Delivery Exceptions',
      subtitle: 'Operational issues reported during delivery.',
      icon: Icons.warning_amber_rounded,
      child: Column(
        children: [
          _ExceptionRow(
            label: 'Short',
            value: shortWaybills.length,
            color: Colors.orange,
            onTap: () => onOpenIssue(
              title: 'Short Waybills',
              selectedWaybills: shortWaybills,
            ),
          ),
          _ExceptionRow(
            label: 'Over',
            value: overWaybills.length,
            color: Colors.blue,
            onTap: () => onOpenIssue(
              title: 'Over Waybills',
              selectedWaybills: overWaybills,
            ),
          ),
          _ExceptionRow(
            label: 'Damaged',
            value: damagedWaybills.length,
            color: Colors.red,
            onTap: () => onOpenIssue(
              title: 'Damaged Waybills',
              selectedWaybills: damagedWaybills,
            ),
          ),
          _ExceptionRow(
            label: 'Parking Unsuitable',
            value: parkingWaybills.length,
            color: Colors.deepPurple,
            onTap: () => onOpenIssue(
              title: 'Parking Unsuitable Waybills',
              selectedWaybills: parkingWaybills,
            ),
          ),
          _ExceptionRow(
            label: 'Part Order',
            value: partOrderWaybills.length,
            color: Colors.teal,
            onTap: () => onOpenIssue(
              title: 'Part Order Waybills',
              selectedWaybills: partOrderWaybills,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusGraphPanel extends StatefulWidget {
  final List<WaybillModel> waybills;

  const _StatusGraphPanel({required this.waybills});

  @override
  State<_StatusGraphPanel> createState() => _StatusGraphPanelState();
}

class _StatusGraphPanelState extends State<_StatusGraphPanel> {
  String selectedFilter = 'All';
  int selectedMonth = 0;
  int selectedYear = DateTime.now().year < 2026 ? 2026 : DateTime.now().year;

  static const List<String> monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  List<WaybillModel> get filteredWaybills {
    if (selectedFilter == 'All') return widget.waybills;

    final start = selectedMonth == 0
        ? DateTime(selectedYear)
        : DateTime(selectedYear, selectedMonth);
    final end = selectedMonth == 0
        ? DateTime(selectedYear + 1)
        : DateTime(selectedYear, selectedMonth + 1);

    return widget.waybills.where((waybill) {
      final waybillDate = _waybillDate(waybill);
      if (waybillDate == null) return false;
      return !waybillDate.isBefore(start!) && waybillDate.isBefore(end!);
    }).toList();
  }

  DateTime? _waybillDate(WaybillModel waybill) {
    if (waybill.createdAt.trim().isEmpty) return null;
    return DateTime.tryParse(waybill.createdAt);
  }

  String get _subtitle {
    if (selectedFilter == 'All') {
      return 'A quick view of all waybills by current status.';
    }

    if (selectedMonth == 0) {
      return 'Showing all months in $selectedYear.';
    }

    return 'Showing ${monthNames[selectedMonth - 1]} $selectedYear.';
  }

  @override
  Widget build(BuildContext context) {
    final graphWaybills = filteredWaybills;
    final pendingCount = graphWaybills
        .where(
          (waybill) => waybill.status == WaybillService.pendingDeliveryStatus,
        )
        .length;
    final deliveredCount = graphWaybills
        .where((waybill) => waybill.status == WaybillService.deliveredStatus)
        .length;
    final invoicedCount = graphWaybills
        .where((waybill) => waybill.status == WaybillService.invoicedStatus)
        .length;
    final issueCount = graphWaybills.where((waybill) {
      return waybill.isShort ||
          waybill.isOver ||
          waybill.isDamaged ||
          waybill.isParkingUnsuitable ||
          waybill.isPartOrder;
    }).length;
    final maxCount = [
      pendingCount,
      deliveredCount,
      invoicedCount,
      issueCount,
      1,
    ].reduce((a, b) => a > b ? a : b);

    return _Panel(
      title: 'Waybill Status Graph',
      subtitle: _subtitle,
      icon: Icons.bar_chart,
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: selectedFilter == 'All',
                onSelected: (_) => setState(() => selectedFilter = 'All'),
              ),
              ChoiceChip(
                label: const Text('By Month'),
                selected: selectedFilter == 'Month',
                onSelected: (_) => setState(() => selectedFilter = 'Month'),
              ),
              DropdownButton<int>(
                value: selectedMonth,
                items: [
                  const DropdownMenuItem(value: 0, child: Text('All')),
                  for (var index = 0; index < monthNames.length; index++)
                    DropdownMenuItem(
                      value: index + 1,
                      child: Text(monthNames[index]),
                    ),
                ],
                onChanged: selectedFilter == 'Month'
                    ? (value) {
                        if (value == null) return;
                        setState(() => selectedMonth = value);
                      }
                    : null,
              ),
              DropdownButton<int>(
                value: selectedYear,
                items: [
                  for (var year = 2026; year <= DateTime.now().year + 5; year++)
                    DropdownMenuItem(value: year, child: Text(year.toString())),
                ],
                onChanged: selectedFilter == 'Month'
                    ? (value) {
                        if (value == null) return;
                        setState(() => selectedYear = value);
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StatusGraphBar(
            label: 'Pending Delivery',
            value: pendingCount,
            maxValue: maxCount,
            color: Colors.orange,
          ),
          _StatusGraphBar(
            label: 'Delivered',
            value: deliveredCount,
            maxValue: maxCount,
            color: Colors.blue,
          ),
          _StatusGraphBar(
            label: 'Invoiced',
            value: invoicedCount,
            maxValue: maxCount,
            color: Colors.green,
          ),
          _StatusGraphBar(
            label: 'Issues',
            value: issueCount,
            maxValue: maxCount,
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _StatusGraphBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;

  const _StatusGraphBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maxValue == 0 ? 0.0 : value / maxValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                value.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 14,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _Panel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDE8F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ExceptionRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;

  const _ExceptionRow({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  value.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;

    if (status == WaybillService.deliveredStatus) {
      color = Colors.green;
    } else if (status == WaybillService.invoicedStatus) {
      color = Colors.blue;
    } else if (status == WaybillService.pendingSyncStatus) {
      color = Colors.red;
    } else {
      color = Colors.orange;
    }

    return Chip(
      label: Text(status),
      backgroundColor: color.withValues(alpha: 0.10),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}
