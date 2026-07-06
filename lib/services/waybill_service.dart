import 'package:hive/hive.dart';
import '../models/waybill_model.dart';

class WaybillService {
  static const String _boxName = 'waybillsBox';
  static const String pendingDeliveryStatus = 'Pending Delivery';
  static const String pendingSyncStatus = 'Pending Sync';
  static const String deliveredStatus = 'Delivered';
  static const String invoicedStatus = 'Invoiced';
  static const String invoiceNotSentStatus = 'Not Sent';
  static const String invoiceSentStatus = 'Sent for Invoicing';
  static const String invoiceAcceptedStatus = 'Accepted';
  static const String invoiceRejectedStatus = 'Rejected';

  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static int getIndexByWaybillNumber(String waybillNumber) {
    final allWaybills = getAllWaybills(includeDeleted: true);

    return allWaybills.indexWhere(
      (waybill) => waybill.waybillNumber == waybillNumber,
    );
  }

  static Future<int> ensureCachedIndex(WaybillModel waybill) async {
    var index = getIndexByWaybillNumber(waybill.waybillNumber);

    if (index == -1) {
      await updateWaybillByNumber(waybill);
      index = getIndexByWaybillNumber(waybill.waybillNumber);
    }

    return index;
  }

  static List<WaybillModel> getAllWaybills({bool includeDeleted = false}) {
    final waybills = _box.values.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return WaybillModel.fromMap(map);
    }).toList();

    if (includeDeleted) {
      return waybills;
    }

    return waybills.where((waybill) => !waybill.isDeleted).toList();
  }

  static List<WaybillModel> getWaybillsCreatedBy(String userId) {
    return getAllWaybills()
        .where((waybill) => waybill.createdByUserId == userId)
        .toList();
  }

  static List<WaybillModel> getWaybillsAssignedToDriver(String driverId) {
    return _uniqueByWaybillNumber(
      getAllWaybills()
          .where((waybill) => waybill.assignedDriverId == driverId)
          .toList(),
    );
  }

  static Future<void> addWaybill(WaybillModel waybill) async {
    await _box.add(waybill.toMap());
  }

  static Future<void> replaceCachedWaybills(List<WaybillModel> waybills) async {
    final pendingSyncByWaybillNumber = {
      for (final waybill in getPendingSyncWaybills())
        waybill.waybillNumber: waybill,
    };
    final cachedWaybillNumbers = <String>{};

    await _box.clear();

    for (final waybill in _uniqueByWaybillNumber(waybills)) {
      final pendingSyncWaybill =
          pendingSyncByWaybillNumber[waybill.waybillNumber];
      final waybillToCache = pendingSyncWaybill ?? waybill;

      await _box.add(waybillToCache.toMap());
      cachedWaybillNumbers.add(waybillToCache.waybillNumber);
    }

    for (final pendingSyncWaybill in pendingSyncByWaybillNumber.values) {
      if (!cachedWaybillNumbers.contains(pendingSyncWaybill.waybillNumber)) {
        await _box.add(pendingSyncWaybill.toMap());
      }
    }
  }

  static Future<void> mergeCachedWaybills(List<WaybillModel> waybills) async {
    for (final waybill in _uniqueByWaybillNumber(waybills)) {
      final existingIndex = getIndexByWaybillNumber(waybill.waybillNumber);
      if (existingIndex >= 0 && existingIndex < _box.length) {
        final existingMap = Map<String, dynamic>.from(
          _box.getAt(existingIndex) as Map,
        );
        final existingWaybill = WaybillModel.fromMap(existingMap);

        if (existingWaybill.status == pendingSyncStatus) {
          continue;
        }
      }

      await updateWaybillByNumber(waybill);
    }
  }

  static List<WaybillModel> _uniqueByWaybillNumber(
    List<WaybillModel> waybills,
  ) {
    final waybillsByNumber = <String, WaybillModel>{};

    for (final waybill in waybills) {
      final key = waybill.waybillNumber.trim().isEmpty
          ? '${waybill.bajNumber}-${waybill.createdAt}'
          : waybill.waybillNumber.trim();
      waybillsByNumber[key] = waybill;
    }

    return waybillsByNumber.values.toList();
  }

  static String generateNextWaybillNumber() {
    const prefix = 'BAJ/WB-';
    final waybillPattern = RegExp(r'^BAJ/WB-(\d+)$');
    var highestNumber = 0;

    for (final waybill in getAllWaybills(includeDeleted: true)) {
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

  static Future<bool> updateWaybillByNumber(WaybillModel updatedWaybill) async {
    final index = getIndexByWaybillNumber(updatedWaybill.waybillNumber);

    if (index >= 0 && index < _box.length) {
      await _box.putAt(index, updatedWaybill.toMap());
      return true;
    }

    await _box.add(updatedWaybill.toMap());
    return false;
  }

  static List<WaybillModel> getPendingWaybills() {
    return getAllWaybills()
        .where((waybill) => waybill.status == pendingDeliveryStatus)
        .toList();
  }

  static List<WaybillModel> getPendingWaybillsCreatedBy(String userId) {
    return getWaybillsCreatedBy(
      userId,
    ).where((waybill) => waybill.status == pendingDeliveryStatus).toList();
  }

  static List<WaybillModel> getPendingWaybillsAssignedToDriver(
    String driverId,
  ) {
    return getWaybillsAssignedToDriver(
      driverId,
    ).where((waybill) => waybill.status == pendingDeliveryStatus).toList();
  }

  static List<WaybillModel> getPendingSyncWaybills() {
    return getAllWaybills()
        .where((waybill) => waybill.status == pendingSyncStatus)
        .toList();
  }

  static List<WaybillModel> getPendingSyncWaybillsAssignedToDriver(
    String driverId,
  ) {
    return getWaybillsAssignedToDriver(
      driverId,
    ).where((waybill) => waybill.status == pendingSyncStatus).toList();
  }

  static List<WaybillModel> getDeliveredWaybills() {
    return getAllWaybills()
        .where((waybill) => waybill.status == deliveredStatus)
        .toList();
  }

  static List<WaybillModel> getReadyForInvoiceWaybills() {
    return getAllWaybills()
        .where(
          (waybill) =>
              waybill.status == deliveredStatus &&
              waybill.invoiceStatus == invoiceNotSentStatus,
        )
        .toList();
  }

  static List<WaybillModel> getSentForInvoicingWaybills() {
    return getAllWaybills()
        .where((waybill) => waybill.invoiceStatus == invoiceSentStatus)
        .toList();
  }

  static List<WaybillModel> getRejectedInvoiceWaybills() {
    return getAllWaybills()
        .where((waybill) => waybill.invoiceStatus == invoiceRejectedStatus)
        .toList();
  }

  static List<WaybillModel> getDeliveredWaybillsCreatedBy(String userId) {
    return getWaybillsCreatedBy(
      userId,
    ).where((waybill) => waybill.status == deliveredStatus).toList();
  }

  static List<WaybillModel> getInvoicedWaybills() {
    return getAllWaybills()
        .where((waybill) => waybill.status == invoicedStatus)
        .toList();
  }

  static List<WaybillModel> getInvoicedWaybillsCreatedBy(String userId) {
    return getWaybillsCreatedBy(
      userId,
    ).where((waybill) => waybill.status == invoicedStatus).toList();
  }

  static Future<void> deleteWaybill(int index) async {
    if (index >= 0 && index < _box.length) {
      await _box.deleteAt(index);
    }
  }

  static Future<void> softDeleteWaybillByNumber({
    required String waybillNumber,
    required String deletedBy,
  }) async {
    final index = getIndexByWaybillNumber(waybillNumber);

    if (index < 0 || index >= _box.length) {
      return;
    }

    final current = WaybillModel.fromMap(
      Map<String, dynamic>.from(_box.getAt(index) as Map),
    );
    final now = DateTime.now().toIso8601String();

    await _box.putAt(
      index,
      current
          .copyWith(
            isDeleted: true,
            deletedAt: now,
            deletedBy: deletedBy,
            updatedAt: now,
          )
          .toMap(),
    );
  }

  static Future<void> restoreWaybillByNumber(String waybillNumber) async {
    final index = getIndexByWaybillNumber(waybillNumber);

    if (index < 0 || index >= _box.length) {
      return;
    }

    final current = WaybillModel.fromMap(
      Map<String, dynamic>.from(_box.getAt(index) as Map),
    );
    final now = DateTime.now().toIso8601String();

    await _box.putAt(
      index,
      current
          .copyWith(
            isDeleted: false,
            deletedAt: '',
            deletedBy: '',
            updatedAt: now,
          )
          .toMap(),
    );
  }

  static Future<void> clearAllWaybills() async {
    await _box.clear();
  }
}
