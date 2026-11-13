import '../models/waybill_model.dart';

class DeliveryEmailResult {
  final bool sent;
  final String message;

  const DeliveryEmailResult({required this.sent, required this.message});
}

class DeliveryEmailService {
  static const bool isEnabled = false;

  static Future<DeliveryEmailResult> sendSignedWaybill({
    required WaybillModel waybill,
    required String receiverEmail,
  }) async {
    return const DeliveryEmailResult(
      sent: false,
      message:
          'Email sending is temporarily unavailable. Use PDF or WhatsApp sharing.',
    );
  }
}
