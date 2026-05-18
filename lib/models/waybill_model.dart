import 'dart:typed_data';

class WaybillModel {
  final String bajNumber;
  final String waybillNumber;
  final String date;
  final String poNumber;
  final String sealNumber;
  final String shippingVendor;
  final String consigneeReceiver;
  final String deliveryAddress;
  final String cargoDescription;
  final String grossWeight;
  final String vehicleNumber;
  final String driverName;
  final String comments;
  final String hazardousCargoType;
  final String unNumber;
  final String tremcard;

  final bool isOk;
  final bool isShort;
  final bool isOver;
  final bool isDamaged;
  final bool isParkingUnsuitable;
  final bool isPartOrder;
  final bool isCompleteOrder;
  final String deliveryRemarks;

  final String status;
  final String syncStatus;
  final String receiverName;
  final String receiverSignatureUrl; // Receiver signature image URL
  final String driverSignatureUrl; // Driver signature image URL

  final Uint8List? receiverSignatureBytes; // Local receiver signature image
  final Uint8List? driverSignatureBytes; // Local driver signature image

  final String createdAt;
  final String updatedAt;
  final String deliveredAt;
  final String invoicedAt;
  final bool isDeleted;
  final String deletedAt;
  final String deletedBy;
  final String createdByUserId;
  final String createdByName;
  final String createdByEmail;

  WaybillModel({
    required this.bajNumber,
    required this.waybillNumber,
    required this.date,
    required this.poNumber,
    this.sealNumber = '',
    required this.shippingVendor,
    required this.consigneeReceiver,
    required this.deliveryAddress,
    required this.cargoDescription,
    required this.grossWeight,
    required this.vehicleNumber,
    required this.driverName,
    required this.comments,
    this.hazardousCargoType = '',
    this.unNumber = '',
    this.tremcard = '',
    this.isOk = false,
    this.isShort = false,
    this.isOver = false,
    this.isDamaged = false,
    this.isParkingUnsuitable = false,
    this.isPartOrder = false,
    this.isCompleteOrder = false,
    this.deliveryRemarks = '',
    this.status = 'Pending Delivery',
    this.syncStatus = 'Synced',
    this.receiverName = '',
    this.receiverSignatureUrl = '',
    this.driverSignatureUrl = '',
    this.receiverSignatureBytes,
    this.driverSignatureBytes,
    required this.createdAt,
    String? updatedAt,
    this.deliveredAt = '',
    this.invoicedAt = '',
    this.isDeleted = false,
    this.deletedAt = '',
    this.deletedBy = '',
    this.createdByUserId = '',
    this.createdByName = '',
    this.createdByEmail = '',
  }) : updatedAt = updatedAt ?? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'bajNumber': bajNumber,
      'waybillNumber': waybillNumber,
      'date': date,
      'poNumber': poNumber,
      'sealNumber': sealNumber,
      'shippingVendor': shippingVendor,
      'consigneeReceiver': consigneeReceiver,
      'deliveryAddress': deliveryAddress,
      'cargoDescription': cargoDescription,
      'grossWeight': grossWeight,
      'vehicleNumber': vehicleNumber,
      'driverName': driverName,
      'comments': comments,
      'hazardousCargoType': hazardousCargoType,
      'unNumber': unNumber,
      'tremcard': tremcard,
      'isOk': isOk,
      'isShort': isShort,
      'isOver': isOver,
      'isDamaged': isDamaged,
      'isParkingUnsuitable': isParkingUnsuitable,
      'isPartOrder': isPartOrder,
      'isCompleteOrder': isCompleteOrder,
      'deliveryRemarks': deliveryRemarks,
      'status': status,
      'syncStatus': syncStatus,
      'receiverName': receiverName,
      'receiverSignatureUrl': receiverSignatureUrl,
      'driverSignatureUrl': driverSignatureUrl,
      'receiverSignatureBytes': receiverSignatureBytes,
      'driverSignatureBytes': driverSignatureBytes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deliveredAt': deliveredAt,
      'invoicedAt': invoicedAt,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
      'deletedBy': deletedBy,
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'createdByEmail': createdByEmail,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'bajNumber': bajNumber,
      'waybillNumber': waybillNumber,
      'date': date,
      'poNumber': poNumber,
      'sealNumber': sealNumber,
      'shippingVendor': shippingVendor,
      'consigneeReceiver': consigneeReceiver,
      'deliveryAddress': deliveryAddress,
      'cargoDescription': cargoDescription,
      'grossWeight': grossWeight,
      'comments': comments,
      'hazardousCargoType': hazardousCargoType,
      'unNumber': unNumber,
      'tremcard': tremcard,
      'vehicleNumber': vehicleNumber,
      'driverName': driverName,
      'receiverName': receiverName,
      'status': status,
      'syncStatus': syncStatus,
      'isOk': isOk,
      'isShort': isShort,
      'isOver': isOver,
      'isDamaged': isDamaged,
      'isParkingUnsuitable': isParkingUnsuitable,
      'isPartOrder': isPartOrder,
      'isCompleteOrder': isCompleteOrder,
      'deliveryRemarks': deliveryRemarks,
      'receiverSignatureUrl': receiverSignatureUrl,
      'driverSignatureUrl': driverSignatureUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deliveredAt': deliveredAt,
      'invoicedAt': invoicedAt,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
      'deletedBy': deletedBy,
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'createdByEmail': createdByEmail,
    };
  }

  factory WaybillModel.fromMap(Map<String, dynamic> map) {
    return WaybillModel(
      bajNumber: map['bajNumber'] ?? '',
      waybillNumber: map['waybillNumber'] ?? '',
      date: map['date'] ?? '',
      poNumber: map['poNumber'] ?? '',
      sealNumber: map['sealNumber'] ?? '',
      shippingVendor: map['shippingVendor'] ?? '',
      consigneeReceiver: map['consigneeReceiver'] ?? '',
      deliveryAddress: map['deliveryAddress'] ?? '',
      cargoDescription: map['cargoDescription'] ?? '',
      grossWeight: map['grossWeight'] ?? '',
      vehicleNumber: map['vehicleNumber'] ?? '',
      driverName: map['driverName'] ?? '',
      comments: map['comments'] ?? '',
      hazardousCargoType: map['hazardousCargoType'] ?? '',
      unNumber: map['unNumber'] ?? '',
      tremcard: map['tremcard'] ?? '',
      isOk: map['isOk'] ?? false,
      isShort: map['isShort'] ?? false,
      isOver: map['isOver'] ?? false,
      isDamaged: map['isDamaged'] ?? false,
      isParkingUnsuitable: map['isParkingUnsuitable'] ?? false,
      isPartOrder: map['isPartOrder'] ?? false,
      isCompleteOrder: map['isCompleteOrder'] ?? false,
      deliveryRemarks: map['deliveryRemarks'] ?? '',
      status: map['status'] ?? 'Pending Delivery',
      syncStatus: map['syncStatus'] ?? 'Synced',
      receiverName: map['receiverName'] ?? '',
      receiverSignatureUrl:
          map['receiverSignatureUrl'] ?? map['signatureUrl'] ?? '',
      driverSignatureUrl: map['driverSignatureUrl'] ?? '',
      receiverSignatureBytes: _convertToUint8List(
        map['receiverSignatureBytes'],
      ),
      driverSignatureBytes: _convertToUint8List(map['driverSignatureBytes']),
      createdAt: map['createdAt'] ?? '',
      updatedAt: map['updatedAt'],
      deliveredAt: map['deliveredAt'] ?? '',
      invoicedAt: map['invoicedAt'] ?? '',
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: map['deletedAt'] ?? '',
      deletedBy: map['deletedBy'] ?? '',
      createdByUserId: map['createdByUserId'] ?? '',
      createdByName: map['createdByName'] ?? '',
      createdByEmail: map['createdByEmail'] ?? '',
    );
  }

  WaybillModel copyWith({
    String? bajNumber,
    String? waybillNumber,
    String? date,
    String? poNumber,
    String? sealNumber,
    String? shippingVendor,
    String? consigneeReceiver,
    String? deliveryAddress,
    String? cargoDescription,
    String? grossWeight,
    String? vehicleNumber,
    String? driverName,
    String? comments,
    String? hazardousCargoType,
    String? unNumber,
    String? tremcard,
    bool? isOk,
    bool? isShort,
    bool? isOver,
    bool? isDamaged,
    bool? isParkingUnsuitable,
    bool? isPartOrder,
    bool? isCompleteOrder,
    String? deliveryRemarks,
    String? status,
    String? syncStatus,
    String? receiverName,
    String? receiverSignatureUrl,
    String? driverSignatureUrl,
    Uint8List? receiverSignatureBytes,
    Uint8List? driverSignatureBytes,
    String? createdAt,
    String? updatedAt,
    String? deliveredAt,
    String? invoicedAt,
    bool? isDeleted,
    String? deletedAt,
    String? deletedBy,
    String? createdByUserId,
    String? createdByName,
    String? createdByEmail,
  }) {
    return WaybillModel(
      bajNumber: bajNumber ?? this.bajNumber,
      waybillNumber: waybillNumber ?? this.waybillNumber,
      date: date ?? this.date,
      poNumber: poNumber ?? this.poNumber,
      sealNumber: sealNumber ?? this.sealNumber,
      shippingVendor: shippingVendor ?? this.shippingVendor,
      consigneeReceiver: consigneeReceiver ?? this.consigneeReceiver,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      cargoDescription: cargoDescription ?? this.cargoDescription,
      grossWeight: grossWeight ?? this.grossWeight,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      driverName: driverName ?? this.driverName,
      comments: comments ?? this.comments,
      hazardousCargoType: hazardousCargoType ?? this.hazardousCargoType,
      unNumber: unNumber ?? this.unNumber,
      tremcard: tremcard ?? this.tremcard,
      isOk: isOk ?? this.isOk,
      isShort: isShort ?? this.isShort,
      isOver: isOver ?? this.isOver,
      isDamaged: isDamaged ?? this.isDamaged,
      isParkingUnsuitable: isParkingUnsuitable ?? this.isParkingUnsuitable,
      isPartOrder: isPartOrder ?? this.isPartOrder,
      isCompleteOrder: isCompleteOrder ?? this.isCompleteOrder,
      deliveryRemarks: deliveryRemarks ?? this.deliveryRemarks,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      receiverName: receiverName ?? this.receiverName,
      receiverSignatureUrl: receiverSignatureUrl ?? this.receiverSignatureUrl,
      driverSignatureUrl: driverSignatureUrl ?? this.driverSignatureUrl,
      receiverSignatureBytes:
          receiverSignatureBytes ?? this.receiverSignatureBytes,
      driverSignatureBytes: driverSignatureBytes ?? this.driverSignatureBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      invoicedAt: invoicedAt ?? this.invoicedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByName: createdByName ?? this.createdByName,
      createdByEmail: createdByEmail ?? this.createdByEmail,
    );
  }

  static Uint8List? _convertToUint8List(dynamic value) {
    if (value == null) return null;

    if (value is Uint8List) {
      return value;
    }

    if (value is List<int>) {
      return Uint8List.fromList(value);
    }

    if (value is List<dynamic>) {
      return Uint8List.fromList(value.cast<int>());
    }

    return null;
  }
}
