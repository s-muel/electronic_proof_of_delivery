import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/waybill_model.dart';
import '../models/waybill_stats_model.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_waybill_service.dart';
import '../services/pdf_service.dart';
import '../services/waybill_service.dart';
import '../utils/platform_flags.dart';
import 'driver_delivery_screen.dart';
import 'waybill_details_screen.dart';

class DriverAssignedWaybillsScreen extends StatefulWidget {
  const DriverAssignedWaybillsScreen({super.key});

  @override
  State<DriverAssignedWaybillsScreen> createState() =>
      _DriverAssignedWaybillsScreenState();
}

class _DriverAssignedWaybillsScreenState
    extends State<DriverAssignedWaybillsScreen> {
  static const int _itemsPerPage = 25;

  final searchController = TextEditingController();
  List<WaybillModel> assignedWaybills = [];
  final List<DocumentSnapshot<Map<String, dynamic>>?> _pageCursors = [null];
  final Map<int, List<WaybillModel>> _loadedPageCache = {};
  final Map<int, bool> _pageHasMoreCache = {};
  WaybillStatsModel? assignedStats;
  int _currentPage = 0;
  bool _hasNextPage = false;
  bool _usingServerPagination = false;
  static const String _rejectedFilter = 'Rejected';

  String selectedStatusFilter = 'All';
  bool isLoading = true;
  String? sharingWaybillNumber;

  List<WaybillModel> get filteredWaybills {
    final searchText = searchController.text.trim().toLowerCase();

    return assignedWaybills.where((waybill) {
      final matchesStatus = _matchesSelectedFilter(waybill);
      final matchesSearch =
          searchText.isEmpty ||
          waybill.waybillNumber.toLowerCase().contains(searchText) ||
          waybill.bajNumber.toLowerCase().contains(searchText) ||
          waybill.shippingVendor.toLowerCase().contains(searchText) ||
          waybill.consigneeReceiver.toLowerCase().contains(searchText) ||
          _displayStatus(waybill).toLowerCase().contains(searchText) ||
          waybill.invoiceStatus.toLowerCase().contains(searchText);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadAssignedWaybills();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool _hasInvalidStats(WaybillStatsModel? stats) {
    if (stats == null) return true;

    return stats.total < 0 ||
        stats.pendingDelivery < 0 ||
        stats.delivered < 0 ||
        stats.invoiced < 0 ||
        stats.rejected < 0;
  }

  String? get _serverStatusFilter =>
      selectedStatusFilter == 'All' || selectedStatusFilter == _rejectedFilter
      ? null
      : selectedStatusFilter;

  void _resetPagination() {
    _currentPage = 0;
    _hasNextPage = false;
    _pageCursors
      ..clear()
      ..add(null);
    _loadedPageCache.clear();
    _pageHasMoreCache.clear();
  }

  Future<void> loadAssignedWaybills({
    int pageIndex = 0,
    bool resetPagination = false,
  }) async {
    final driverId = FirebaseAuthService.currentFirebaseUser?.uid ?? '';

    if (resetPagination) _resetPagination();

    final cachedPage = _loadedPageCache[pageIndex];
    if (cachedPage != null && shouldUseFirestoreData) {
      setState(() {
        assignedWaybills = cachedPage;
        _currentPage = pageIndex;
        _hasNextPage = _pageHasMoreCache[pageIndex] ?? false;
        _usingServerPagination = true;
        isLoading = false;
      });
      return;
    }

    setState(() => isLoading = true);

    if (shouldUseFirestoreData) {
      try {
        var stats = await FirestoreWaybillService.getAssignedDriverWaybillStats(
          driverId,
        );
        if (_hasInvalidStats(stats)) {
          stats =
              await FirestoreWaybillService.rebuildAssignedDriverWaybillStats(
                driverId,
              );
        }

        while (_pageCursors.length <= pageIndex) {
          _pageCursors.add(null);
        }

        final page =
            await FirestoreWaybillService.getWaybillsAssignedToDriverPage(
              driverId,
              limit: _itemsPerPage,
              startAfterDocument: _pageCursors[pageIndex],
              statusFilter: _serverStatusFilter,
            );
        await WaybillService.mergeCachedWaybills(page.waybills);

        if (pageIndex == 0 &&
            _serverStatusFilter == null &&
            !page.hasMore &&
            stats != null &&
            stats.total > page.waybills.length) {
          debugPrint(
            'DRIVER ASSIGNED WAYBILLS COUNT MISMATCH: stats=${stats.total}, query=${page.waybills.length}. Rebuilding driver stats.',
          );
          stats =
              await FirestoreWaybillService.rebuildAssignedDriverWaybillStats(
                driverId,
              );
        }
        if (_pageCursors.length <= pageIndex + 1) {
          _pageCursors.add(page.lastDocument);
        } else {
          _pageCursors[pageIndex + 1] = page.lastDocument;
        }

        if (!mounted) return;

        setState(() {
          assignedStats = stats;
          assignedWaybills = page.waybills;
          _loadedPageCache[pageIndex] = page.waybills;
          _pageHasMoreCache[pageIndex] = page.hasMore;
          _currentPage = pageIndex;
          _hasNextPage = page.hasMore;
          _usingServerPagination = true;
          isLoading = false;
        });
        return;
      } catch (error) {
        debugPrint('DRIVER ASSIGNED WAYBILLS PAGE ERROR: $error');

        try {
          var assignedFromFirestore =
              await FirestoreWaybillService.getWaybillsAssignedToDriver(
                driverId,
              );

          if (selectedStatusFilter == _rejectedFilter) {
            assignedFromFirestore = assignedFromFirestore
                .where(_isRejected)
                .toList();
          } else if (_serverStatusFilter != null) {
            assignedFromFirestore = assignedFromFirestore
                .where(
                  (waybill) =>
                      !_isRejected(waybill) &&
                      waybill.status == _serverStatusFilter,
                )
                .toList();
          }

          final start = pageIndex * _itemsPerPage;
          final end = (start + _itemsPerPage).clamp(
            0,
            assignedFromFirestore.length,
          );
          final fallbackPage = start >= assignedFromFirestore.length
              ? <WaybillModel>[]
              : assignedFromFirestore.sublist(start, end);

          await WaybillService.mergeCachedWaybills(fallbackPage);

          if (!mounted) return;

          setState(() {
            assignedStats = WaybillStatsModel.fromWaybills(
              assignedFromFirestore,
            );
            assignedWaybills = fallbackPage;
            _loadedPageCache[pageIndex] = fallbackPage;
            _pageHasMoreCache[pageIndex] = end < assignedFromFirestore.length;
            _currentPage = pageIndex;
            _hasNextPage = end < assignedFromFirestore.length;
            _usingServerPagination = true;
            isLoading = false;
          });
          return;
        } catch (fallbackError) {
          debugPrint(
            'DRIVER ASSIGNED WAYBILLS FIRESTORE FALLBACK ERROR: $fallbackError',
          );
          // The driver can still see locally cached assigned waybills offline.
        }
      }
    }

    if (!mounted) return;

    final localWaybills = WaybillService.getWaybillsAssignedToDriver(driverId)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {
      assignedWaybills = localWaybills;
      assignedStats = WaybillStatsModel.fromWaybills(localWaybills);
      _usingServerPagination = false;
      _hasNextPage = false;
      _currentPage = 0;
      isLoading = false;
    });
  }

  Future<void> openWaybill(WaybillModel waybill) async {
    final index = await WaybillService.ensureCachedIndex(waybill);

    if (!mounted) return;

    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find this waybill record')),
      );
      return;
    }

    final isPendingDelivery =
        waybill.status == WaybillService.pendingDeliveryStatus;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isPendingDelivery
            ? DriverDeliveryScreen(waybill: waybill, index: index)
            : WaybillDetailsScreen(waybill: waybill, index: index),
      ),
    );

    await loadAssignedWaybills();
  }

  Future<void> viewWaybill(WaybillModel waybill) async {
    final index = await WaybillService.ensureCachedIndex(waybill);

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

    await loadAssignedWaybills();
  }

  Future<void> shareWaybillPdf(WaybillModel waybill) async {
    if (sharingWaybillNumber != null) return;

    setState(() => sharingWaybillNumber = waybill.waybillNumber);

    try {
      final pdfBytes = await PdfService.generateWaybillPdf(
        waybill,
        receiverSignatureBytes: waybill.receiverSignatureBytes,
        driverSignatureBytes: waybill.driverSignatureBytes,
        receiverStampBytes: waybill.receiverStampBytes,
      );

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: _pdfFileName(waybill.waybillNumber),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share this waybill PDF.')),
      );
    } finally {
      if (mounted) setState(() => sharingWaybillNumber = null);
    }
  }

  String _pdfFileName(String waybillNumber) {
    final safeWaybillNumber = waybillNumber.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    return 'Waybill_$safeWaybillNumber.pdf';
  }

  bool _isRejected(WaybillModel waybill) {
    return waybill.invoiceStatus == WaybillService.invoiceRejectedStatus;
  }

  String _displayStatus(WaybillModel waybill) {
    if (_isRejected(waybill)) return _rejectedFilter;
    return waybill.status;
  }

  bool _matchesSelectedFilter(WaybillModel waybill) {
    if (selectedStatusFilter == 'All') return true;
    if (selectedStatusFilter == _rejectedFilter) return _isRejected(waybill);
    return !_isRejected(waybill) && waybill.status == selectedStatusFilter;
  }

  Color getStatusColor(String status) {
    switch (status) {
      case WaybillService.pendingDeliveryStatus:
        return Colors.orange;
      case WaybillService.pendingSyncStatus:
        return Colors.deepOrange;
      case WaybillService.deliveredStatus:
        return Colors.blue;
      case WaybillService.invoicedStatus:
        return Colors.green;
      case _rejectedFilter:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Assigned Waybills',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172033),
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading
                ? null
                : () => loadAssignedWaybills(resetPagination: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              _buildSearchAndFilterRow(),
              const SizedBox(height: 14),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : assignedWaybills.isEmpty
                    ? _buildEmptyState()
                    : filteredWaybills.isEmpty
                    ? _buildNoMatchesState()
                    : Column(
                        children: [
                          Expanded(
                            child: isWideScreen
                                ? _buildTableView()
                                : _buildCardList(),
                          ),
                          if (_usingServerPagination) ...[
                            const SizedBox(height: 8),
                            _buildPaginationControls(),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalCount = assignedStats?.total ?? assignedWaybills.length;
    final pendingCount =
        assignedStats?.pendingDelivery ??
        assignedWaybills
            .where(
              (waybill) =>
                  !_isRejected(waybill) &&
                  waybill.status == WaybillService.pendingDeliveryStatus,
            )
            .length;
    final completedCount = totalCount - pendingCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF3FF), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E7FB)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_shipping, color: Colors.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All waybills assigned to you',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pendingCount pending, $completedCount completed or synced',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          Chip(
            avatar: const Icon(Icons.assignment, size: 16),
            label: Text('$totalCount Total'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 620;
        final searchField = TextField(
          controller: searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search waybill, BAJ number, client or status',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD8E1EC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD8E1EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.blue, width: 1.4),
            ),
          ),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 10),
              SizedBox(width: 520, child: _buildSummaryFilterPill()),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            searchField,
            const SizedBox(height: 10),
            _buildSummaryFilterPill(),
          ],
        );
      },
    );
  }

  Widget _buildSummaryFilterPill() {
    final pendingCount = _countByStatus(WaybillService.pendingDeliveryStatus);
    final deliveredCount = _countByStatus(WaybillService.deliveredStatus);
    final invoicedCount = _countByStatus(WaybillService.invoicedStatus);
    final rejectedCount = _countByStatus(_rejectedFilter);
    final showingCount = selectedStatusFilter == 'All'
        ? assignedStats?.total ?? filteredWaybills.length
        : _countByStatus(selectedStatusFilter);

    return PopupMenuButton<String>(
      initialValue: selectedStatusFilter,
      onSelected: (value) {
        setState(() => selectedStatusFilter = value);
        loadAssignedWaybills(resetPagination: true);
      },
      itemBuilder: (context) => [
        _buildFilterMenuItem(
          'All',
          assignedStats?.total ?? assignedWaybills.length,
        ),
        _buildFilterMenuItem(
          WaybillService.pendingDeliveryStatus,
          pendingCount,
        ),
        _buildFilterMenuItem(WaybillService.deliveredStatus, deliveredCount),
        _buildFilterMenuItem(WaybillService.invoicedStatus, invoicedCount),
        _buildFilterMenuItem(_rejectedFilter, rejectedCount),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_list, color: Colors.blue, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selectedStatusFilter == 'All'
                    ? 'Pending $pendingCount | Delivered $deliveredCount | Invoiced $invoicedCount | Rejected $rejectedCount'
                    : '$showingCount $selectedStatusFilter',
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem(String status, int count) {
    return PopupMenuItem<String>(
      value: status,
      child: Row(
        children: [
          Icon(
            status == selectedStatusFilter
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            color: status == 'All' ? Colors.blue : getStatusColor(status),
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(status)),
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  int _countByStatus(String status) {
    final stats = assignedStats;
    if (stats != null) {
      switch (status) {
        case WaybillService.pendingDeliveryStatus:
          return stats.pendingDelivery;
        case WaybillService.deliveredStatus:
          return stats.delivered;
        case WaybillService.invoicedStatus:
          return stats.invoiced;
        case _rejectedFilter:
          return stats.rejected;
      }
    }

    if (status == _rejectedFilter) {
      return assignedWaybills.where(_isRejected).length;
    }

    return assignedWaybills
        .where((waybill) => !_isRejected(waybill) && waybill.status == status)
        .length;
  }

  Widget _buildPaginationControls() {
    final start = (_currentPage * _itemsPerPage) + 1;
    final end = start + assignedWaybills.length - 1;
    final total = selectedStatusFilter == 'All'
        ? assignedStats?.total
        : _countByStatus(selectedStatusFilter);
    final showingText = total == null
        ? 'Showing $start-$end'
        : 'Showing $start-$end of $total';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E7FB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isLoading ? 'Loading waybills...' : showingText,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.filledTonal(
            onPressed: isLoading || _currentPage == 0
                ? null
                : () => loadAssignedWaybills(pageIndex: _currentPage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('Page ${_currentPage + 1}'),
          ),
          IconButton.filledTonal(
            onPressed: isLoading || !_hasNextPage
                ? null
                : () => loadAssignedWaybills(pageIndex: _currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.assignment_outlined, size: 54, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No assigned waybills yet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                'Waybills assigned to you will stay visible here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoMatchesState() {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 54, color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                'No matching waybills',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                selectedStatusFilter == 'All'
                    ? 'Try another search term.'
                    : 'No $selectedStatusFilter waybills match this search.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardList() {
    return RefreshIndicator(
      onRefresh: () => loadAssignedWaybills(resetPagination: true),
      child: ListView.builder(
        itemCount: filteredWaybills.length,
        itemBuilder: (context, index) {
          final waybill = filteredWaybills[index];
          final displayStatus = _displayStatus(waybill);
          final statusColor = getStatusColor(displayStatus);
          final isPendingDelivery =
              waybill.status == WaybillService.pendingDeliveryStatus;
          final isSharing = sharingWaybillNumber == waybill.waybillNumber;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFDDE6F2)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => openWaybill(waybill),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    waybill.waybillNumber,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF172033),
                                    ),
                                  ),
                                  _buildCardStatusChip(
                                    displayStatus,
                                    statusColor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 12,
                                runSpacing: 5,
                                children: [
                                  _buildCardInfoText(
                                    'BAJ No',
                                    waybill.bajNumber,
                                  ),
                                  _buildCardInfoText(
                                    'Client',
                                    waybill.shippingVendor,
                                  ),
                                  _buildCardIconText(
                                    Icons.calendar_today,
                                    waybill.date,
                                  ),
                                  _buildCardIconText(
                                    Icons.local_shipping,
                                    displayStatus,
                                    color: statusColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () => openWaybill(waybill),
                          icon: Icon(
                            isPendingDelivery
                                ? Icons.task_alt
                                : Icons.visibility,
                            size: 16,
                          ),
                          label: Text(isPendingDelivery ? 'Deliver' : 'View'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onPressed: sharingWaybillNumber == null
                              ? () => shareWaybillPdf(waybill)
                              : null,
                          icon: isSharing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.share, size: 16),
                          label: const Text('Share'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardStatusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildCardInfoText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Color(0xFF34465C), fontSize: 13),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value.isEmpty ? '-' : value,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardIconText(IconData icon, String text, {Color? color}) {
    final effectiveColor = color ?? const Color(0xFF34465C);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: effectiveColor),
        const SizedBox(width: 4),
        Text(
          text.isEmpty ? '-' : text,
          style: TextStyle(
            color: effectiveColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTableView() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SingleChildScrollView(
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
                    final displayStatus = _displayStatus(waybill);
                    final statusColor = getStatusColor(displayStatus);

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            waybill.waybillNumber,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          onTap: () => viewWaybill(waybill),
                        ),
                        DataCell(Text(waybill.bajNumber)),
                        DataCell(Text(waybill.date)),
                        DataCell(Text(waybill.shippingVendor)),
                        DataCell(
                          Chip(
                            label: Text(displayStatus),
                            backgroundColor: statusColor.withValues(
                              alpha: 0.14,
                            ),
                            labelStyle: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => openWaybill(waybill),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: Text(
                                  waybill.status ==
                                          WaybillService.pendingDeliveryStatus
                                      ? 'Deliver'
                                      : 'View',
                                ),
                              ),
                              TextButton.icon(
                                onPressed: sharingWaybillNumber == null
                                    ? () => shareWaybillPdf(waybill)
                                    : null,
                                icon:
                                    sharingWaybillNumber ==
                                        waybill.waybillNumber
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.share, size: 16),
                                label: const Text('Share'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
