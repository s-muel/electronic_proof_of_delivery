import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../models/waybill_model.dart';
import 'pdf_service.dart';
import 'settings_service.dart';

class DeliveryEmailResult {
  final bool sent;
  final String message;

  const DeliveryEmailResult({
    required this.sent,
    required this.message,
  });
}

class DeliveryEmailService {
  static Future<DeliveryEmailResult> sendSignedWaybill({
    required WaybillModel waybill,
    required String receiverEmail,
  }) async {
    final cleanEmail = receiverEmail.trim();
    if (cleanEmail.isEmpty) {
      return const DeliveryEmailResult(
        sent: false,
        message: 'Receiver email is empty.',
      );
    }

    final settings = await SettingsService().loadSmtpSettings();
    if (!settings.isConfigured) {
      return const DeliveryEmailResult(
        sent: false,
        message: 'SMTP email settings are not configured.',
      );
    }

    _logEmailInfo(
      'SMTP EMAIL SETTINGS: host=${settings.smtpHost}, '
      'port=${settings.smtpPort}, ssl=${settings.smtpSsl}, '
      'ignoreBadCertificate=${settings.ignoreBadCertificate}, '
      'sender=${settings.senderEmail}',
    );

    final pdfBytes = await PdfService.generateWaybillPdf(
      waybill,
      receiverSignatureBytes: waybill.receiverSignatureBytes,
      driverSignatureBytes: waybill.driverSignatureBytes,
      receiverStampBytes: waybill.receiverStampBytes,
    );

    final smtpServer = SmtpServer(
      settings.smtpHost,
      port: settings.smtpPort,
      ssl: settings.smtpSsl,
      ignoreBadCertificate: settings.ignoreBadCertificate,
      username: settings.senderEmail,
      password: settings.senderPassword,
    );

    final message = Message()
      ..from = Address(settings.senderEmail, settings.senderName)
      ..recipients.add(cleanEmail)
      ..ccRecipients.addAll(_copyRecipients(settings.senderEmail, cleanEmail))
      ..subject = 'Signed Waybill ${waybill.waybillNumber}'
      ..text = _plainTextBody(waybill)
      ..attachments = [
        StreamAttachment(
          Stream<List<int>>.fromIterable([pdfBytes]),
          'application/pdf',
          fileName: _pdfFileName(waybill.waybillNumber),
        ),
      ];

    try {
      await send(message, smtpServer);
      return DeliveryEmailResult(
        sent: true,
        message: 'Signed waybill emailed to $cleanEmail.',
      );
    } on MailerException catch (error, stackTrace) {
      _logEmailError(error, stackTrace);
      return DeliveryEmailResult(
        sent: false,
        message: _mailerErrorMessage(error),
      );
    } catch (error, stackTrace) {
      _logEmailError(error, stackTrace);
      return DeliveryEmailResult(
        sent: false,
        message: 'Email failed: $error',
      );
    }
  }

  static List<String> _copyRecipients(String senderEmail, String receiverEmail) {
    final cleanSenderEmail = senderEmail.trim();
    if (cleanSenderEmail.isEmpty) return [];

    if (cleanSenderEmail.toLowerCase() == receiverEmail.trim().toLowerCase()) {
      return [];
    }

    return [cleanSenderEmail];
  }

  static String _plainTextBody(WaybillModel waybill) {
    return '''
Dear ${waybill.receiverName.isEmpty ? 'Receiver' : waybill.receiverName},

Please find attached the signed E-POD waybill.

Waybill No: ${waybill.waybillNumber}
BAJ No: ${waybill.bajNumber}
Delivery Date: ${waybill.deliveredAt.isEmpty ? waybill.date : waybill.deliveredAt}
Status: ${waybill.status}

Regards,
BAJ E-POD
''';
  }

  static String _mailerErrorMessage(MailerException error) {
    final problems = error.problems
        .map((problem) => '${problem.code}: ${problem.msg}')
        .join('; ');

    if (problems.isEmpty) {
      return 'Email failed: ${error.message}';
    }

    return 'Email failed: ${error.message}. Problems: $problems';
  }

  static void _logEmailError(Object error, StackTrace stackTrace) {
    _logEmailInfo('SMTP EMAIL ERROR: $error');

    if (error is MailerException && error.problems.isNotEmpty) {
      for (final problem in error.problems) {
        _logEmailInfo('SMTP EMAIL PROBLEM: ${problem.code} - ${problem.msg}');
      }
    }

    _logEmailInfo('SMTP EMAIL STACKTRACE: $stackTrace');
  }

  static void _logEmailInfo(String message) {
    debugPrint(message);
    // Plain print is intentionally kept for emulator logs where debugPrint can
    // be throttled among noisy platform output.
    // ignore: avoid_print
    print(message);
  }

  static String _pdfFileName(String waybillNumber) {
    final safeWaybillNumber = waybillNumber.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    return 'Waybill_$safeWaybillNumber.pdf';
  }
}
