import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/waybill_model.dart';

class FirestoreWaybillService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'waybills';
  static const String _counterDocumentPath = 'counters/waybills';
  static const String _waybillPrefix = 'BAJ/WB-';
  static const int _waybillPadding = 4;

  static CollectionReference<Map<String, dynamic>> get _waybills =>
      _firestore.collection(_collectionName);

  static Future<String> generateNextWaybillNumber() async {
    return _firestore.runTransaction((transaction) async {
      final counterRef = _firestore.doc(_counterDocumentPath);
      final counterSnapshot = await transaction.get(counterRef);
      final data = counterSnapshot.data();
      final lastNumber = data?['lastNumber'] as int? ?? 0;
      final nextNumber = lastNumber + 1;
      final now = DateTime.now().toIso8601String();

      transaction.set(
        counterRef,
        {
          'lastNumber': nextNumber,
          'prefix': _waybillPrefix,
          'padding': _waybillPadding,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      return '$_waybillPrefix${nextNumber.toString().padLeft(_waybillPadding, '0')}';
    });
  }

  static Future<void> createWaybill(WaybillModel waybill) async {
    await _waybills
        .doc(_safeDocumentId(waybill.waybillNumber))
        .set(waybill.toFirestoreMap());
  }

  static Future<void> updateWaybill(WaybillModel waybill) async {
    await _waybills
        .doc(_safeDocumentId(waybill.waybillNumber))
        .set(waybill.toFirestoreMap(), SetOptions(merge: true));
  }

  static Future<List<WaybillModel>> getAllWaybills({
    bool includeDeleted = false,
  }) async {
    final snapshot = await _waybills.orderBy('createdAt', descending: true).get();

    final waybills = snapshot.docs
        .map((doc) => WaybillModel.fromMap(doc.data()))
        .toList();

    if (includeDeleted) {
      return waybills;
    }

    return waybills.where((waybill) => !waybill.isDeleted).toList();
  }

  static Future<List<WaybillModel>> getWaybillsCreatedBy(
    String userId, {
    bool includeDeleted = false,
  }) async {
    final snapshot = await _waybills
        .where('createdByUserId', isEqualTo: userId)
        .get();

    final waybills = snapshot.docs
        .map((doc) => WaybillModel.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (includeDeleted) {
      return waybills;
    }

    return waybills.where((waybill) => !waybill.isDeleted).toList();
  }

  static Future<List<WaybillModel>> getWaybillsAssignedToDriver(
    String driverId, {
    bool includeDeleted = false,
  }) async {
    final snapshot = await _waybills
        .where('assignedDriverId', isEqualTo: driverId)
        .get();

    final waybills = snapshot.docs
        .map((doc) => WaybillModel.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (includeDeleted) {
      return waybills;
    }

    return waybills.where((waybill) => !waybill.isDeleted).toList();
  }

  static Future<List<WaybillModel>> getWaybillsByStatus(String status) async {
    final snapshot = await _waybills
        .where('status', isEqualTo: status)
        .get();

    return snapshot.docs
        .map((doc) => WaybillModel.fromMap(doc.data()))
        .where((waybill) => !waybill.isDeleted)
        .toList();
  }

  static Future<void> softDeleteWaybill({
    required WaybillModel waybill,
    required String deletedBy,
  }) async {
    final now = DateTime.now().toIso8601String();

    await updateWaybill(
      waybill.copyWith(
        isDeleted: true,
        deletedAt: now,
        deletedBy: deletedBy,
        updatedAt: now,
      ),
    );
  }

  static Future<void> restoreWaybill(WaybillModel waybill) async {
    final now = DateTime.now().toIso8601String();

    await updateWaybill(
      waybill.copyWith(
        isDeleted: false,
        deletedAt: '',
        deletedBy: '',
        updatedAt: now,
      ),
    );
  }

  static String _safeDocumentId(String waybillNumber) {
    return waybillNumber.replaceAll('/', '_');
  }
}
