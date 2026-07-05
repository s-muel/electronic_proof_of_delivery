import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/waybill_model.dart';
import '../models/waybill_stats_model.dart';

class FirestoreWaybillPage {
  final List<WaybillModel> waybills;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const FirestoreWaybillPage({
    required this.waybills,
    required this.lastDocument,
    required this.hasMore,
  });
}

class _StatsPeriod {
  final int year;
  final int month;

  const _StatsPeriod(this.year, this.month);
}

class FirestoreWaybillService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'waybills';
  static const String _counterDocumentPath = 'counters/waybills';
  static const String _statsDocumentPath = 'appStats/waybillsSummary';
  static const String _statsYearlyPrefix = 'appStats/yearly_';
  static const String _statsMonthlyPrefix = 'appStats/monthly_';
  static const String _userStatsDocumentName = 'waybillsSummary';
  static const String _assignedStatsDocumentName = 'assignedWaybillsSummary';
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

      transaction.set(counterRef, {
        'lastNumber': nextNumber,
        'prefix': _waybillPrefix,
        'padding': _waybillPadding,
        'updatedAt': now,
      }, SetOptions(merge: true));

      return '$_waybillPrefix${nextNumber.toString().padLeft(_waybillPadding, '0')}';
    });
  }

  static Future<void> createWaybill(WaybillModel waybill) async {
    final waybillRef = _waybills.doc(_safeDocumentId(waybill.waybillNumber));
    await _firestore.runTransaction((transaction) async {
      transaction.set(waybillRef, waybill.toFirestoreMap());
      _applyStatsDeltas(
        transaction: transaction,
        previousWaybill: null,
        nextWaybill: waybill,
      );
    });
  }

  static Future<void> updateWaybill(WaybillModel waybill) async {
    final waybillRef = _waybills.doc(_safeDocumentId(waybill.waybillNumber));
    await _firestore.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(waybillRef);
      final currentData = currentSnapshot.data();
      final previousWaybill = currentData == null
          ? null
          : WaybillModel.fromMap(currentData);

      transaction.set(
        waybillRef,
        waybill.toFirestoreMap(),
        SetOptions(merge: true),
      );
      _applyStatsDeltas(
        transaction: transaction,
        previousWaybill: previousWaybill,
        nextWaybill: waybill,
      );
    });
  }

  static Future<WaybillStatsModel?> getWaybillStats() async {
    final snapshot = await _firestore.doc(_statsDocumentPath).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return null;

    return WaybillStatsModel.fromMap(data);
  }

  static Future<WaybillStatsModel?> getYearlyWaybillStats(int year) async {
    final snapshot = await _firestore.doc(_yearlyStatsPath(year)).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return null;

    return WaybillStatsModel.fromMap(data);
  }

  static Future<WaybillStatsModel?> getMonthlyWaybillStats(
    int year,
    int month,
  ) async {
    final snapshot = await _firestore.doc(_monthlyStatsPath(year, month)).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return null;

    return WaybillStatsModel.fromMap(data);
  }

  static Future<WaybillStatsModel?> getUserWaybillStats(String userId) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return null;

    final snapshot = await _firestore.doc(_userStatsPath(trimmedUserId)).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return null;

    return WaybillStatsModel.fromMap(data);
  }

  static Future<WaybillStatsModel> rebuildUserWaybillStats(
    String userId,
  ) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return WaybillStatsModel.empty();

    final waybills = await getWaybillsCreatedBy(
      trimmedUserId,
      includeDeleted: true,
    );
    final stats = WaybillStatsModel.fromWaybills(waybills);

    await _firestore.doc(_userStatsPath(trimmedUserId)).set(stats.toMap());
    return stats;
  }

  static Future<WaybillStatsModel?> getAssignedDriverWaybillStats(
    String driverId,
  ) async {
    final trimmedDriverId = driverId.trim();
    if (trimmedDriverId.isEmpty) return null;

    final snapshot = await _firestore
        .doc(_assignedDriverStatsPath(trimmedDriverId))
        .get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return null;

    return WaybillStatsModel.fromMap(data);
  }

  static Future<WaybillStatsModel> rebuildAssignedDriverWaybillStats(
    String driverId,
  ) async {
    final trimmedDriverId = driverId.trim();
    if (trimmedDriverId.isEmpty) return WaybillStatsModel.empty();

    final waybills = await getWaybillsAssignedToDriver(
      trimmedDriverId,
      includeDeleted: true,
    );
    final stats = WaybillStatsModel.fromWaybills(waybills);

    await _firestore
        .doc(_assignedDriverStatsPath(trimmedDriverId))
        .set(stats.toMap());
    return stats;
  }

  static Future<WaybillStatsModel> getOrRebuildWaybillStats() async {
    final stats = await getWaybillStats();
    if (stats != null) return stats;

    return rebuildWaybillStats();
  }

  static Future<WaybillStatsModel> rebuildWaybillStats() async {
    final waybills = await getAllWaybills(includeDeleted: true);
    final stats = WaybillStatsModel.fromWaybills(waybills);
    final yearlyGroups = <int, List<WaybillModel>>{};
    final monthlyGroups = <String, List<WaybillModel>>{};
    final userGroups = <String, List<WaybillModel>>{};
    final assignedDriverGroups = <String, List<WaybillModel>>{};

    for (final waybill in waybills) {
      final statsUserId = _statsUserIdFor(waybill);
      if (statsUserId != null) {
        userGroups.putIfAbsent(statsUserId, () => []).add(waybill);
      }

      final assignedDriverId = _statsAssignedDriverIdFor(waybill);
      if (assignedDriverId != null) {
        assignedDriverGroups
            .putIfAbsent(assignedDriverId, () => [])
            .add(waybill);
      }
      final period = _statsPeriodFor(waybill);
      if (period == null) continue;

      yearlyGroups.putIfAbsent(period.year, () => []).add(waybill);
      monthlyGroups
          .putIfAbsent(_monthlyStatsKey(period.year, period.month), () => [])
          .add(waybill);
    }

    final batch = _firestore.batch();
    batch.set(_firestore.doc(_statsDocumentPath), stats.toMap());

    for (final entry in yearlyGroups.entries) {
      batch.set(
        _firestore.doc(_yearlyStatsPath(entry.key)),
        WaybillStatsModel.fromWaybills(entry.value).toMap(),
      );
    }

    for (final entry in monthlyGroups.entries) {
      final parts = entry.key.split('_');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      batch.set(
        _firestore.doc(_monthlyStatsPath(year, month)),
        WaybillStatsModel.fromWaybills(entry.value).toMap(),
      );
    }

    for (final entry in userGroups.entries) {
      batch.set(
        _firestore.doc(_userStatsPath(entry.key)),
        WaybillStatsModel.fromWaybills(entry.value).toMap(),
      );
    }

    for (final entry in assignedDriverGroups.entries) {
      batch.set(
        _firestore.doc(_assignedDriverStatsPath(entry.key)),
        WaybillStatsModel.fromWaybills(entry.value).toMap(),
      );
    }
    await batch.commit();
    return stats;
  }

  static Future<List<WaybillModel>> getAllWaybills({
    bool includeDeleted = false,
  }) async {
    final snapshot = await _waybills
        .orderBy('createdAt', descending: true)
        .get();

    final waybills = snapshot.docs
        .map((doc) => WaybillModel.fromMap(doc.data()))
        .toList();

    if (includeDeleted) {
      return waybills;
    }

    return waybills.where((waybill) => !waybill.isDeleted).toList();
  }

  static Future<FirestoreWaybillPage> getAllWaybillsPage({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    bool includeDeleted = false,
  }) async {
    Query<Map<String, dynamic>> query = _waybills.orderBy(
      'createdAt',
      descending: true,
    );

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(limit + 1).get();
    final docs = snapshot.docs;
    final pageDocs = docs.take(limit).toList();
    final waybills =
        pageDocs
            .map((doc) => WaybillModel.fromMap(doc.data()))
            .where((waybill) => includeDeleted || !waybill.isDeleted)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return FirestoreWaybillPage(
      waybills: waybills,
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: docs.length > limit,
    );
  }

  static Future<List<WaybillModel>> getWaybillsCreatedBy(
    String userId, {
    bool includeDeleted = false,
  }) async {
    final snapshot = await _waybills
        .where('createdByUserId', isEqualTo: userId)
        .get();

    final waybills =
        snapshot.docs.map((doc) => WaybillModel.fromMap(doc.data())).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (includeDeleted) {
      return waybills;
    }

    return waybills.where((waybill) => !waybill.isDeleted).toList();
  }

  static Future<FirestoreWaybillPage> getWaybillsCreatedByPage(
    String userId, {
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    String? statusFilter,
    bool rejectedOnly = false,
    bool includeDeleted = false,
  }) async {
    Query<Map<String, dynamic>> query = _waybills
        .where('createdByUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    final trimmedStatus = statusFilter?.trim() ?? '';
    if (trimmedStatus.isNotEmpty) {
      query = query.where('status', isEqualTo: trimmedStatus);
    }

    if (rejectedOnly) {
      query = query.where('invoiceStatus', isEqualTo: 'Rejected');
    }

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(limit + 1).get();
    final docs = snapshot.docs;
    final pageDocs = docs.take(limit).toList();
    final waybills =
        pageDocs
            .map((doc) => WaybillModel.fromMap(doc.data()))
            .where((waybill) => includeDeleted || !waybill.isDeleted)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return FirestoreWaybillPage(
      waybills: waybills,
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: docs.length > limit,
    );
  }

  static Future<List<WaybillModel>> getWaybillsAssignedToDriver(
    String driverId, {
    bool includeDeleted = false,
  }) async {
    final snapshot = await _waybills
        .where('assignedDriverId', isEqualTo: driverId)
        .get();

    final waybills =
        snapshot.docs.map((doc) => WaybillModel.fromMap(doc.data())).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (includeDeleted) {
      return waybills;
    }

    return waybills.where((waybill) => !waybill.isDeleted).toList();
  }

  static Future<FirestoreWaybillPage> getWaybillsAssignedToDriverPage(
    String driverId, {
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    String? statusFilter,
    bool includeDeleted = false,
  }) async {
    Query<Map<String, dynamic>> query = _waybills.where(
      'assignedDriverId',
      isEqualTo: driverId,
    );

    final trimmedStatus = statusFilter?.trim() ?? '';
    if (trimmedStatus.isNotEmpty) {
      query = query.where('status', isEqualTo: trimmedStatus);
    }

    query = query.orderBy('createdAt', descending: true);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(limit + 1).get();
    final docs = snapshot.docs;
    final pageDocs = docs.take(limit).toList();
    final waybills = pageDocs
        .map((doc) => WaybillModel.fromMap(doc.data()))
        .where((waybill) => includeDeleted || !waybill.isDeleted)
        .toList();

    return FirestoreWaybillPage(
      waybills: waybills,
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: docs.length > limit,
    );
  }

  static Future<FirestoreWaybillPage> getWaybillsByStatusPage(
    String status, {
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    bool includeDeleted = false,
  }) async {
    Query<Map<String, dynamic>> query = _waybills.where(
      'status',
      isEqualTo: status,
    );

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(limit + 1).get();
    final docs = snapshot.docs;
    final pageDocs = docs.take(limit).toList();
    final waybills =
        pageDocs
            .map((doc) => WaybillModel.fromMap(doc.data()))
            .where((waybill) => includeDeleted || !waybill.isDeleted)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return FirestoreWaybillPage(
      waybills: waybills,
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: docs.length > limit,
    );
  }

  static Future<FirestoreWaybillPage> getWaybillsByStatusAndInvoiceStatusPage(
    String status,
    String invoiceStatus, {
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    bool includeDeleted = false,
  }) async {
    Query<Map<String, dynamic>> query = _waybills
        .where('status', isEqualTo: status)
        .where('invoiceStatus', isEqualTo: invoiceStatus);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(limit + 1).get();
    final docs = snapshot.docs;
    final pageDocs = docs.take(limit).toList();
    final waybills =
        pageDocs
            .map((doc) => WaybillModel.fromMap(doc.data()))
            .where((waybill) => includeDeleted || !waybill.isDeleted)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return FirestoreWaybillPage(
      waybills: waybills,
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: docs.length > limit,
    );
  }

  static Future<FirestoreWaybillPage> getWaybillsByInvoiceStatusPage(
    String invoiceStatus, {
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    bool includeDeleted = false,
  }) async {
    Query<Map<String, dynamic>> query = _waybills.where(
      'invoiceStatus',
      isEqualTo: invoiceStatus,
    );

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(limit + 1).get();
    final docs = snapshot.docs;
    final pageDocs = docs.take(limit).toList();
    final waybills =
        pageDocs
            .map((doc) => WaybillModel.fromMap(doc.data()))
            .where((waybill) => includeDeleted || !waybill.isDeleted)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return FirestoreWaybillPage(
      waybills: waybills,
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: docs.length > limit,
    );
  }

  static Future<FirestoreWaybillPage> getWaybillsByExceptionPage(
    String exceptionFilter, {
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    bool includeDeleted = false,
  }) async {
    final fieldName = _exceptionFieldName(exceptionFilter);
    Query<Map<String, dynamic>> query = _waybills.where(
      fieldName,
      isEqualTo: true,
    );

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(limit + 1).get();
    final docs = snapshot.docs;
    final pageDocs = docs.take(limit).toList();
    final waybills =
        pageDocs
            .map((doc) => WaybillModel.fromMap(doc.data()))
            .where((waybill) => includeDeleted || !waybill.isDeleted)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return FirestoreWaybillPage(
      waybills: waybills,
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: docs.length > limit,
    );
  }

  static Future<List<WaybillModel>> getWaybillsByStatus(String status) async {
    final snapshot = await _waybills.where('status', isEqualTo: status).get();

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

  static void _applyStatsDeltas({
    required Transaction transaction,
    required WaybillModel? previousWaybill,
    required WaybillModel? nextWaybill,
  }) {
    _applyStatsDelta(
      transaction: transaction,
      statsRef: _firestore.doc(_statsDocumentPath),
      previousWaybill: previousWaybill,
      nextWaybill: nextWaybill,
    );

    _applyUserStatsDeltas(
      transaction: transaction,
      previousWaybill: previousWaybill,
      nextWaybill: nextWaybill,
    );

    _applyAssignedDriverStatsDeltas(
      transaction: transaction,
      previousWaybill: previousWaybill,
      nextWaybill: nextWaybill,
    );
    final previousPeriod = _statsPeriodFor(previousWaybill);
    final nextPeriod = _statsPeriodFor(nextWaybill);

    if (previousPeriod != null &&
        nextPeriod != null &&
        previousPeriod.year == nextPeriod.year &&
        previousPeriod.month == nextPeriod.month) {
      _applyStatsDelta(
        transaction: transaction,
        statsRef: _firestore.doc(_yearlyStatsPath(nextPeriod.year)),
        previousWaybill: previousWaybill,
        nextWaybill: nextWaybill,
      );
      _applyStatsDelta(
        transaction: transaction,
        statsRef: _firestore.doc(
          _monthlyStatsPath(nextPeriod.year, nextPeriod.month),
        ),
        previousWaybill: previousWaybill,
        nextWaybill: nextWaybill,
      );
      return;
    }

    if (previousPeriod != null) {
      _applyStatsDelta(
        transaction: transaction,
        statsRef: _firestore.doc(_yearlyStatsPath(previousPeriod.year)),
        previousWaybill: previousWaybill,
        nextWaybill: null,
      );
      _applyStatsDelta(
        transaction: transaction,
        statsRef: _firestore.doc(
          _monthlyStatsPath(previousPeriod.year, previousPeriod.month),
        ),
        previousWaybill: previousWaybill,
        nextWaybill: null,
      );
    }

    if (nextPeriod != null) {
      _applyStatsDelta(
        transaction: transaction,
        statsRef: _firestore.doc(_yearlyStatsPath(nextPeriod.year)),
        previousWaybill: null,
        nextWaybill: nextWaybill,
      );
      _applyStatsDelta(
        transaction: transaction,
        statsRef: _firestore.doc(
          _monthlyStatsPath(nextPeriod.year, nextPeriod.month),
        ),
        previousWaybill: null,
        nextWaybill: nextWaybill,
      );
    }
  }

  static _StatsPeriod? _statsPeriodFor(WaybillModel? waybill) {
    if (waybill == null || waybill.createdAt.trim().isEmpty) return null;

    final createdAt = DateTime.tryParse(waybill.createdAt);
    if (createdAt == null) return null;

    return _StatsPeriod(createdAt.year, createdAt.month);
  }

  static String _yearlyStatsPath(int year) => '$_statsYearlyPrefix$year';

  static String _monthlyStatsPath(int year, int month) =>
      '$_statsMonthlyPrefix${_monthlyStatsKey(year, month)}';

  static String _monthlyStatsKey(int year, int month) =>
      '${year}_${month.toString().padLeft(2, '0')}';

  static String _userStatsPath(String userId) =>
      'users/$userId/stats/$_userStatsDocumentName';

  static String? _statsUserIdFor(WaybillModel? waybill) {
    final userId = waybill?.createdByUserId.trim() ?? '';
    return userId.isEmpty ? null : userId;
  }

  static void _applyUserStatsDeltas({
    required Transaction transaction,
    required WaybillModel? previousWaybill,
    required WaybillModel? nextWaybill,
  }) {
    final previousUserId = _statsUserIdFor(previousWaybill);
    final nextUserId = _statsUserIdFor(nextWaybill);

    if (previousUserId != null && previousUserId == nextUserId) {
      _applyStatsDelta(
        transaction: transaction,
        statsRef: _firestore.doc(_userStatsPath(previousUserId)),
        previousWaybill: previousWaybill,
        nextWaybill: nextWaybill,
      );
      return;
    }

    if (previousUserId != null) {
      _applyStatsDelta(
        transaction: transaction,
        statsRef: _firestore.doc(_userStatsPath(previousUserId)),
        previousWaybill: previousWaybill,
        nextWaybill: null,
      );
    }

    if (nextUserId != null) {
      _applyStatsDelta(
        transaction: transaction,
        statsRef: _firestore.doc(_userStatsPath(nextUserId)),
        previousWaybill: null,
        nextWaybill: nextWaybill,
      );
    }
  }

  static String _assignedDriverStatsPath(String driverId) =>
      'users/$driverId/stats/$_assignedStatsDocumentName';

  static String? _statsAssignedDriverIdFor(WaybillModel? waybill) {
    final driverId = waybill?.assignedDriverId.trim() ?? '';
    return driverId.isEmpty ? null : driverId;
  }

  static void _applyAssignedDriverStatsDeltas({
    required Transaction transaction,
    required WaybillModel? previousWaybill,
    required WaybillModel? nextWaybill,
  }) {
    final previousDriverId = _statsAssignedDriverIdFor(previousWaybill);
    final nextDriverId = _statsAssignedDriverIdFor(nextWaybill);

    if (previousDriverId != null && previousDriverId == nextDriverId) {
      _applyStatsDelta(
        transaction: transaction,
        statsRef: _firestore.doc(_assignedDriverStatsPath(previousDriverId)),
        previousWaybill: previousWaybill,
        nextWaybill: nextWaybill,
      );
      return;
    }

    if (previousDriverId != null) {
      _applyStatsDelta(
        transaction: transaction,
        statsRef: _firestore.doc(_assignedDriverStatsPath(previousDriverId)),
        previousWaybill: previousWaybill,
        nextWaybill: null,
      );
    }

    if (nextDriverId != null) {
      _applyStatsDelta(
        transaction: transaction,
        statsRef: _firestore.doc(_assignedDriverStatsPath(nextDriverId)),
        previousWaybill: null,
        nextWaybill: nextWaybill,
      );
    }
  }

  static void _applyStatsDelta({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> statsRef,
    required WaybillModel? previousWaybill,
    required WaybillModel? nextWaybill,
  }) {
    final previousCounts = _statsContribution(previousWaybill);
    final nextCounts = _statsContribution(nextWaybill);
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };

    for (final key in nextCounts.keys) {
      final delta = (nextCounts[key] ?? 0) - (previousCounts[key] ?? 0);
      if (delta != 0) {
        updates[key] = FieldValue.increment(delta);
      }
    }

    transaction.set(statsRef, updates, SetOptions(merge: true));
  }

  static Map<String, int> _statsContribution(WaybillModel? waybill) {
    if (waybill == null || waybill.isDeleted) {
      return const {
        'total': 0,
        'pendingDelivery': 0,
        'delivered': 0,
        'readyForInvoice': 0,
        'sentForInvoicing': 0,
        'invoiced': 0,
        'rejected': 0,
        'short': 0,
        'over': 0,
        'damaged': 0,
        'parkingUnsuitable': 0,
        'partOrder': 0,
      };
    }

    final isRejected = waybill.invoiceStatus == 'Rejected';

    return {
      'total': 1,
      'pendingDelivery': waybill.status == 'Pending Delivery' && !isRejected
          ? 1
          : 0,
      'delivered': waybill.status == 'Delivered' && !isRejected ? 1 : 0,
      'readyForInvoice':
          waybill.status == 'Delivered' && waybill.invoiceStatus == 'Not Sent'
          ? 1
          : 0,
      'sentForInvoicing': waybill.invoiceStatus == 'Sent for Invoicing' ? 1 : 0,
      'invoiced': waybill.status == 'Invoiced' && !isRejected ? 1 : 0,
      'rejected': isRejected ? 1 : 0,
      'short': waybill.isShort ? 1 : 0,
      'over': waybill.isOver ? 1 : 0,
      'damaged': waybill.isDamaged ? 1 : 0,
      'parkingUnsuitable': waybill.isParkingUnsuitable ? 1 : 0,
      'partOrder': waybill.isPartOrder ? 1 : 0,
    };
  }

  static String _exceptionFieldName(String exceptionFilter) {
    switch (exceptionFilter) {
      case 'short':
        return 'isShort';
      case 'over':
        return 'isOver';
      case 'damaged':
        return 'isDamaged';
      case 'parkingUnsuitable':
        return 'isParkingUnsuitable';
      case 'partOrder':
        return 'isPartOrder';
      default:
        throw ArgumentError('Unknown exception filter: $exceptionFilter');
    }
  }

  static String _safeDocumentId(String waybillNumber) {
    return waybillNumber.replaceAll('/', '_');
  }
}
