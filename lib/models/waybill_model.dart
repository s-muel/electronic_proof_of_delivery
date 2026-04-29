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
  final String status;
  final String receiverName;
  final String signatureUrl;
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
    this.status = 'Pending Delivery',
    this.receiverName = '',
    this.signatureUrl = '',
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
      'status': status,
      'receiverName': receiverName,
      'signatureUrl': signatureUrl,
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
      status: map['status'] ?? 'Pending Delivery',
      receiverName: map['receiverName'] ?? '',
      signatureUrl: map['signatureUrl'] ?? '',
      createdAt: map['createdAt'] ?? '',
      deliveredAt: map['deliveredAt'] ?? '',
      invoicedAt: map['invoicedAt'] ?? '',
    );
  }
}