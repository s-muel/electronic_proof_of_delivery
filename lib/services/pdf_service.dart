import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/waybill_model.dart';

class PdfService {
  static Future<Uint8List> generateWaybillPdf(
    WaybillModel waybill, {
    Uint8List? receiverSignatureBytes,
    Uint8List? driverSignatureBytes,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;

    final pw.MemoryImage? receiverSignatureImage =
        receiverSignatureBytes != null
        ? pw.MemoryImage(receiverSignatureBytes)
        : null;

    final pw.MemoryImage? driverSignatureImage = driverSignatureBytes != null
        ? pw.MemoryImage(driverSignatureBytes)
        : null;

    try {
      final logoBytes = await rootBundle.load('assets/images/baj_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(waybill, logoImage),
                _buildTopInfo(waybill),
                _buildPartySection(waybill),
                _buildCargoSection(waybill),
                _buildHazardSection(waybill),
                _buildConditionSection(waybill),
                _buildDeliverySection(waybill),
                _buildSignatureSection(
                  waybill,
                  receiverSignatureImage: receiverSignatureImage,
                  driverSignatureImage: driverSignatureImage,
                ),
                _buildFooter(),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
    WaybillModel waybill,
    pw.MemoryImage? logoImage,
  ) {
    return pw.Container(
      height: 75,
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: PdfColors.black)),
              ),
              child: pw.Row(
                children: [
                  if (logoImage != null)
                    pw.Image(
                      logoImage,
                      width: 75,
                      height: 55,
                      fit: pw.BoxFit.contain,
                    )
                  else
                    pw.Container(
                      width: 75,
                      height: 55,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.blue),
                      ),
                      child: pw.Text(
                        'BAJ',
                        style: pw.TextStyle(
                          color: PdfColors.blue,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BAJFREIGHT & LOGISTICS LIMITED',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'FAST - SAFE - SIMPLE',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              alignment: pw.Alignment.center,
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: PdfColors.black)),
              ),
              child: pw.Text(
                'WAYBILL',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                children: [
                  _smallHeaderInfo('BAJFREIGHT NO.', waybill.bajNumber),
                  pw.SizedBox(height: 5),
                  _smallHeaderInfo('WAYBILL NO.', waybill.waybillNumber),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _smallHeaderInfo(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black),
        ),
        child: pw.Row(
          children: [
            pw.SizedBox(width: 85, child: _label(label)),
            pw.Expanded(child: _value(value)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTopInfo(WaybillModel waybill) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _box(label: 'DATE', value: waybill.date, height: 42),
        ),
        pw.Expanded(
          child: _box(label: 'P.O. NO.', value: waybill.poNumber, height: 42),
        ),
        pw.Expanded(
          child: _box(label: 'STATUS', value: waybill.status, height: 42),
        ),
      ],
    );
  }

  static pw.Widget _buildPartySection(WaybillModel waybill) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _box(
            label: 'SHIPPING / VENDOR',
            value: waybill.shippingVendor,
            height: 55,
          ),
        ),
        pw.Expanded(
          child: _box(
            label: 'CONSIGNEE / RECEIVER',
            value: waybill.consigneeReceiver,
            height: 55,
          ),
        ),
        pw.Expanded(
          child: _box(
            label: 'OTHER DELIVERY ADDRESS',
            value: waybill.deliveryAddress,
            height: 55,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCargoSection(WaybillModel waybill) {
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 3,
          child: _box(
            label: 'DESCRIPTION OF CARGO',
            value: waybill.cargoDescription,
            height: 85,
          ),
        ),
        pw.Expanded(
          flex: 1,
          child: _box(
            label: 'GROSS WEIGHT',
            value: waybill.grossWeight,
            height: 85,
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: _box(
            label: 'COMMENTS / SPECIAL INSTRUCTION',
            value: waybill.comments,
            height: 85,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildHazardSection(WaybillModel waybill) {
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 3,
          child: _box(
            label: 'HAZARDOUS CARGO TYPE',
            value: waybill.hazardousCargoType,
            height: 42,
          ),
        ),
        pw.Expanded(
          child: _box(label: 'UN NUMBER', value: waybill.unNumber, height: 42),
        ),
        pw.Expanded(
          child: _box(label: 'TREMCARD', value: waybill.tremcard, height: 42),
        ),
      ],
    );
  }

  static pw.Widget _buildConditionSection(WaybillModel waybill) {
    return pw.Container(
      height: 58,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CONTAINERS OFF LOADED FROM VEHICLE - DEMURAGE & DOUBLE HAULAGE MAY APPLY',
            style: pw.TextStyle(
              fontSize: 8,
              fontStyle: pw.FontStyle.italic,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 7),
          pw.Wrap(
            spacing: 16,
            runSpacing: 5,
            children: [
              _checkItem('OK', waybill.isOk),
              _checkItem('SHORT', waybill.isShort),
              _checkItem('OVER', waybill.isOver),
              _checkItem('DAMAGED', waybill.isDamaged),
              _checkItem('PARKING UNSUITABLE', waybill.isParkingUnsuitable),
              _checkItem('PART ORDER', waybill.isPartOrder),
              _checkItem('COMPLETE ORDER', waybill.isCompleteOrder),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _checkItem(String label, bool checked) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 12,
          height: 12,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black),
          ),
          child: checked
              ? pw.Text(
                  '/',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                )
              : pw.SizedBox(),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _buildDeliverySection(WaybillModel waybill) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _box(
            label: 'GOODS RECEIVED BY',
            value: waybill.receiverName,
            height: 45,
          ),
        ),
        pw.Expanded(
          child: _box(
            label: 'VEHICLE NO.',
            value: waybill.vehicleNumber,
            height: 45,
          ),
        ),
        pw.Expanded(
          child: _box(
            label: 'DRIVER NAME',
            value: waybill.driverName,
            height: 45,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSignatureSection(
    WaybillModel waybill, {
    pw.MemoryImage? receiverSignatureImage,
    pw.MemoryImage? driverSignatureImage,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _signatureBox(
            label: 'DRIVER SIGNATURE',
            value: waybill.driverSignatureUrl.isEmpty
                ? ''
                : 'Driver Signature Captured',
            signatureImage: driverSignatureImage,
          ),
        ),
        pw.Expanded(
          child: _signatureBox(
            label: 'RECEIVER NAME',
            value: waybill.receiverName,
          ),
        ),
        pw.Expanded(
          child: _signatureBox(
            label: 'RECEIVER SIGNATURE',
            value: waybill.receiverSignatureUrl.isEmpty
                ? ''
                : 'Receiver Signature Captured',
            signatureImage: receiverSignatureImage,
          ),
        ),
      ],
    );
  }

  static pw.Widget _signatureBox({
    required String label,
    required String value,
    pw.MemoryImage? signatureImage,
  }) {
    return pw.Container(
      height: 65,
      padding: const pw.EdgeInsets.all(6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(color: PdfColors.black),
          bottom: pw.BorderSide(color: PdfColors.black),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _label(label),
          pw.SizedBox(height: 4),
          pw.Expanded(
            child: signatureImage != null
                ? pw.Image(
                    signatureImage,
                    fit: pw.BoxFit.contain,
                    alignment: pw.Alignment.centerLeft,
                  )
                : pw.Align(
                    alignment: pw.Alignment.bottomLeft,
                    child: pw.Text(
                      value,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(height: 1, color: PdfColors.black),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'BAJFREIGHT STANDARD TRADING CONDITION APPLY',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'BAJFREIGHT ACCEPTS NO RESPONSIBILITY FOR THE GOODS IF PACKING IS UNSUITABLE',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _box({
    required String label,
    required String value,
    required double height,
  }) {
    return pw.Container(
      height: height,
      padding: const pw.EdgeInsets.all(6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(color: PdfColors.black),
          bottom: pw.BorderSide(color: PdfColors.black),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _label(label),
          pw.SizedBox(height: 4),
          pw.Expanded(child: _value(value)),
        ],
      ),
    );
  }

  static pw.Widget _label(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    );
  }

  static pw.Widget _value(String text) {
    return pw.Text(
      text.isEmpty ? '-' : text,
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      maxLines: 4,
    );
  }
}
