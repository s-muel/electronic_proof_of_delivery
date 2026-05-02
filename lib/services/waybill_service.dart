import 'package:hive/hive.dart';
import '../models/waybill_model.dart';

class WaybillService {
  static const String _boxName = 'waybillsBox';
  static const String pendingDeliveryStatus = 'Pending Delivery';
  static const String pendingSyncStatus = 'Pending Sync';
  static const String deliveredStatus = 'Delivered';
  static const String invoicedStatus = 'Invoiced';

  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static int getIndexByWaybillNumber(String waybillNumber) {
    final allWaybills = getAllWaybills();

    return allWaybills.indexWhere(
      (waybill) => waybill.waybillNumber == waybillNumber,
    );
  }

  static List<WaybillModel> getAllWaybills() {
    return _box.values.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return WaybillModel.fromMap(map);
    }).toList();
  }

  static Future<void> addWaybill(WaybillModel waybill) async {
    await _box.add(waybill.toMap());
  }

  static String generateNextWaybillNumber() {
    const prefix = 'BAJ/WB-';
    final waybillPattern = RegExp(r'^BAJ/WB-(\d+)$');
    var highestNumber = 0;

    for (final waybill in getAllWaybills()) {
      final match = waybillPattern.firstMatch(waybill.waybillNumber.trim());

      if (match == null) {
        continue;
      }

      final number = int.tryParse(match.group(1) ?? '') ?? 0;

      if (number > highestNumber) {
        highestNumber = number;
      }
    }

    final nextNumber = highestNumber + 1;
    return '$prefix${nextNumber.toString().padLeft(4, '0')}';
  }

  static Future<void> updateWaybill(
    int index,
    WaybillModel updatedWaybill,
  ) async {
    if (index >= 0 && index < _box.length) {
      await _box.putAt(index, updatedWaybill.toMap());
    }
  }

  static List<WaybillModel> getPendingWaybills() {
    return getAllWaybills()
        .where((waybill) => waybill.status == pendingDeliveryStatus)
        .toList();
  }

  static List<WaybillModel> getPendingSyncWaybills() {
    return getAllWaybills()
        .where((waybill) => waybill.status == pendingSyncStatus)
        .toList();
  }

  static List<WaybillModel> getDeliveredWaybills() {
    return getAllWaybills()
        .where((waybill) => waybill.status == deliveredStatus)
        .toList();
  }

  static List<WaybillModel> getInvoicedWaybills() {
    return getAllWaybills()
        .where((waybill) => waybill.status == invoicedStatus)
        .toList();
  }

  static Future<void> deleteWaybill(int index) async {
    if (index >= 0 && index < _box.length) {
      await _box.deleteAt(index);
    }
  }

  static Future<void> clearAllWaybills() async {
    await _box.clear();
  }
}
