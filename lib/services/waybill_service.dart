import 'package:hive/hive.dart';
import '../models/waybill_model.dart';

class WaybillService {
  static const String _boxName = 'waybillsBox';
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
        .where((waybill) => waybill.status == 'Pending Delivery')
        .toList();
  }

  static List<WaybillModel> getDeliveredWaybills() {
    return getAllWaybills()
        .where((waybill) => waybill.status == 'Delivered')
        .toList();
  }

  static List<WaybillModel> getInvoicedWaybills() {
    return getAllWaybills()
        .where((waybill) => waybill.status == 'Invoiced')
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
