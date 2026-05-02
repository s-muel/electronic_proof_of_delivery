import 'dart:typed_data';

class WaybillModel {
  final String bajNumber;
  final String waybillNumber;
  final String date;
  final String poNumber;
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

  final String status;
  final String receiverName;
  final String signatureUrl; // Receiver signature Cloudinary URL
  final String driverSignatureUrl; // Driver signature Cloudinary URL

  final Uint8List? receiverSignatureBytes; // Local receiver signature image
  final Uint8List? driverSignatureBytes; // Local driver signature image

  final String createdAt;
  final String deliveredAt;
  final String invoicedAt;

  WaybillModel({
    required this.bajNumber,
    required this.waybillNumber,
    required this.date,
    required this.poNumber,
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
    this.status = 'Pending Delivery',
    this.receiverName = '',
    this.signatureUrl = '',
    this.driverSignatureUrl = '',
    this.receiverSignatureBytes,
    this.driverSignatureBytes,
    required this.createdAt,
    this.deliveredAt = '',
    this.invoicedAt = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'bajNumber': bajNumber,
      'waybillNumber': waybillNumber,
      'date': date,
      'poNumber': poNumber,
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
      'status': status,
      'receiverName': receiverName,
      'signatureUrl': signatureUrl,
      'driverSignatureUrl': driverSignatureUrl,
      'receiverSignatureBytes': receiverSignatureBytes,
      'driverSignatureBytes': driverSignatureBytes,
      'createdAt': createdAt,
      'deliveredAt': deliveredAt,
      'invoicedAt': invoicedAt,
    };
  }

  factory WaybillModel.fromMap(Map<String, dynamic> map) {
    return WaybillModel(
      bajNumber: map['bajNumber'] ?? '',
      waybillNumber: map['waybillNumber'] ?? '',
      date: map['date'] ?? '',
      poNumber: map['poNumber'] ?? '',
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
      status: map['status'] ?? 'Pending Delivery',
      receiverName: map['receiverName'] ?? '',
      signatureUrl: map['signatureUrl'] ?? '',
      driverSignatureUrl: map['driverSignatureUrl'] ?? '',
      receiverSignatureBytes: _convertToUint8List(
        map['receiverSignatureBytes'],
      ),
      driverSignatureBytes: _convertToUint8List(map['driverSignatureBytes']),
      createdAt: map['createdAt'] ?? '',
      deliveredAt: map['deliveredAt'] ?? '',
      invoicedAt: map['invoicedAt'] ?? '',
    );
  }

  WaybillModel copyWith({
    String? bajNumber,
    String? waybillNumber,
    String? date,
    String? poNumber,
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
    String? status,
    String? receiverName,
    String? signatureUrl,
    String? driverSignatureUrl,
    Uint8List? receiverSignatureBytes,
    Uint8List? driverSignatureBytes,
    String? createdAt,
    String? deliveredAt,
    String? invoicedAt,
  }) {
    return WaybillModel(
      bajNumber: bajNumber ?? this.bajNumber,
      waybillNumber: waybillNumber ?? this.waybillNumber,
      date: date ?? this.date,
      poNumber: poNumber ?? this.poNumber,
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
      status: status ?? this.status,
      receiverName: receiverName ?? this.receiverName,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      driverSignatureUrl: driverSignatureUrl ?? this.driverSignatureUrl,
      receiverSignatureBytes:
          receiverSignatureBytes ?? this.receiverSignatureBytes,
      driverSignatureBytes: driverSignatureBytes ?? this.driverSignatureBytes,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      invoicedAt: invoicedAt ?? this.invoicedAt,
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
