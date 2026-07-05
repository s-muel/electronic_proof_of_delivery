import 'waybill_model.dart';

class WaybillStatsModel {
  final int total;
  final int pendingDelivery;
  final int delivered;
  final int readyForInvoice;
  final int sentForInvoicing;
  final int invoiced;
  final int rejected;
  final int short;
  final int over;
  final int damaged;
  final int parkingUnsuitable;
  final int partOrder;
  final String updatedAt;

  const WaybillStatsModel({
    required this.total,
    required this.pendingDelivery,
    required this.delivered,
    required this.readyForInvoice,
    required this.sentForInvoicing,
    required this.invoiced,
    required this.rejected,
    required this.short,
    required this.over,
    required this.damaged,
    required this.parkingUnsuitable,
    required this.partOrder,
    required this.updatedAt,
  });

  factory WaybillStatsModel.empty() {
    return const WaybillStatsModel(
      total: 0,
      pendingDelivery: 0,
      delivered: 0,
      readyForInvoice: 0,
      sentForInvoicing: 0,
      invoiced: 0,
      rejected: 0,
      short: 0,
      over: 0,
      damaged: 0,
      parkingUnsuitable: 0,
      partOrder: 0,
      updatedAt: '',
    );
  }

  factory WaybillStatsModel.fromMap(Map<String, dynamic> map) {
    return WaybillStatsModel(
      total: (map['total'] as num?)?.toInt() ?? 0,
      pendingDelivery: (map['pendingDelivery'] as num?)?.toInt() ?? 0,
      delivered: (map['delivered'] as num?)?.toInt() ?? 0,
      readyForInvoice: (map['readyForInvoice'] as num?)?.toInt() ?? 0,
      sentForInvoicing: (map['sentForInvoicing'] as num?)?.toInt() ?? 0,
      invoiced: (map['invoiced'] as num?)?.toInt() ?? 0,
      rejected: (map['rejected'] as num?)?.toInt() ?? 0,
      short: (map['short'] as num?)?.toInt() ?? 0,
      over: (map['over'] as num?)?.toInt() ?? 0,
      damaged: (map['damaged'] as num?)?.toInt() ?? 0,
      parkingUnsuitable: (map['parkingUnsuitable'] as num?)?.toInt() ?? 0,
      partOrder: (map['partOrder'] as num?)?.toInt() ?? 0,
      updatedAt: map['updatedAt'] ?? '',
    );
  }

  factory WaybillStatsModel.fromWaybills(List<WaybillModel> waybills) {
    var total = 0;
    var pendingDelivery = 0;
    var delivered = 0;
    var readyForInvoice = 0;
    var sentForInvoicing = 0;
    var invoiced = 0;
    var rejected = 0;
    var short = 0;
    var over = 0;
    var damaged = 0;
    var parkingUnsuitable = 0;
    var partOrder = 0;

    for (final waybill in waybills) {
      if (waybill.isDeleted) continue;

      total++;

      final isRejected = waybill.invoiceStatus == 'Rejected';
      if (waybill.status == 'Pending Delivery' && !isRejected) {
        pendingDelivery++;
      }
      if (waybill.status == 'Delivered' && !isRejected) delivered++;
      if (waybill.status == 'Invoiced' && !isRejected) invoiced++;
      if (waybill.status == 'Delivered' &&
          waybill.invoiceStatus == 'Not Sent') {
        readyForInvoice++;
      }
      if (waybill.invoiceStatus == 'Sent for Invoicing') sentForInvoicing++;
      if (waybill.invoiceStatus == 'Rejected') rejected++;
      if (waybill.isShort) short++;
      if (waybill.isOver) over++;
      if (waybill.isDamaged) damaged++;
      if (waybill.isParkingUnsuitable) parkingUnsuitable++;
      if (waybill.isPartOrder) partOrder++;
    }

    return WaybillStatsModel(
      total: total,
      pendingDelivery: pendingDelivery,
      delivered: delivered,
      readyForInvoice: readyForInvoice,
      sentForInvoicing: sentForInvoicing,
      invoiced: invoiced,
      rejected: rejected,
      short: short,
      over: over,
      damaged: damaged,
      parkingUnsuitable: parkingUnsuitable,
      partOrder: partOrder,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'pendingDelivery': pendingDelivery,
      'delivered': delivered,
      'readyForInvoice': readyForInvoice,
      'sentForInvoicing': sentForInvoicing,
      'invoiced': invoiced,
      'rejected': rejected,
      'short': short,
      'over': over,
      'damaged': damaged,
      'parkingUnsuitable': parkingUnsuitable,
      'partOrder': partOrder,
      'updatedAt': updatedAt,
    };
  }
}
