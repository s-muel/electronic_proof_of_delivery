import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/waybill_model.dart';
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
  final searchController = TextEditingController();
  List<WaybillModel> assignedWaybills = [];
  String selectedStatusFilter = 'All';
  bool isLoading = true;
  String? sharingWaybillNumber;

  List<WaybillModel> get filteredWaybills {
    final searchText = searchController.text.trim().toLowerCase();

    return assignedWaybills.where((waybill) {
      final matchesStatus =
          selectedStatusFilter == 'All' ||
          waybill.status == selectedStatusFilter;
      final matchesSearch =
          searchText.isEmpty ||
          waybill.waybillNumber.toLowerCase().contains(searchText) ||
          waybill.bajNumber.toLowerCase().contains(searchText) ||
          waybill.shippingVendor.toLowerCase().contains(searchText) ||
          waybill.consigneeReceiver.toLowerCase().contains(searchText) ||
          waybill.status.toLowerCase().contains(searchText);

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

  Future<void> loadAssignedWaybills() async {
    final driverId = FirebaseAuthService.currentFirebaseUser?.uid ?? '';

    setState(() => isLoading = true);

    if (shouldUseFirestoreData) {
      try {
        final onlineWaybills =
            await FirestoreWaybillService.getWaybillsAssignedToDriver(driverId);
        await WaybillService.replaceCachedWaybills(onlineWaybills);
      } catch (_) {
        // The driver can still see the locally cached assigned waybills offline.
      }
    }

    if (!mounted) return;

    final localWaybills = WaybillService.getWaybillsAssignedToDriver(driverId)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {
      assignedWaybills = localWaybills;
      isLoading = false;
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
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

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
            onPressed: isLoading ? null : loadAssignedWaybills,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
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
                  : isWideScreen
                  ? _buildTableView()
                  : _buildCardList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final pendingCount = assignedWaybills
        .where(
          (waybill) => waybill.status == WaybillService.pendingDeliveryStatus,
        )
        .length;
    final completedCount = assignedWaybills.length - pendingCount;

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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_shipping, color: Colors.blue),
          ),
          const SizedBox(width: 12),
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
            avatar: const Icon(Icons.assignment, size: 18),
            label: Text('${assignedWaybills.length} Total'),
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
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD8E1EC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD8E1EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.blue, width: 1.4),
            ),
          ),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              SizedBox(width: 360, child: _buildSummaryFilterPill()),
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
    final showingCount = filteredWaybills.length;

    return PopupMenuButton<String>(
      initialValue: selectedStatusFilter,
      onSelected: (value) {
        setState(() => selectedStatusFilter = value);
      },
      itemBuilder: (context) => [
        _buildFilterMenuItem('All', assignedWaybills.length),
        _buildFilterMenuItem(
          WaybillService.pendingDeliveryStatus,
          pendingCount,
        ),
        _buildFilterMenuItem(WaybillService.deliveredStatus, deliveredCount),
        _buildFilterMenuItem(WaybillService.invoicedStatus, invoicedCount),
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
            const Icon(Icons.filter_list, color: Colors.blue, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selectedStatusFilter == 'All'
                    ? 'Pending $pendingCount | Delivered $deliveredCount | Invoiced $invoicedCount'
                    : '$showingCount $selectedStatusFilter',
                overflow: TextOverflow.ellipsis,
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
            size: 18,
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
    return assignedWaybills.where((waybill) => waybill.status == status).length;
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
              const SizedBox(height: 12),
              const Text(
                'No matching waybills',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
      onRefresh: loadAssignedWaybills,
      child: ListView.builder(
        itemCount: filteredWaybills.length,
        itemBuilder: (context, index) {
          final waybill = filteredWaybills[index];

          return Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.blue),
              title: Text(
                waybill.waybillNumber,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'BAJ No: ${waybill.bajNumber}\n'
                'Date: ${waybill.date}\n'
                'Client: ${waybill.shippingVendor} | ${waybill.status}',
              ),
              trailing: IconButton(
                tooltip: 'Share PDF',
                onPressed: sharingWaybillNumber == null
                    ? () => shareWaybillPdf(waybill)
                    : null,
                icon: sharingWaybillNumber == waybill.waybillNumber
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share, size: 20),
              ),
              isThreeLine: true,
              onTap: () => openWaybill(waybill),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableView() {
    return Card(
      clipBehavior: Clip.antiAlias,
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
            final statusColor = getStatusColor(waybill.status);

            return DataRow(
              cells: [
                DataCell(Text(waybill.waybillNumber)),
                DataCell(Text(waybill.bajNumber)),
                DataCell(Text(waybill.date)),
                DataCell(Text(waybill.shippingVendor)),
                DataCell(
                  Chip(
                    label: Text(waybill.status),
                    backgroundColor: statusColor.withValues(alpha: 0.14),
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
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(
                          waybill.status == WaybillService.pendingDeliveryStatus
                              ? 'Deliver'
                              : 'View',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: sharingWaybillNumber == null
                            ? () => shareWaybillPdf(waybill)
                            : null,
                        icon: sharingWaybillNumber == waybill.waybillNumber
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.share, size: 18),
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
    );
  }
}
