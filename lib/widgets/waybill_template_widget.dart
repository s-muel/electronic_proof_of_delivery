import 'package:flutter/material.dart';
import '../models/waybill_model.dart';

class WaybillTemplateWidget extends StatelessWidget {
  final WaybillModel waybill;

  const WaybillTemplateWidget({super.key, required this.waybill});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 850,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          _buildTopInfo(),
          _buildPartySection(),
          _buildCargoSection(),
          _buildHazardSection(),
          _buildDeliverySection(),
          _buildSignatureSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black)),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              height: 95,
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.black)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      'BAJ',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BAJFREIGHT & LOGISTICS LIMITED',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'FAST • SAFE • SIMPLE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 95,
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  _smallHeaderInfo('BAJFREIGHT NO.', waybill.bajNumber),
                  const SizedBox(height: 10),
                  _smallHeaderInfo('WAYBILL NO.', waybill.waybillNumber),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallHeaderInfo(String label, String value) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(border: Border.all(color: Colors.black)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_label(label), const SizedBox(height: 3), _value(value)],
        ),
      ),
    );
  }

  Widget _buildTopInfo() {
    return Row(
      children: [
        Expanded(
          child: _box(label: 'DATE', value: waybill.date, height: 60),
        ),
        Expanded(
          child: _box(label: 'P.O. NO.', value: waybill.poNumber, height: 60),
        ),
        Expanded(
          child: _box(label: 'STATUS', value: waybill.status, height: 60),
        ),
      ],
    );
  }

  Widget _buildPartySection() {
    return Column(
      children: [
        _box(
          label: 'SHIPPING / VENDOR',
          value: waybill.shippingVendor,
          height: 65,
        ),
        _box(
          label: 'CONSIGNEE / RECEIVER',
          value: waybill.consigneeReceiver,
          height: 65,
        ),
        _box(
          label: 'OTHER DELIVERY ADDRESS',
          value: waybill.deliveryAddress,
          height: 70,
        ),
      ],
    );
  }

  Widget _buildCargoSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _box(
            label: 'DESCRIPTION OF CARGO',
            value: waybill.cargoDescription,
            height: 160,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _box(
                label: 'GROSS WEIGHT',
                value: waybill.grossWeight,
                height: 80,
              ),
              _box(
                label: 'COMMENTS / SPECIAL INSTRUCTION',
                value: waybill.comments,
                height: 80,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHazardSection() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _box(
            label: 'HAZARDOUS CARGO TYPE',
            value: waybill.hazardousCargoType,
            height: 60,
          ),
        ),
        Expanded(
          child: _box(label: 'UN', value: waybill.unNumber, height: 60),
        ),
        Expanded(
          child: _box(label: 'TREMCARD', value: waybill.tremcard, height: 60),
        ),
      ],
    );
  }

  Widget _buildDeliverySection() {
    return Row(
      children: [
        Expanded(
          child: _box(
            label: 'GOODS RECEIVED BY',
            value: waybill.receiverName,
            height: 65,
          ),
        ),
        Expanded(
          child: _box(
            label: 'VEHICLE NO.',
            value: waybill.vehicleNumber,
            height: 65,
          ),
        ),
        Expanded(
          child: _box(
            label: 'DRIVER NAME',
            value: waybill.driverName,
            height: 65,
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureSection() {
    return Row(
      children: [
        Expanded(
          child: _signatureBox(label: 'DRIVER SIGNATURE', value: ''),
        ),
        Expanded(
          child: _signatureBox(
            label: 'RECEIVER NAME',
            value: waybill.receiverName,
          ),
        ),
        Expanded(
          child: _signatureBox(
            label: 'RECEIVER SIGNATURE',
            value: waybill.signatureUrl.isEmpty ? '' : 'Signature Captured',
          ),
        ),
      ],
    );
  }

  Widget _box({
    required String label,
    required String value,
    required double height,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.black),
          right: BorderSide(color: Colors.black),
          bottom: BorderSide(color: Colors.black),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          Expanded(
            child: Align(alignment: Alignment.topLeft, child: _value(value)),
          ),
        ],
      ),
    );
  }

  Widget _signatureBox({required String label, required String value}) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.black),
          right: BorderSide(color: Colors.black),
          bottom: BorderSide(color: Colors.black),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const Spacer(),
          Text(
            value.isEmpty ? '' : value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: Colors.black),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _value(String text) {
    return Text(
      text.isEmpty ? '-' : text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
      overflow: TextOverflow.visible,
    );
  }
}
