import '../models/waybill_model.dart';
import 'cloudinary_service.dart';
import 'waybill_service.dart';

class DeliverySyncService {
  static Future<int> syncPendingDeliveries() async {
    var syncedCount = 0;
    final waybills = WaybillService.getAllWaybills();

    for (var index = 0; index < waybills.length; index++) {
      final waybill = waybills[index];

      if (waybill.status != WaybillService.pendingSyncStatus) {
        continue;
      }

      final syncedWaybill = await _syncWaybill(waybill);

      if (syncedWaybill != null) {
        await WaybillService.updateWaybill(index, syncedWaybill);
        syncedCount++;
      }
    }

    return syncedCount;
  }

  static Future<WaybillModel?> _syncWaybill(WaybillModel waybill) async {
    final safeWaybillNumber = _safeWaybillNumber(waybill.waybillNumber);
    var receiverSignatureUrl = waybill.signatureUrl;
    var driverSignatureUrl = waybill.driverSignatureUrl;

    if (receiverSignatureUrl.isEmpty) {
      final receiverSignatureBytes = waybill.receiverSignatureBytes;

      if (receiverSignatureBytes == null) {
        return null;
      }

      final uploadedUrl = await CloudinaryService.uploadSignature(
        signatureBytes: receiverSignatureBytes,
        fileName: 'receiver_signature_$safeWaybillNumber',
      );

      if (uploadedUrl == null) {
        return null;
      }

      receiverSignatureUrl = uploadedUrl;
    }

    if (driverSignatureUrl.isEmpty) {
      final driverSignatureBytes = waybill.driverSignatureBytes;

      if (driverSignatureBytes == null) {
        return null;
      }

      final uploadedUrl = await CloudinaryService.uploadSignature(
        signatureBytes: driverSignatureBytes,
        fileName: 'driver_signature_$safeWaybillNumber',
      );

      if (uploadedUrl == null) {
        return null;
      }

      driverSignatureUrl = uploadedUrl;
    }

    return waybill.copyWith(
      signatureUrl: receiverSignatureUrl,
      driverSignatureUrl: driverSignatureUrl,
      status: WaybillService.deliveredStatus,
    );
  }

  static String _safeWaybillNumber(String waybillNumber) {
    return waybillNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }
}
