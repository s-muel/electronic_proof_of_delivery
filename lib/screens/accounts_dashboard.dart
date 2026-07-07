import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/waybill_model.dart';
import '../models/waybill_stats_model.dart';
import '../services/delivery_sync_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_waybill_service.dart';
import '../services/pdf_service.dart';
import '../services/waybill_service.dart';
import '../utils/platform_flags.dart';
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
  List<WaybillModel> sentForInvoicingWaybills = [];
  List<WaybillModel> rejectedInvoiceWaybills = [];
  List<WaybillModel> invoicedWaybills = [];
  WaybillStatsModel? dashboardStats;
  bool isSyncing = false;
  String accountName = '';

  int get pendingDeliveryCount =>
      dashboardStats?.pendingDelivery ?? pendingWaybills.length;

  int get readyForInvoiceCount =>
      dashboardStats?.readyForInvoice ?? deliveredWaybills.length;

  int get sentForInvoicingCount =>
      dashboardStats?.sentForInvoicing ?? sentForInvoicingWaybills.length;

  int get rejectedInvoiceCount =>
      dashboardStats?.rejected ?? rejectedInvoiceWaybills.length;

  int get invoicedCount => dashboardStats?.invoiced ?? invoicedWaybills.length;

  @override
  void initState() {
    super.initState();
    if (shouldSkipAutomaticFirebaseRefresh) {
      setState(() {
        pendingWaybills = WaybillService.getPendingWaybills();
        deliveredWaybills = WaybillService.getReadyForInvoiceWaybills();
        sentForInvoicingWaybills = WaybillService.getSentForInvoicingWaybills();
        rejectedInvoiceWaybills = WaybillService.getRejectedInvoiceWaybills();
        invoicedWaybills = WaybillService.getInvoicedWaybills();
      });
    } else {
      loadWaybills();
    }
  }

  Future<void> loadWaybills() async {
    final firebaseUser = FirebaseAuthService.currentFirebaseUser;
    var loadedAccountName =
        firebaseUser?.displayName ?? firebaseUser?.email ?? '';

    try {
      final profile = await FirebaseAuthService.getCurrentUserProfile();
      loadedAccountName = profile?.fullName ?? loadedAccountName;
    } catch (_) {
      // Use Firebase Auth display data if the profile cannot be refreshed.
    }

    if (shouldUseFirestoreData) {
      try {
        dashboardStats = await FirestoreWaybillService.getWaybillStats();
      } catch (error) {
        // Keep using local cached data when Firestore is unavailable.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load waybills: $error')),
          );
        }
      }
    }

    if (!mounted) return;

    setState(() {
      accountName = loadedAccountName;
      pendingWaybills = WaybillService.getPendingWaybills();
      deliveredWaybills = WaybillService.getReadyForInvoiceWaybills();
      sentForInvoicingWaybills = WaybillService.getSentForInvoicingWaybills();
      rejectedInvoiceWaybills = WaybillService.getRejectedInvoiceWaybills();
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

    if (!mounted) return;

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
    String invoiceActionMode = 'none',
    int? readyCount,
    int? invoicedCount,
    bool showFullSummary = false,
    String? serverStatusFilter,
    String? serverInvoiceStatusFilter,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountsWaybillListScreen(
          title: title,
          waybills: waybills,
          showMarkInvoicedButton: showMarkInvoicedButton,
          invoiceActionMode: invoiceActionMode,
          readyCount: readyCount,
          invoicedCount: invoicedCount,
          showFullSummary: showFullSummary,
          serverStatusFilter: serverStatusFilter,
          serverInvoiceStatusFilter: serverInvoiceStatusFilter,
        ),
      ),
    );

    await loadWaybills();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Row(
        children: [
          if (isWideScreen) _buildSidebar(context),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isWideScreen ? 22 : 16,
                  18,
                  isWideScreen ? 22 : 16,
                  18,
                ),
                child: _buildDashboardContent(context, isWideScreen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 214,
      decoration: const BoxDecoration(
        color: Color(0xFFEAF3FF),
        border: Border(right: BorderSide(color: Color(0xFFD6E4F5))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F5FB8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BAJ E-POD',
                          style: TextStyle(
                            color: Color(0xFF0A467F),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Accounts Desk',
                          style: TextStyle(
                            color: Color(0xFF5B718C),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SidebarItem(
                icon: Icons.dashboard_customize,
                label: 'Dashboard',
                isActive: true,
                onTap: () {},
              ),
              _SidebarItem(
                icon: Icons.receipt_long,
                label: 'Ready for Invoice',
                onTap: _openReadyForInvoice,
              ),
              _SidebarItem(
                icon: Icons.send,
                label: 'Sent for Invoicing',
                onTap: _openSentForInvoicing,
              ),
              _SidebarItem(
                icon: Icons.done_all,
                label: 'Invoiced',
                onTap: _openInvoicedWaybills,
              ),
              _SidebarItem(
                icon: Icons.report_problem,
                label: 'Rejected',
                onTap: _openRejectedWaybills,
              ),
              _SidebarItem(
                icon: Icons.visibility,
                label: 'View Waybills',
                onTap: _openAllWaybills,
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD6E4F5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Logged in as',
                      style: TextStyle(color: Color(0xFF6B7D90), fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      accountName.trim().isEmpty
                          ? 'Accounts User'
                          : accountName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout, size: 17),
                      label: const Text('Logout'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0F5FB8),
                        padding: EdgeInsets.zero,
                      ),
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

  Widget _buildDashboardContent(BuildContext context, bool isWideScreen) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && !isWideScreen;
    final summaryColumns = isWideScreen ? 5 : (isTablet ? 2 : 1);
    final actionColumns = isWideScreen ? 3 : (isTablet ? 2 : 1);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroPanel(isWideScreen),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Waybill Summary',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172033),
                ),
              ),
              TextButton.icon(
                onPressed: _openAllWaybills,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: summaryColumns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: isWideScreen ? 2.25 : (isTablet ? 2.8 : 3.8),
            children: [
              _SummaryCard(
                title: 'Pending Delivery',
                count: pendingDeliveryCount,
                icon: Icons.pending_actions,
                color: Colors.orange,
              ),
              _SummaryCard(
                title: 'Ready for Invoice',
                count: readyForInvoiceCount,
                icon: Icons.receipt_long,
                color: Colors.blue,
              ),
              _SummaryCard(
                title: 'Sent for Invoicing',
                count: sentForInvoicingCount,
                icon: Icons.send,
                color: Colors.indigo,
              ),
              _SummaryCard(
                title: 'Rejected',
                count: rejectedInvoiceCount,
                icon: Icons.report_problem,
                color: Colors.red,
              ),
              _SummaryCard(
                title: 'Invoiced',
                count: invoicedCount,
                icon: Icons.done_all,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: actionColumns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: isWideScreen ? 3.65 : (isTablet ? 2.8 : 3.2),
            children: [
              _DashboardCard(
                icon: Icons.receipt_long,
                title: 'Ready for Invoice',
                subtitle: 'View delivered waybills awaiting invoice',
                color: Colors.blue,
                onTap: _openReadyForInvoice,
              ),
              _DashboardCard(
                icon: Icons.send,
                title: 'Sent for Invoicing',
                subtitle: 'Awaiting client acceptance or rejection',
                color: Colors.indigo,
                onTap: _openSentForInvoicing,
              ),
              _DashboardCard(
                icon: Icons.done_all,
                title: 'Invoiced',
                subtitle: 'View already invoiced waybills',
                color: Colors.green,
                onTap: _openInvoicedWaybills,
              ),
              _DashboardCard(
                icon: Icons.report_problem,
                title: 'Rejected',
                subtitle: 'View rejected waybills and reasons',
                color: Colors.red,
                onTap: _openRejectedWaybills,
              ),
              _DashboardCard(
                icon: Icons.visibility,
                title: 'View Waybills',
                subtitle: 'View all waybills in the system',
                color: Colors.blue,
                onTap: _openAllWaybills,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPanel(bool isWideScreen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE1E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
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
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F5FB8), Color(0xFF1D8BE8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Accounts Control Center',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172033),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    accountName.trim().isEmpty
                        ? 'Monitor delivered waybills, invoicing progress, and client responses.'
                        : 'Welcome, $accountName. Monitor invoices and waybill movement.',
                    style: const TextStyle(color: Color(0xFF5B718C)),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF0F5FB8),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$readyForInvoiceCount Ready',
                      style: const TextStyle(
                        color: Color(0xFF0F5FB8),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Awaiting billing',
                      style: TextStyle(
                        color: Color(0xFF5B718C),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openReadyForInvoice() {
    openAccountsList(
      title: 'Ready for Invoice',
      waybills: WaybillService.getReadyForInvoiceWaybills(),
      showMarkInvoicedButton: true,
      invoiceActionMode: 'markSent',
      readyCount: dashboardStats?.readyForInvoice,
      invoicedCount: dashboardStats?.invoiced,
      serverStatusFilter: WaybillService.deliveredStatus,
      serverInvoiceStatusFilter: WaybillService.invoiceNotSentStatus,
    );
  }

  void _openSentForInvoicing() {
    openAccountsList(
      title: 'Sent for Invoicing',
      waybills: WaybillService.getSentForInvoicingWaybills(),
      showMarkInvoicedButton: true,
      invoiceActionMode: 'sentReview',
      readyCount: dashboardStats?.readyForInvoice,
      invoicedCount: dashboardStats?.invoiced,
      serverInvoiceStatusFilter: WaybillService.invoiceSentStatus,
    );
  }

  void _openInvoicedWaybills() {
    openAccountsList(
      title: 'Invoiced Waybills',
      waybills: WaybillService.getInvoicedWaybills(),
      showMarkInvoicedButton: false,
      readyCount: dashboardStats?.readyForInvoice,
      invoicedCount: dashboardStats?.invoiced,
      serverStatusFilter: WaybillService.invoicedStatus,
    );
  }

  void _openRejectedWaybills() {
    openAccountsList(
      title: 'Rejected Waybills',
      waybills: WaybillService.getRejectedInvoiceWaybills(),
      showMarkInvoicedButton: false,
      invoiceActionMode: 'rejected',
      readyCount: dashboardStats?.readyForInvoice,
      invoicedCount: dashboardStats?.invoiced,
      serverInvoiceStatusFilter: WaybillService.invoiceRejectedStatus,
    );
  }

  void _openAllWaybills() {
    openAccountsList(
      title: 'View All Waybills',
      waybills: WaybillService.getAllWaybills(),
      showMarkInvoicedButton: false,
      readyCount: dashboardStats?.readyForInvoice,
      invoicedCount: dashboardStats?.invoiced,
      showFullSummary: true,
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: isActive
                  ? Border.all(color: const Color(0xFFD6E4F5))
                  : null,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive
                      ? const Color(0xFF0F5FB8)
                      : const Color(0xFF34465C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF0F5FB8)
                          : const Color(0xFF34465C),
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
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
  final String invoiceActionMode;
  final int? readyCount;
  final int? invoicedCount;
  final bool showFullSummary;
  final String? serverStatusFilter;
  final String? serverInvoiceStatusFilter;

  const AccountsWaybillListScreen({
    super.key,
    required this.title,
    required this.waybills,
    required this.showMarkInvoicedButton,
    this.invoiceActionMode = 'none',
    this.readyCount,
    this.invoicedCount,
    this.showFullSummary = false,
    this.serverStatusFilter,
    this.serverInvoiceStatusFilter,
  });

  @override
  State<AccountsWaybillListScreen> createState() =>
      _AccountsWaybillListScreenState();
}

class _AccountsWaybillListScreenState extends State<AccountsWaybillListScreen> {
  static const int _itemsPerPage = 25;
  late List<WaybillModel> allWaybills;
  late List<WaybillModel> filteredWaybills;
  final Set<String> _downloadingPdfWaybillNumbers = {};
  final List<DocumentSnapshot<Map<String, dynamic>>?> _pageCursors = [null];
  final Map<int, List<WaybillModel>> _loadedPageCache = {};
  final Map<int, bool> _pageHasMoreCache = {};

  final searchController = TextEditingController();
  int _currentPage = 0;
  bool _hasNextPage = false;
  bool _isLoadingPage = false;
  bool _usingLocalCache = false;
  int _localTotalItems = 0;
  int? _serverTotalWaybills;
  WaybillStatsModel? _summaryStats;
  List<WaybillModel>? _readyForInvoiceServerCache;

  bool get _usesServerPagination =>
      widget.showFullSummary ||
      widget.serverStatusFilter != null ||
      widget.serverInvoiceStatusFilter != null;

  bool get _isReadyForInvoiceFilter =>
      widget.serverStatusFilter == WaybillService.deliveredStatus &&
      widget.serverInvoiceStatusFilter == WaybillService.invoiceNotSentStatus;

  bool get shouldPaginate => _usesServerPagination
      ? _currentPage > 0 || _hasNextPage
      : filteredWaybills.length > _itemsPerPage;

  int get totalPages => filteredWaybills.isEmpty
      ? 1
      : ((filteredWaybills.length - 1) ~/ _itemsPerPage) + 1;

  List<WaybillModel> get visibleWaybills {
    if (_usesServerPagination) return filteredWaybills;

    final start = _currentPage * _itemsPerPage;
    if (start >= filteredWaybills.length) return const [];

    final end = (start + _itemsPerPage).clamp(0, filteredWaybills.length);
    return filteredWaybills.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    allWaybills = _usesServerPagination
        ? widget.waybills.take(_itemsPerPage).toList()
        : widget.waybills;
    filteredWaybills = allWaybills;
    if (_usesServerPagination) {
      _hasNextPage = widget.waybills.length >= _itemsPerPage;
      loadWaybillPage();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void filterWaybills(String query) {
    final searchText = query.toLowerCase().trim();

    setState(() {
      if (!_usesServerPagination) _currentPage = 0;

      if (searchText.isEmpty) {
        filteredWaybills = allWaybills;
      } else {
        filteredWaybills = allWaybills.where((waybill) {
          return waybill.waybillNumber.toLowerCase().contains(searchText) ||
              waybill.bajNumber.toLowerCase().contains(searchText) ||
              waybill.shippingVendor.toLowerCase().contains(searchText) ||
              waybill.consigneeReceiver.toLowerCase().contains(searchText) ||
              waybill.status.toLowerCase().contains(searchText) ||
              waybill.invoiceStatus.toLowerCase().contains(searchText) ||
              waybill.invoiceRejectionReason.toLowerCase().contains(searchText);
        }).toList();
      }
    });
  }

  int? _totalFromStats(WaybillStatsModel? stats) {
    if (stats == null) return null;

    if (widget.showFullSummary) return stats.total;

    if (widget.serverStatusFilter == WaybillService.deliveredStatus &&
        widget.serverInvoiceStatusFilter ==
            WaybillService.invoiceNotSentStatus) {
      return stats.readyForInvoice;
    }

    switch (widget.serverInvoiceStatusFilter) {
      case WaybillService.invoiceSentStatus:
        return stats.sentForInvoicing;
      case WaybillService.invoiceRejectedStatus:
        return stats.rejected;
    }

    switch (widget.serverStatusFilter) {
      case WaybillService.invoicedStatus:
        return stats.invoiced;
      case WaybillService.deliveredStatus:
        return stats.delivered;
      case WaybillService.pendingDeliveryStatus:
        return stats.pendingDelivery;
      default:
        return stats.total;
    }
  }

  DateTime _readyForInvoiceSortDate(WaybillModel waybill) {
    return DateTime.tryParse(waybill.deliveredAt) ??
        DateTime.tryParse(waybill.updatedAt) ??
        DateTime.tryParse(waybill.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<bool> _loadReadyForInvoicePage(int pageIndex) async {
    final readyWaybills =
        _readyForInvoiceServerCache ??
        (await FirestoreWaybillService.getWaybillsByStatus(
              WaybillService.deliveredStatus,
            ))
            .where(
              (waybill) =>
                  waybill.status == WaybillService.deliveredStatus &&
                  waybill.invoiceStatus == WaybillService.invoiceNotSentStatus,
            )
            .toList();

    readyWaybills.sort(
      (a, b) =>
          _readyForInvoiceSortDate(b).compareTo(_readyForInvoiceSortDate(a)),
    );
    _readyForInvoiceServerCache = readyWaybills;

    final start = pageIndex * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, readyWaybills.length);

    allWaybills = start >= readyWaybills.length
        ? const []
        : readyWaybills.sublist(start, end);
    _hasNextPage = end < readyWaybills.length;
    _loadedPageCache[pageIndex] = allWaybills;
    _pageHasMoreCache[pageIndex] = _hasNextPage;
    _usingLocalCache = false;
    _localTotalItems = 0;

    if (_serverTotalWaybills == null) {
      final stats = await FirestoreWaybillService.getWaybillStats();
      _summaryStats = stats;
      _serverTotalWaybills = _totalFromStats(stats) ?? readyWaybills.length;
    }

    return true;
  }

  Future<void> loadWaybillPage({int pageIndex = 0}) async {
    if (!_usesServerPagination) return;

    final cachedPage = _loadedPageCache[pageIndex];
    if (cachedPage != null) {
      allWaybills = cachedPage;
      _hasNextPage = _pageHasMoreCache[pageIndex] ?? false;
      _usingLocalCache = false;

      if (!mounted) return;

      setState(() {
        _currentPage = pageIndex;
        _isLoadingPage = false;
      });
      filterWaybills(searchController.text);
      return;
    }

    setState(() => _isLoadingPage = true);

    try {
      if (_isReadyForInvoiceFilter) {
        await _loadReadyForInvoicePage(pageIndex);
      } else {
        final page =
            widget.serverStatusFilter != null &&
                widget.serverInvoiceStatusFilter != null
            ? await FirestoreWaybillService.getWaybillsByStatusAndInvoiceStatusPage(
                widget.serverStatusFilter!,
                widget.serverInvoiceStatusFilter!,
                limit: _itemsPerPage,
                startAfterDocument: _pageCursors[pageIndex],
              )
            : widget.serverStatusFilter != null
            ? await FirestoreWaybillService.getWaybillsByStatusPage(
                widget.serverStatusFilter!,
                limit: _itemsPerPage,
                startAfterDocument: _pageCursors[pageIndex],
              )
            : widget.serverInvoiceStatusFilter != null
            ? await FirestoreWaybillService.getWaybillsByInvoiceStatusPage(
                widget.serverInvoiceStatusFilter!,
                limit: _itemsPerPage,
                startAfterDocument: _pageCursors[pageIndex],
              )
            : await FirestoreWaybillService.getAllWaybillsPage(
                limit: _itemsPerPage,
                startAfterDocument: _pageCursors[pageIndex],
              );
        if (page.hasMore && _pageCursors.length == pageIndex + 1) {
          _pageCursors.add(page.lastDocument);
        }

        allWaybills = _filterServerPageWaybills(page.waybills);
        _hasNextPage = page.hasMore;
        _loadedPageCache[pageIndex] = allWaybills;
        _pageHasMoreCache[pageIndex] = page.hasMore;
        _usingLocalCache = false;
        _localTotalItems = 0;
        if (_serverTotalWaybills == null) {
          final stats = await FirestoreWaybillService.getWaybillStats();
          _summaryStats = stats;
          _serverTotalWaybills = _totalFromStats(stats);
        }
      }
    } catch (error) {
      debugPrint('Accounts waybill page load failed: $error');
      _loadLocalPage(pageIndex);
    }

    if (!mounted) return;

    setState(() {
      _currentPage = pageIndex;
      _isLoadingPage = false;
    });
    filterWaybills(searchController.text);
  }

  List<WaybillModel> _filterServerPageWaybills(List<WaybillModel> waybills) {
    if (_isReadyForInvoiceFilter) {
      return waybills
          .where(
            (waybill) =>
                waybill.status == WaybillService.deliveredStatus &&
                waybill.invoiceStatus == WaybillService.invoiceNotSentStatus,
          )
          .toList();
    }

    return waybills;
  }

  void _loadLocalPage(int pageIndex) {
    var cachedWaybills = WaybillService.getAllWaybills();

    if (widget.serverStatusFilter != null) {
      cachedWaybills = cachedWaybills
          .where((waybill) => waybill.status == widget.serverStatusFilter)
          .toList();
    }

    if (widget.serverInvoiceStatusFilter != null) {
      cachedWaybills = cachedWaybills
          .where(
            (waybill) =>
                waybill.invoiceStatus == widget.serverInvoiceStatusFilter,
          )
          .toList();
    }

    final start = pageIndex * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, cachedWaybills.length);

    allWaybills = start >= cachedWaybills.length
        ? const []
        : cachedWaybills.sublist(start, end);
    _hasNextPage = end < cachedWaybills.length;
    _loadedPageCache[pageIndex] = allWaybills;
    _pageHasMoreCache[pageIndex] = _hasNextPage;
    _usingLocalCache = true;
    _localTotalItems = cachedWaybills.length;
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
      case 'Accepted':
        return Colors.blue;
      case 'Sent for Invoicing':
        return Colors.indigo;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _displayStatus(WaybillModel waybill) {
    if (waybill.invoiceStatus == WaybillService.invoiceAcceptedStatus) {
      return WaybillService.invoicedStatus;
    }
    if (waybill.invoiceStatus != WaybillService.invoiceNotSentStatus) {
      return waybill.invoiceStatus;
    }
    return waybill.status;
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
        builder: (_) => WaybillDetailsScreen(waybill: waybill, index: index),
      ),
    );
  }

  Future<void> downloadWaybillPdf(WaybillModel waybill) async {
    if (_downloadingPdfWaybillNumbers.contains(waybill.waybillNumber)) return;

    setState(() {
      _downloadingPdfWaybillNumbers.add(waybill.waybillNumber);
    });

    try {
      final pdfBytes = await PdfService.generateWaybillPdf(
        waybill,
        receiverSignatureBytes: waybill.receiverSignatureBytes,
        driverSignatureBytes: waybill.driverSignatureBytes,
      );

      await Printing.layoutPdf(
        name: 'Waybill_${waybill.waybillNumber}.pdf',
        onLayout: (_) async => pdfBytes,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not prepare the PDF. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingPdfWaybillNumbers.remove(waybill.waybillNumber);
        });
      }
    }
  }

  Future<bool> _saveInvoiceUpdate(WaybillModel updatedWaybill) async {
    await WaybillService.updateWaybillByNumber(updatedWaybill);

    if (shouldUseFirestoreData) {
      try {
        await FirestoreWaybillService.updateWaybill(updatedWaybill);
      } catch (error) {
        debugPrint('ACCOUNT INVOICE UPDATE ERROR: $error');
        if (!mounted) return false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invoice update saved locally but could not sync: $error',
            ),
          ),
        );
        return false;
      }
    }

    if (!mounted) return true;

    setState(() {
      allWaybills.removeWhere(
        (item) => item.waybillNumber == updatedWaybill.waybillNumber,
      );

      filteredWaybills.removeWhere(
        (item) => item.waybillNumber == updatedWaybill.waybillNumber,
      );

      if (_currentPage >= totalPages) {
        _currentPage = totalPages - 1;
      }
    });

    return true;
  }

  Future<String> _invoiceUpdatedBy() async {
    final profile = await FirebaseAuthService.getCurrentUserProfile();
    return profile?.email ??
        FirebaseAuthService.currentFirebaseUser?.email ??
        '';
  }

  Future<void> markAsSentForInvoicing(WaybillModel waybill) async {
    final now = DateTime.now().toIso8601String();
    final updatedWaybill = waybill.copyWith(
      invoiceStatus: WaybillService.invoiceSentStatus,
      sentForInvoicingAt: now,
      invoiceRejectedAt: '',
      invoiceRejectionReason: '',
      invoiceUpdatedBy: await _invoiceUpdatedBy(),
      updatedAt: now,
    );

    final saved = await _saveInvoiceUpdate(updatedWaybill);

    if (!saved || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Waybill marked as sent for invoicing')),
    );
  }

  Future<void> markAsInvoiced(WaybillModel waybill) async {
    final now = DateTime.now().toIso8601String();
    final updatedWaybill = waybill.copyWith(
      status: WaybillService.invoicedStatus,
      invoiceStatus: WaybillService.invoiceAcceptedStatus,
      invoicedAt: now,
      invoiceRejectedAt: '',
      invoiceRejectionReason: '',
      invoiceUpdatedBy: await _invoiceUpdatedBy(),
      updatedAt: now,
    );

    final saved = await _saveInvoiceUpdate(updatedWaybill);

    if (!saved || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Waybill marked as invoiced')));
  }

  Future<void> rejectInvoice(WaybillModel waybill, String reason) async {
    final now = DateTime.now().toIso8601String();
    final updatedWaybill = waybill.copyWith(
      invoiceStatus: WaybillService.invoiceRejectedStatus,
      invoiceRejectedAt: now,
      invoiceRejectionReason: reason.trim(),
      invoiceUpdatedBy: await _invoiceUpdatedBy(),
      updatedAt: now,
    );

    final saved = await _saveInvoiceUpdate(updatedWaybill);

    if (!saved || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Waybill marked as rejected')));
  }

  void confirmMarkAsSentForInvoicing(WaybillModel waybill) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Mark as Sent for Invoicing'),
          content: Text(
            'Mark Waybill No. ${waybill.waybillNumber} as sent for invoicing?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                markAsSentForInvoicing(waybill);
              },
              icon: const Icon(Icons.send),
              label: const Text('Mark Sent'),
            ),
          ],
        );
      },
    );
  }

  void confirmMarkAsInvoiced(WaybillModel waybill) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Mark as Invoiced'),
          content: Text(
            'Has the client accepted Waybill No. ${waybill.waybillNumber}? This will mark it as invoiced.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                markAsInvoiced(waybill);
              },
              icon: const Icon(Icons.check),
              label: const Text('Mark Invoiced'),
            ),
          ],
        );
      },
    );
  }

  void confirmRejectInvoice(WaybillModel waybill) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Invoice'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection reason',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Please enter the rejection reason';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final reason = reasonController.text;
                Navigator.pop(dialogContext);
                rejectInvoice(waybill, reason);
              },
              icon: const Icon(Icons.report_problem),
              label: const Text('Reject'),
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
        : widget.showFullSummary
        ? Icons.visibility
        : Icons.done_all;
    final stats = _summaryStats;
    final pendingCount =
        stats?.pendingDelivery ??
        filteredWaybills
            .where(
              (waybill) =>
                  waybill.status == WaybillService.pendingDeliveryStatus,
            )
            .length;
    final deliveredCount =
        stats?.delivered ??
        filteredWaybills
            .where(
              (waybill) => waybill.status == WaybillService.deliveredStatus,
            )
            .length;
    final totalWaybillCount =
        stats?.total ?? (_serverTotalWaybills ?? filteredWaybills.length);
    final readyCount =
        _serverTotalWaybills ??
        widget.readyCount ??
        allWaybills
            .where(
              (waybill) =>
                  waybill.status == WaybillService.deliveredStatus &&
                  waybill.invoiceStatus == WaybillService.invoiceNotSentStatus,
            )
            .length;
    final invoicedCount =
        stats?.invoiced ??
        filteredWaybills
            .where((waybill) => waybill.status == WaybillService.invoicedStatus)
            .length;
    final rejectedCount =
        stats?.rejected ??
        filteredWaybills
            .where(
              (waybill) =>
                  waybill.invoiceStatus == WaybillService.invoiceRejectedStatus,
            )
            .length;
    final displayInvoicedCount = widget.showFullSummary
        ? invoicedCount
        : widget.invoicedCount ?? invoicedCount;
    final secondarySummaryLabel = widget.invoiceActionMode == 'sentReview'
        ? 'Sent'
        : widget.showMarkInvoicedButton
        ? 'Ready'
        : 'Invoiced';
    final secondarySummaryValue = widget.invoiceActionMode == 'sentReview'
        ? stats?.sentForInvoicing ?? filteredWaybills.length
        : widget.showMarkInvoicedButton
        ? readyCount
        : displayInvoicedCount;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
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
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(14),
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
                                : widget.showFullSummary
                                ? 'Summary of all waybills in the system.'
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
                    children: widget.showFullSummary
                        ? [
                            _AccountsSummaryPill(
                              label: 'Total',
                              value: totalWaybillCount.toString(),
                              color: Colors.blue,
                              icon: Icons.list_alt,
                            ),
                            _AccountsSummaryPill(
                              label: 'Pending',
                              value: pendingCount.toString(),
                              color: Colors.orange,
                              icon: Icons.schedule,
                            ),
                            _AccountsSummaryPill(
                              label: 'Delivered',
                              value: deliveredCount.toString(),
                              color: Colors.green,
                              icon: Icons.check_circle,
                            ),
                            _AccountsSummaryPill(
                              label: 'Invoiced',
                              value: displayInvoicedCount.toString(),
                              color: Colors.blue,
                              icon: Icons.receipt_long,
                            ),
                            _AccountsSummaryPill(
                              label: 'Rejected',
                              value: rejectedCount.toString(),
                              color: Colors.red,
                              icon: Icons.warning_amber_rounded,
                            ),
                          ]
                        : [
                            _AccountsSummaryPill(
                              label: 'Showing',
                              value: visibleWaybills.length.toString(),
                              color: pageColor,
                              icon: Icons.filter_list,
                            ),
                            if (widget.invoiceActionMode != 'rejected')
                              _AccountsSummaryPill(
                                label: secondarySummaryLabel,
                                value: secondarySummaryValue.toString(),
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
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: pageColor, width: 1.5),
                  ),
                ),
                onChanged: filterWaybills,
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: _isLoadingPage && filteredWaybills.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Loading waybills...'),
                        ],
                      ),
                    )
                  : filteredWaybills.isEmpty
                  ? _buildEmptyState(pageColor)
                  : Column(
                      children: [
                        Expanded(
                          child: isWideScreen
                              ? _buildTableView()
                              : _buildListView(),
                        ),
                        if (shouldPaginate) ...[
                          const SizedBox(height: 12),
                          _buildPaginationControls(),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    final pageWaybills = visibleWaybills;

    return ListView.builder(
      itemCount: pageWaybills.length,
      itemBuilder: (context, index) {
        final waybill = pageWaybills[index];

        final originalIndex = WaybillService.getIndexByWaybillNumber(
          waybill.waybillNumber,
        );

        final displayStatus = _displayStatus(waybill);
        final statusColor = getStatusColor(displayStatus);

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
                        const SizedBox(height: 3),
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
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _AccountsStatusChip(
                          status: displayStatus,
                          color: statusColor,
                        ),
                        if (waybill.invoiceRejectionReason
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Reason: ${waybill.invoiceRejectionReason}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                      IconButton(
                        tooltip: 'Download PDF',
                        icon:
                            _downloadingPdfWaybillNumbers.contains(
                              waybill.waybillNumber,
                            )
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download, color: Colors.blue),
                        onPressed:
                            _downloadingPdfWaybillNumbers.contains(
                              waybill.waybillNumber,
                            )
                            ? null
                            : () => downloadWaybillPdf(waybill),
                      ),
                      ..._buildInvoiceIconActions(waybill),
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

  List<Widget> _buildInvoiceIconActions(WaybillModel waybill) {
    if (widget.invoiceActionMode == 'markSent' &&
        waybill.status == WaybillService.deliveredStatus &&
        waybill.invoiceStatus == WaybillService.invoiceNotSentStatus) {
      return [
        IconButton(
          icon: const Icon(Icons.send, color: Colors.indigo),
          tooltip: 'Mark Sent for Invoicing',
          onPressed: () => confirmMarkAsSentForInvoicing(waybill),
        ),
      ];
    }

    if (widget.invoiceActionMode == 'sentReview' &&
        waybill.invoiceStatus == WaybillService.invoiceSentStatus) {
      return [
        IconButton(
          icon: const Icon(Icons.done_all, color: Colors.blue),
          tooltip: 'Mark Invoiced',
          onPressed: () => confirmMarkAsInvoiced(waybill),
        ),
        IconButton(
          icon: const Icon(Icons.report_problem, color: Colors.red),
          tooltip: 'Reject',
          onPressed: () => confirmRejectInvoice(waybill),
        ),
      ];
    }

    return [];
  }

  List<Widget> _buildInvoiceTableActions(WaybillModel waybill) {
    if (widget.invoiceActionMode == 'markSent' &&
        waybill.status == WaybillService.deliveredStatus &&
        waybill.invoiceStatus == WaybillService.invoiceNotSentStatus) {
      return [
        FilledButton.icon(
          onPressed: () => confirmMarkAsSentForInvoicing(waybill),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.send, size: 16),
          label: const Text('Mark Sent'),
        ),
      ];
    }

    if (widget.invoiceActionMode == 'sentReview' &&
        waybill.invoiceStatus == WaybillService.invoiceSentStatus) {
      return [
        FilledButton.icon(
          onPressed: () => confirmMarkAsInvoiced(waybill),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 34),
          ),
          icon: const Icon(Icons.done_all, size: 16),
          label: const Text('Mark Invoiced'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => confirmRejectInvoice(waybill),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 34),
          ),
          icon: const Icon(Icons.report_problem, size: 16),
          label: const Text('Reject'),
        ),
      ];
    }

    return [];
  }

  Widget _buildTableView() {
    final usesReviewLayout =
        widget.invoiceActionMode == 'sentReview' ||
        widget.invoiceActionMode == 'rejected';
    final actionColumnWidth = usesReviewLayout
        ? 260.0
        : widget.showMarkInvoicedButton
        ? 430.0
        : 250.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: usesReviewLayout
                    ? 1230
                    : widget.showMarkInvoicedButton
                    ? 1330
                    : 1180,
              ),
              child: DataTable(
                columnSpacing: 24,
                horizontalMargin: 18,
                dataRowMinHeight: usesReviewLayout ? 86 : 58,
                dataRowMaxHeight: usesReviewLayout ? 96 : 68,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFEAF3FF),
                ),
                columns: [
                  const DataColumn(label: Text('Waybill No.')),
                  const DataColumn(label: Text('BAJ No.')),
                  const DataColumn(label: Text('Date')),
                  const DataColumn(label: Text('Shipping/Vendor')),
                  const DataColumn(label: Text('Delivered At')),
                  DataColumn(
                    label: usesReviewLayout
                        ? const SizedBox(width: 150, child: Text('Status'))
                        : const Text('Status'),
                  ),
                  DataColumn(
                    label: SizedBox(
                      width: actionColumnWidth,
                      child: const Center(child: Text('Actions')),
                    ),
                  ),
                ],
                rows: visibleWaybills.map((waybill) {
                  final originalIndex = WaybillService.getIndexByWaybillNumber(
                    waybill.waybillNumber,
                  );
                  final displayStatus = _displayStatus(waybill);
                  final statusColor = getStatusColor(displayStatus);
                  final isDownloading = _downloadingPdfWaybillNumbers.contains(
                    waybill.waybillNumber,
                  );

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
                        usesReviewLayout
                            ? SizedBox(
                                width: 150,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _AccountsStatusChip(
                                      status: displayStatus,
                                      color: statusColor,
                                    ),
                                    if (waybill.invoiceRejectionReason
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 170,
                                        child: Text(
                                          'Reason: ${waybill.invoiceRejectionReason}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : _AccountsStatusChip(
                                status: displayStatus,
                                color: statusColor,
                              ),
                      ),
                      DataCell(
                        SizedBox(
                          width: actionColumnWidth,
                          child: Center(
                            child: usesReviewLayout
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FilledButton.tonalIcon(
                                            onPressed: () => openWaybillDetails(
                                              originalIndex,
                                              waybill,
                                            ),
                                            icon: const Icon(
                                              Icons.visibility,
                                              size: 15,
                                            ),
                                            label: const Text('View'),
                                          ),
                                          const SizedBox(width: 8),
                                          FilledButton.tonalIcon(
                                            onPressed: isDownloading
                                                ? null
                                                : () => downloadWaybillPdf(
                                                    waybill,
                                                  ),
                                            icon: isDownloading
                                                ? const SizedBox(
                                                    width: 15,
                                                    height: 15,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.download,
                                                    size: 15,
                                                  ),
                                            label: Text(
                                              isDownloading
                                                  ? 'Preparing'
                                                  : 'Download',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: _buildInvoiceTableActions(
                                          waybill,
                                        ),
                                      ),
                                    ],
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () => openWaybillDetails(
                                          originalIndex,
                                          waybill,
                                        ),
                                        icon: const Icon(
                                          Icons.visibility,
                                          size: 16,
                                        ),
                                        label: const Text('View'),
                                      ),
                                      FilledButton.tonalIcon(
                                        onPressed: isDownloading
                                            ? null
                                            : () => downloadWaybillPdf(waybill),
                                        icon: isDownloading
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.download,
                                                size: 16,
                                              ),
                                        label: Text(
                                          isDownloading
                                              ? 'Preparing'
                                              : 'Download',
                                        ),
                                      ),
                                      ..._buildInvoiceTableActions(waybill),
                                    ],
                                  ),
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

  Widget _buildPaginationControls() {
    final start = (_currentPage * _itemsPerPage) + 1;
    final end = _usesServerPagination
        ? start + visibleWaybills.length - 1
        : ((_currentPage * _itemsPerPage) + visibleWaybills.length).clamp(
            0,
            filteredWaybills.length,
          );
    final showingText = _usesServerPagination
        ? _usingLocalCache && _localTotalItems > 0
              ? 'Showing $start-$end of $_localTotalItems cached'
              : _serverTotalWaybills != null
              ? 'Showing $start-$end of $_serverTotalWaybills'
              : 'Showing $start-$end'
        : 'Showing $start-$end of ${filteredWaybills.length}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE8F6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isLoadingPage ? 'Loading waybills...' : showingText,
              style: const TextStyle(
                color: Color(0xFF5B718C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Previous page',
            onPressed: _currentPage == 0 || _isLoadingPage
                ? null
                : _usesServerPagination
                ? () => loadWaybillPage(pageIndex: _currentPage - 1)
                : () => setState(() => _currentPage--),
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          Text(
            _usesServerPagination
                ? 'Page ${_currentPage + 1}'
                : 'Page ${_currentPage + 1} of $totalPages',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Next page',
            onPressed:
                _isLoadingPage ||
                    (_usesServerPagination
                        ? !_hasNextPage
                        : _currentPage >= totalPages - 1)
                ? null
                : _usesServerPagination
                ? () => loadWaybillPage(pageIndex: _currentPage + 1)
                : () => setState(() => _currentPage++),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
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
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 128),
        child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.24)),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF172033),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE8F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF4F9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172033),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.arrow_forward, size: 18, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
