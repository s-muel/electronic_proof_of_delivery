import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../widgets/waybill_template_widget.dart';
import 'edit_waybill_screen.dart';
import '../services/waybill_service.dart';

import 'package:printing/printing.dart';
import '../services/pdf_service.dart';

class WaybillDetailsScreen extends StatefulWidget {
  final WaybillModel waybill;
  final int index;

  const WaybillDetailsScreen({
    super.key,
    required this.waybill,
    required this.index,
  });

  @override
  State<WaybillDetailsScreen> createState() => _WaybillDetailsScreenState();
}

class _WaybillDetailsScreenState extends State<WaybillDetailsScreen> {
  late WaybillModel currentWaybill;
  bool _isDownloadingPdf = false;

  @override
  void initState() {
    super.initState();
    currentWaybill = widget.waybill;
  }

  Future<void> downloadPdf() async {
    if (_isDownloadingPdf) return;

    setState(() => _isDownloadingPdf = true);

    try {
      final pdfBytes = await PdfService.generateWaybillPdf(
        currentWaybill,
        receiverSignatureBytes: currentWaybill.receiverSignatureBytes,
        driverSignatureBytes: currentWaybill.driverSignatureBytes,
      );

      await Printing.layoutPdf(
        name: 'Waybill_${currentWaybill.waybillNumber}.pdf',
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
        setState(() => _isDownloadingPdf = false);
      }
    }
  }

  void editWaybill() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditWaybillScreen(waybill: currentWaybill, index: widget.index),
      ),
    );

    if (result == true) {
      setState(() {
        currentWaybill = WaybillService.getAllWaybills()[widget.index];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = currentWaybill.status == 'Pending Delivery';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0.5,
        title: Text(
          'Waybill ${currentWaybill.waybillNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton.icon(
              onPressed: _isDownloadingPdf ? null : downloadPdf,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              icon: _isDownloadingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf, size: 18),
              label: Text(_isDownloadingPdf ? 'Preparing PDF' : 'Download PDF'),
            ),
          ),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
              child: OutlinedButton.icon(
                onPressed: editWaybill,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: _WaybillHeaderCard(waybill: currentWaybill),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFDDE5EF)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: WaybillTemplateWidget(
                      waybill: currentWaybill,
                      receiverSignatureBytes:
                          currentWaybill.receiverSignatureBytes,
                      driverSignatureBytes: currentWaybill.driverSignatureBytes,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaybillHeaderCard extends StatelessWidget {
  final WaybillModel waybill;

  const _WaybillHeaderCard({required this.waybill});

  Color get _statusColor {
    switch (waybill.status) {
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF3FF), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD7E7FB)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waybill.waybillNumber,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172033),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'BAJ No: ${waybill.bajNumber}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          _HeaderInfo(icon: Icons.calendar_today, label: 'Date', value: waybill.date),
          _HeaderInfo(
            icon: Icons.business,
            label: 'Vendor',
            value: waybill.shippingVendor,
          ),
          Chip(
            avatar: Icon(Icons.circle, size: 12, color: _statusColor),
            label: Text(waybill.status),
            backgroundColor: _statusColor.withValues(alpha: 0.12),
            side: BorderSide(color: _statusColor.withValues(alpha: 0.25)),
            labelStyle: TextStyle(
              color: _statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF64748B), size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 210),
              child: Text(
                value.isEmpty ? '-' : value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
