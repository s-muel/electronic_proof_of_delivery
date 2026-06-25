import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/waybill_model.dart';
import 'pdf_service.dart';

class WhatsAppShareResult {
  final bool sentToWhatsApp;
  final String message;

  const WhatsAppShareResult({
    required this.sentToWhatsApp,
    required this.message,
  });
}

class WhatsAppShareService {
  static const _channel = MethodChannel('baj_epod/whatsapp_share');

  static Future<WhatsAppShareResult> shareWaybillPdfToPhone({
    required WaybillModel waybill,
    required String receiverPhone,
    Uint8List? receiverSignatureBytes,
    Uint8List? driverSignatureBytes,
    Uint8List? receiverStampBytes,
  }) async {
    final phone = _normalizeWhatsAppPhone(receiverPhone);
    if (phone.isEmpty) {
      return const WhatsAppShareResult(
        sentToWhatsApp: false,
        message: 'Receiver phone number is empty.',
      );
    }

    try {
      final pdfBytes = await PdfService.generateWaybillPdf(
        waybill,
        receiverSignatureBytes: receiverSignatureBytes,
        driverSignatureBytes: driverSignatureBytes,
        receiverStampBytes: receiverStampBytes,
      );
      final fileName =
          'Waybill_${waybill.waybillNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf';
      final receiverName = waybill.receiverName.trim().isEmpty
          ? 'Customer'
          : waybill.receiverName.trim();
      final message =
          'Hello $receiverName, please find attached the signed waybill '
          '${waybill.waybillNumber}.';

      final opened = await _channel.invokeMethod<bool>('sharePdfToWhatsApp', {
        'phone': phone,
        'fileName': fileName,
        'pdfBytes': pdfBytes,
        'message': message,
      });

      if (opened == true) {
        return const WhatsAppShareResult(
          sentToWhatsApp: true,
          message: 'WhatsApp opened with the signed PDF. Tap Send to share it.',
        );
      }

      return const WhatsAppShareResult(
        sentToWhatsApp: false,
        message: 'WhatsApp could not be opened on this device.',
      );
    } on PlatformException catch (error) {
      debugPrint('WHATSAPP PDF SHARE ERROR: ${error.code} ${error.message}');
      return WhatsAppShareResult(
        sentToWhatsApp: false,
        message: error.message ?? 'WhatsApp could not be opened.',
      );
    } catch (error) {
      debugPrint('WHATSAPP PDF SHARE ERROR: $error');
      return const WhatsAppShareResult(
        sentToWhatsApp: false,
        message: 'WhatsApp PDF share failed.',
      );
    }
  }

  static String _normalizeWhatsAppPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0') && digits.length >= 10) {
      return '233${digits.substring(1)}';
    }
    return digits;
  }
}
