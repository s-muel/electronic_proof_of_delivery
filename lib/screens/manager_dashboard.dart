import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/waybill_model.dart';
import '../models/waybill_stats_model.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_waybill_service.dart';
import '../services/waybill_service.dart';
import '../utils/platform_flags.dart';
import 'login_screen.dart';
import 'waybill_details_screen.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  List<WaybillModel> waybills = [];
  WaybillStatsModel? dashboardStats;
  String managerName = '';
  String? openingCardKey;

  int get _totalCount => dashboardStats?.total ?? waybills.length;

  int get _pendingCount =>
      dashboardStats?.pendingDelivery ?? _pendingWaybills.length;

  int get _deliveredCount =>
      dashboardStats?.delivered ?? _deliveredWaybills.length;

  int get _sentForInvoicingCount =>
      dashboardStats?.sentForInvoicing ?? _sentForInvoicingWaybills.length;

  int get _invoicedCount =>
      dashboardStats?.invoiced ?? _invoicedWaybills.length;

  int get _rejectedCount => dashboardStats?.rejected ?? _issueWaybills.length;

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
        dashboardStats = await FirestoreWaybillService.getWaybillStats();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load manager data: $error')),
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
    String? serverStatusFilter,
    String? serverInvoiceStatusFilter,
    String? serverExceptionFilter,
  }) async {
    if (openingCardKey != null) return;

    setState(() => openingCardKey = cardKey);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManagerWaybillListScreen(
          title: title,
          waybills: selectedWaybills,
          serverExceptionFilter: serverExceptionFilter,
        ),
      ),
    );

    if (!mounted) return;

    setState(() => openingCardKey = null);
  }

  Future<void> _openExceptionWaybillList({
    required String title,
    required List<WaybillModel> selectedWaybills,
    String? serverExceptionFilter,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManagerWaybillListScreen(
          title: title,
          waybills: selectedWaybills,
          serverExceptionFilter: serverExceptionFilter,
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

  List<WaybillModel> get _sentForInvoicingWaybills => waybills
      .where(
        (waybill) => waybill.invoiceStatus == WaybillService.invoiceSentStatus,
      )
      .toList();

  List<WaybillModel> get _issueWaybills => waybills
      .where(
        (waybill) =>
            waybill.invoiceStatus == WaybillService.invoiceRejectedStatus,
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;
    final isTablet = screenWidth >= 600 && !isWideScreen;
    final summaryColumns = isWideScreen ? 6 : (isTablet ? 2 : 1);
    final summaryAspectRatio = isWideScreen ? 2.35 : (isTablet ? 2.65 : 4.1);

    final dashboardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ManagerHero(
          managerName: managerName,
          totalCount: _totalCount,
          deliveredCount: _deliveredCount,
          sentCount: _sentForInvoicingCount,
          issueCount: _rejectedCount,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Company Waybill Overview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172033),
                ),
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
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: summaryAspectRatio,
          children: [
            _MetricCard(
              title: 'Total Waybills',
              value: _totalCount,
              icon: Icons.inventory_2,
              color: Colors.indigo,
              isLoading: openingCardKey == 'total',
              onTap: _openAllWaybills,
            ),
            _MetricCard(
              title: 'Pending',
              value: _pendingCount,
              icon: Icons.pending_actions,
              color: Colors.orange,
              isLoading: openingCardKey == 'pending',
              onTap: _openPendingWaybills,
            ),
            _MetricCard(
              title: 'Delivered',
              value: _deliveredCount,
              icon: Icons.local_shipping,
              color: Colors.blue,
              isLoading: openingCardKey == 'delivered',
              onTap: _openDeliveredWaybills,
            ),
            _MetricCard(
              title: 'Sent for Invoicing',
              value: _sentForInvoicingCount,
              icon: Icons.outbox_rounded,
              color: Colors.deepPurple,
              isLoading: openingCardKey == 'sent',
              onTap: _openSentForInvoicingWaybills,
            ),
            _MetricCard(
              title: 'Invoiced',
              value: _invoicedCount,
              icon: Icons.done_all,
              color: Colors.green,
              isLoading: openingCardKey == 'invoiced',
              onTap: _openInvoicedWaybills,
            ),
            _MetricCard(
              title: 'Rejected',
              value: _rejectedCount,
              icon: Icons.report_problem,
              color: Colors.red,
              isLoading: openingCardKey == 'issues',
              onTap: _openRejectedWaybills,
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 950) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ExceptionPanel(
                      waybills: waybills,
                      stats: dashboardStats,
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
                  stats: dashboardStats,
                  onOpenIssue: _openExceptionWaybillList,
                ),
                const SizedBox(height: 16),
                _StatusGraphPanel(waybills: waybills),
              ],
            );
          },
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Row(
        children: [
          if (isWideScreen) _buildSidebar(context),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isWideScreen ? 22 : 14,
                  16,
                  isWideScreen ? 22 : 14,
                  16,
                ),
                child: SingleChildScrollView(child: dashboardContent),
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
                      Icons.manage_accounts,
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
                          'Manager Desk',
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
                icon: Icons.inventory_2,
                label: 'All Waybills',
                onTap: _openAllWaybills,
              ),
              _SidebarItem(
                icon: Icons.pending_actions,
                label: 'Pending',
                onTap: _openPendingWaybills,
              ),
              _SidebarItem(
                icon: Icons.local_shipping,
                label: 'Delivered',
                onTap: _openDeliveredWaybills,
              ),
              _SidebarItem(
                icon: Icons.done_all,
                label: 'Invoiced',
                onTap: _openInvoicedWaybills,
              ),
              _SidebarItem(
                icon: Icons.outbox_rounded,
                label: 'Sent for Invoicing',
                onTap: _openSentForInvoicingWaybills,
              ),
              _SidebarItem(
                icon: Icons.report_problem,
                label: 'Rejected',
                onTap: _openRejectedWaybills,
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
                      managerName.trim().isEmpty ? 'Manager User' : managerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _logout,
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

  void _openAllWaybills() {
    _openWaybillList(
      title: 'All Waybills',
      selectedWaybills: waybills,
      cardKey: 'total',
    );
  }

  void _openPendingWaybills() {
    _openWaybillList(
      title: 'Pending Deliveries',
      selectedWaybills: _pendingWaybills,
      cardKey: 'pending',
      serverStatusFilter: WaybillService.pendingDeliveryStatus,
    );
  }

  void _openDeliveredWaybills() {
    _openWaybillList(
      title: 'Delivered Waybills',
      selectedWaybills: _deliveredWaybills,
      cardKey: 'delivered',
      serverStatusFilter: WaybillService.deliveredStatus,
    );
  }

  void _openInvoicedWaybills() {
    _openWaybillList(
      title: 'Invoiced Waybills',
      selectedWaybills: _invoicedWaybills,
      cardKey: 'invoiced',
      serverStatusFilter: WaybillService.invoicedStatus,
    );
  }

  void _openSentForInvoicingWaybills() {
    _openWaybillList(
      title: 'Sent for Invoicing',
      selectedWaybills: _sentForInvoicingWaybills,
      cardKey: 'sent',
      serverInvoiceStatusFilter: WaybillService.invoiceSentStatus,
    );
  }

  void _openRejectedWaybills() {
    _openWaybillList(
      title: 'Rejected Waybills',
      selectedWaybills: _issueWaybills,
      cardKey: 'issues',
      serverInvoiceStatusFilter: WaybillService.invoiceRejectedStatus,
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

class ManagerWaybillListScreen extends StatefulWidget {
  final String title;
  final List<WaybillModel> waybills;
  final String? serverStatusFilter;
  final String? serverInvoiceStatusFilter;
  final String? serverExceptionFilter;

  const ManagerWaybillListScreen({
    super.key,
    required this.title,
    required this.waybills,
    this.serverStatusFilter,
    this.serverInvoiceStatusFilter,
    this.serverExceptionFilter,
  });

  @override
  State<ManagerWaybillListScreen> createState() =>
      _ManagerWaybillListScreenState();
}

class _ManagerWaybillListScreenState extends State<ManagerWaybillListScreen> {
  static const int _itemsPerPage = 25;
  late List<WaybillModel> filteredWaybills;
  late List<WaybillModel> currentPageWaybills;
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

  bool get isAllWaybillList => widget.title.toLowerCase().contains('all');

  bool get usesServerPagination =>
      isAllWaybillList ||
      widget.serverStatusFilter != null ||
      widget.serverInvoiceStatusFilter != null ||
      widget.serverExceptionFilter != null;

  bool get shouldPaginate => usesServerPagination
      ? _currentPage > 0 || _hasNextPage
      : filteredWaybills.length > _itemsPerPage;

  int get totalPages => filteredWaybills.isEmpty
      ? 1
      : ((filteredWaybills.length - 1) ~/ _itemsPerPage) + 1;

  List<WaybillModel> get visibleWaybills {
    if (usesServerPagination) return filteredWaybills;

    final start = _currentPage * _itemsPerPage;
    if (start >= filteredWaybills.length) return const [];

    final end = (start + _itemsPerPage).clamp(0, filteredWaybills.length);
    return filteredWaybills.sublist(start, end);
  }

  String get _showingSummary {
    if (filteredWaybills.isEmpty) return '0 waybills showing';
    if (!usesServerPagination) {
      return '${filteredWaybills.length} waybills showing';
    }

    final start = (_currentPage * _itemsPerPage) + 1;
    final rawEnd = start + visibleWaybills.length - 1;
    final totalCount = _usingLocalCache && _localTotalItems > 0
        ? _localTotalItems
        : _serverTotalWaybills;
    final end = totalCount == null ? rawEnd : rawEnd.clamp(0, totalCount);
    if (_usingLocalCache && _localTotalItems > 0) {
      return 'Showing $start-$end of $_localTotalItems cached waybills';
    }
    if (_serverTotalWaybills != null) {
      return 'Showing $start-$end of $_serverTotalWaybills waybills';
    }
    return 'Showing $start-$end waybills';
  }

  bool get isRejectedWaybillList =>
      widget.title.toLowerCase().contains('rejected');

  String _rejectionReasonFor(WaybillModel waybill) {
    final reason = waybill.invoiceRejectionReason.trim();
    return reason.isEmpty ? 'No rejection reason recorded' : reason;
  }

  String _displayStatusFor(WaybillModel waybill) {
    if (widget.serverInvoiceStatusFilter == WaybillService.invoiceSentStatus) {
      return WaybillService.invoiceSentStatus;
    }
    if (widget.serverInvoiceStatusFilter ==
        WaybillService.invoiceRejectedStatus) {
      return WaybillService.invoiceRejectedStatus;
    }
    if (waybill.invoiceStatus == WaybillService.invoiceRejectedStatus) {
      return WaybillService.invoiceRejectedStatus;
    }
    return waybill.status;
  }

  @override
  void initState() {
    super.initState();
    filteredWaybills = widget.waybills;
    currentPageWaybills = widget.waybills;
    if (usesServerPagination) {
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
      if (!usesServerPagination) _currentPage = 0;

      final sourceWaybills = usesServerPagination
          ? currentPageWaybills
          : widget.waybills;

      if (searchText.isEmpty) {
        filteredWaybills = sourceWaybills;
      } else {
        filteredWaybills = sourceWaybills.where((waybill) {
          return waybill.waybillNumber.toLowerCase().contains(searchText) ||
              waybill.bajNumber.toLowerCase().contains(searchText) ||
              waybill.shippingVendor.toLowerCase().contains(searchText) ||
              waybill.consigneeReceiver.toLowerCase().contains(searchText) ||
              waybill.invoiceRejectionReason.toLowerCase().contains(
                searchText,
              ) ||
              waybill.status.toLowerCase().contains(searchText);
        }).toList();
      }
    });
  }

  int? _totalFromStats(WaybillStatsModel? stats) {
    if (stats == null) return null;

    if (widget.serverStatusFilter == WaybillService.pendingDeliveryStatus) {
      return stats.pendingDelivery;
    }
    if (widget.serverStatusFilter == WaybillService.deliveredStatus) {
      return stats.delivered;
    }
    if (widget.serverStatusFilter == WaybillService.invoicedStatus) {
      return stats.invoiced;
    }
    if (widget.serverInvoiceStatusFilter == WaybillService.invoiceSentStatus) {
      return stats.sentForInvoicing;
    }
    if (widget.serverInvoiceStatusFilter ==
        WaybillService.invoiceRejectedStatus) {
      return stats.rejected;
    }
    switch (widget.serverExceptionFilter) {
      case 'short':
        return stats.short;
      case 'over':
        return stats.over;
      case 'damaged':
        return stats.damaged;
      case 'parkingUnsuitable':
        return stats.parkingUnsuitable;
      case 'partOrder':
        return stats.partOrder;
    }

    return stats.total;
  }

  List<WaybillModel> _cachedFallbackWaybills() {
    final cachedWaybills = WaybillService.getAllWaybills();
    final statusFilter = widget.serverStatusFilter;
    final invoiceStatusFilter = widget.serverInvoiceStatusFilter;
    final exceptionFilter = widget.serverExceptionFilter;

    if (statusFilter != null) {
      return cachedWaybills
          .where((waybill) => waybill.status == statusFilter)
          .toList();
    }
    if (invoiceStatusFilter != null) {
      return cachedWaybills
          .where((waybill) => waybill.invoiceStatus == invoiceStatusFilter)
          .toList();
    }
    if (exceptionFilter != null) {
      return cachedWaybills
          .where((waybill) => _matchesExceptionFilter(waybill, exceptionFilter))
          .toList();
    }

    return cachedWaybills;
  }

  bool _matchesExceptionFilter(WaybillModel waybill, String exceptionFilter) {
    switch (exceptionFilter) {
      case 'short':
        return waybill.isShort;
      case 'over':
        return waybill.isOver;
      case 'damaged':
        return waybill.isDamaged;
      case 'parkingUnsuitable':
        return waybill.isParkingUnsuitable;
      case 'partOrder':
        return waybill.isPartOrder;
      default:
        return false;
    }
  }

  Future<void> loadWaybillPage({int pageIndex = 0}) async {
    if (!usesServerPagination) return;

    final cachedPage = _loadedPageCache[pageIndex];
    if (cachedPage != null) {
      currentPageWaybills = cachedPage;
      filteredWaybills = cachedPage;
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
      final page = widget.serverStatusFilter != null
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
          : widget.serverExceptionFilter != null
          ? await FirestoreWaybillService.getWaybillsByExceptionPage(
              widget.serverExceptionFilter!,
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

      currentPageWaybills = page.waybills;
      filteredWaybills = page.waybills;
      _hasNextPage = page.hasMore;
      _loadedPageCache[pageIndex] = page.waybills;
      _pageHasMoreCache[pageIndex] = page.hasMore;
      _usingLocalCache = false;
      _localTotalItems = 0;
      if (_serverTotalWaybills == null) {
        final stats = await FirestoreWaybillService.getWaybillStats();
        _serverTotalWaybills = _totalFromStats(stats);
      }
    } catch (_) {
      _loadLocalPage(pageIndex);
    }

    if (!mounted) return;

    setState(() {
      _currentPage = pageIndex;
      _isLoadingPage = false;
    });
    filterWaybills(searchController.text);
  }

  void _loadLocalPage(int pageIndex) {
    final cachedWaybills = _cachedFallbackWaybills();
    final start = pageIndex * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, cachedWaybills.length);

    currentPageWaybills = start >= cachedWaybills.length
        ? const []
        : cachedWaybills.sublist(start, end);
    filteredWaybills = currentPageWaybills;
    _hasNextPage = end < cachedWaybills.length;
    _loadedPageCache[pageIndex] = filteredWaybills;
    _pageHasMoreCache[pageIndex] = _hasNextPage;
    _usingLocalCache = true;
    _localTotalItems = cachedWaybills.length;
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
        padding: const EdgeInsets.all(13),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
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
                          _showingSummary,
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
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
                ),
              ),
              onChanged: filterWaybills,
            ),
            const SizedBox(height: 16),
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
                  ? const Center(child: Text('No waybills found.'))
                  : Column(
                      children: [
                        Expanded(
                          child: isWideScreen
                              ? _buildTableView()
                              : _buildCardList(),
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

  Widget _buildCardList() {
    final pageWaybills = visibleWaybills;

    return ListView.builder(
      itemCount: pageWaybills.length,
      itemBuilder: (context, index) {
        final waybill = pageWaybills[index];

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
              'BAJ: ${waybill.bajNumber}\nClient: ${waybill.consigneeReceiver}\nStatus: ${_displayStatusFor(waybill)}',
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
              constraints: BoxConstraints(
                minWidth: isRejectedWaybillList ? 1320 : 1080,
              ),
              child: DataTable(
                columnSpacing: 24,
                horizontalMargin: 18,
                dataRowMinHeight: isRejectedWaybillList ? 70 : 58,
                dataRowMaxHeight: isRejectedWaybillList ? 92 : 68,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFEAF3FF),
                ),
                columns: [
                  const DataColumn(label: Text('Waybill No.')),
                  const DataColumn(label: Text('BAJ No.')),
                  const DataColumn(label: Text('Date')),
                  const DataColumn(label: Text('Client/Receiver')),
                  const DataColumn(label: Text('Driver')),
                  const DataColumn(label: Text('Status')),
                  if (isRejectedWaybillList)
                    const DataColumn(label: Text('Rejection Reason')),
                  const DataColumn(label: Center(child: Text('Actions'))),
                ],
                rows: visibleWaybills.map((waybill) {
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
                      DataCell(_StatusChip(status: _displayStatusFor(waybill))),
                      if (isRejectedWaybillList)
                        DataCell(
                          SizedBox(
                            width: 260,
                            child: Text(
                              _rejectionReasonFor(waybill),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB42318),
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildPaginationControls() {
    final start = (_currentPage * _itemsPerPage) + 1;
    final rawEnd = usesServerPagination
        ? start + visibleWaybills.length - 1
        : ((_currentPage * _itemsPerPage) + visibleWaybills.length).clamp(
            0,
            filteredWaybills.length,
          );
    final totalCount = usesServerPagination
        ? _usingLocalCache && _localTotalItems > 0
              ? _localTotalItems
              : _serverTotalWaybills
        : filteredWaybills.length;
    final end = totalCount == null ? rawEnd : rawEnd.clamp(0, totalCount);
    final showingText = usesServerPagination
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
                : usesServerPagination
                ? () => loadWaybillPage(pageIndex: _currentPage - 1)
                : () => setState(() => _currentPage--),
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          Text(
            usesServerPagination
                ? 'Page ${_currentPage + 1}'
                : 'Page ${_currentPage + 1} of $totalPages',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Next page',
            onPressed:
                _isLoadingPage ||
                    (usesServerPagination
                        ? !_hasNextPage
                        : _currentPage >= totalPages - 1)
                ? null
                : usesServerPagination
                ? () => loadWaybillPage(pageIndex: _currentPage + 1)
                : () => setState(() => _currentPage++),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _ManagerHero extends StatelessWidget {
  final String managerName;
  final int totalCount;
  final int deliveredCount;
  final int sentCount;
  final int issueCount;

  const _ManagerHero({
    required this.managerName,
    required this.totalCount,
    required this.deliveredCount,
    required this.sentCount,
    required this.issueCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD6E4F5)),
                ),
                child: const Icon(
                  Icons.insights,
                  color: Color(0xFF0F5FB8),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manager Control Center',
                    style: TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (managerName.trim().isNotEmpty) ...[
                    Text(
                      'Welcome, $managerName',
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  const Text(
                    'Monitor company deliveries, invoice movement, and exceptions.',
                    style: TextStyle(color: Color(0xFF5B718C)),
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
                label: 'Sent',
                value: sentCount.toString(),
                icon: Icons.outbox_rounded,
              ),
              _HeroPill(
                label: 'Rejected',
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E4F5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF0F5FB8), size: 18),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F5FB8),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF34465C),
              fontWeight: FontWeight.w600,
            ),
          ),
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.toString(),
                      style: TextStyle(
                        color: color,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF172033),
                      ),
                    ),
                  ],
                ),
              ),
              isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
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
  final WaybillStatsModel? stats;
  final Future<void> Function({
    required String title,
    required List<WaybillModel> selectedWaybills,
    String? serverExceptionFilter,
  })
  onOpenIssue;

  const _ExceptionPanel({
    required this.waybills,
    required this.onOpenIssue,
    this.stats,
  });

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
            value: stats?.short ?? shortWaybills.length,
            color: Colors.orange,
            onTap: () => onOpenIssue(
              title: 'Short Waybills',
              selectedWaybills: shortWaybills,
              serverExceptionFilter: 'short',
            ),
          ),
          _ExceptionRow(
            label: 'Over',
            value: stats?.over ?? overWaybills.length,
            color: Colors.blue,
            onTap: () => onOpenIssue(
              title: 'Over Waybills',
              selectedWaybills: overWaybills,
              serverExceptionFilter: 'over',
            ),
          ),
          _ExceptionRow(
            label: 'Damaged',
            value: stats?.damaged ?? damagedWaybills.length,
            color: Colors.red,
            onTap: () => onOpenIssue(
              title: 'Damaged Waybills',
              selectedWaybills: damagedWaybills,
              serverExceptionFilter: 'damaged',
            ),
          ),
          _ExceptionRow(
            label: 'Parking Unsuitable',
            value: stats?.parkingUnsuitable ?? parkingWaybills.length,
            color: Colors.deepPurple,
            onTap: () => onOpenIssue(
              title: 'Parking Unsuitable Waybills',
              selectedWaybills: parkingWaybills,
              serverExceptionFilter: 'parkingUnsuitable',
            ),
          ),
          _ExceptionRow(
            label: 'Part Order',
            value: stats?.partOrder ?? partOrderWaybills.length,
            color: Colors.teal,
            onTap: () => onOpenIssue(
              title: 'Part Order Waybills',
              selectedWaybills: partOrderWaybills,
              serverExceptionFilter: 'partOrder',
            ),
          ),
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
  WaybillStatsModel? graphStats;
  bool isLoadingStats = false;

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

  @override
  void initState() {
    super.initState();
    _loadGraphStats();
  }

  Future<void> _loadGraphStats() async {
    setState(() => isLoadingStats = true);

    try {
      final stats = selectedFilter == 'All'
          ? await FirestoreWaybillService.getWaybillStats()
          : selectedMonth == 0
          ? await FirestoreWaybillService.getYearlyWaybillStats(selectedYear)
          : await FirestoreWaybillService.getMonthlyWaybillStats(
              selectedYear,
              selectedMonth,
            );

      if (!mounted) return;
      setState(() {
        graphStats = stats;
        isLoadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        graphStats = null;
        isLoadingStats = false;
      });
    }
  }

  void _updateGraphFilter(VoidCallback update) {
    setState(update);
    _loadGraphStats();
  }

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
      return !waybillDate.isBefore(start) && waybillDate.isBefore(end);
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
    final stats =
        graphStats ?? WaybillStatsModel.fromWaybills(filteredWaybills);
    final totalCount = stats.total;
    final pendingCount = stats.pendingDelivery;
    final deliveredCount = stats.delivered;
    final invoicedCount = stats.invoiced;
    final issueCount = stats.rejected;
    final maxCount = [
      totalCount,
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
                onSelected: (_) =>
                    _updateGraphFilter(() => selectedFilter = 'All'),
              ),
              ChoiceChip(
                label: const Text('By Month'),
                selected: selectedFilter == 'Month',
                onSelected: (_) =>
                    _updateGraphFilter(() => selectedFilter = 'Month'),
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
                        _updateGraphFilter(() => selectedMonth = value);
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
                        _updateGraphFilter(() => selectedYear = value);
                      }
                    : null,
              ),
            ],
          ),
          if (isLoadingStats) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 3),
          ],
          const SizedBox(height: 14),
          _StatusGraphBar(
            label: 'Total Waybills',
            value: totalCount,
            maxValue: maxCount,
            color: Colors.indigo,
          ),
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
            label: 'Rejected',
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
      padding: const EdgeInsets.only(bottom: 12),
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
              minHeight: 12,
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

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.trim().toLowerCase();
    Color color;

    if (status == WaybillService.deliveredStatus) {
      color = Colors.green;
    } else if (status == WaybillService.invoicedStatus) {
      color = Colors.blue;
    } else if (normalizedStatus == 'sent for invoicing') {
      color = Colors.indigo;
    } else if (normalizedStatus == 'rejected' ||
        status == WaybillService.pendingSyncStatus) {
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
