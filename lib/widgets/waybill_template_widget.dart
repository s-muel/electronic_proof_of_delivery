import 'package:flutter/material.dart';
import '../models/waybill_model.dart';

import 'dart:typed_data';

class WaybillTemplateWidget extends StatelessWidget {
  final WaybillModel waybill;

  final Uint8List? receiverSignatureBytes;
  final Uint8List? driverSignatureBytes;

  const WaybillTemplateWidget({
    super.key,
    required this.waybill,
    this.receiverSignatureBytes,
    this.driverSignatureBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1120, // Landscape-style width
      padding: const EdgeInsets.all(14),
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
          _buildConditionSection(),
          _buildDeliverySection(),
          _buildSignatureSection(),
        ],
      ),
    );
  }

  Widget _buildConditionSection() {
    return Container(
      height: 75,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
          const Text(
            'CONTAINERS OFF LOADED FROM VEHICLE - DEMURAGE & DOUBLE HAULAGE MAY APPLY',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _checkItem('OK', waybill.isOk),
              _checkItem('SHORT', waybill.isShort),
              _checkItem('OVER', waybill.isOver),
              _checkItem('DAMAGED', waybill.isDamaged),
              _checkItem('PARKING\nUNSUITABLE', waybill.isParkingUnsuitable),
              _checkItem('PART\nORDER', waybill.isPartOrder),
              _checkItem('COMPLETE\nORDER', waybill.isCompleteOrder),
            ],
          ),
        ],
      ),
    );
  }

  Widget _checkItem(String label, bool checked) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: checked
                ? const Icon(Icons.check, size: 15, color: Colors.black)
                : null,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
          ),
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
            flex: 4,
            child: Container(
              height: 85,
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.black)),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/baj_logo.png',
                    width: 105,
                    height: 65,
                    fit: BoxFit.contain,
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
                            fontSize: 20,
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
            flex: 2,
            child: Container(
              height: 85,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.black)),
              ),
              child: const Text(
                'WAYBILL',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          Expanded(
            flex: 3,
            child: Container(
              height: 85,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _smallHeaderInfo('BAJFREIGHT NO.', waybill.bajNumber),
                  const SizedBox(height: 6),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(border: Border.all(color: Colors.black)),
        child: Row(
          children: [
            SizedBox(width: 105, child: _label(label)),
            Expanded(child: _value(value)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopInfo() {
    return Row(
      children: [
        Expanded(
          child: _box(label: 'DATE', value: waybill.date, height: 58),
        ),
        Expanded(
          child: _box(label: 'P.O. NO.', value: waybill.poNumber, height: 58),
        ),
        Expanded(
          child: _box(label: 'STATUS', value: waybill.status, height: 58),
        ),
      ],
    );
  }

  Widget _buildPartySection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _box(
                label: 'SHIPPING / VENDOR',
                value: waybill.shippingVendor,
                height: 65,
              ),
            ),
            Expanded(
              child: _box(
                label: 'CONSIGNEE / RECEIVER',
                value: waybill.consigneeReceiver,
                height: 65,
              ),
            ),
          ],
        ),
        _box(
          label: 'OTHER DELIVERY ADDRESS',
          value: waybill.deliveryAddress,
          height: 65,
        ),
      ],
    );
  }

  Widget _buildCargoSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _box(
            label: 'DESCRIPTION OF CARGO',
            value: waybill.cargoDescription,
            height: 130,
          ),
        ),
        Expanded(
          flex: 1,
          child: _box(
            label: 'GROSS WEIGHT',
            value: waybill.grossWeight,
            height: 130,
          ),
        ),
        Expanded(
          flex: 2,
          child: _box(
            label: 'COMMENTS / SPECIAL INSTRUCTION',
            value: waybill.comments,
            height: 130,
          ),
        ),
      ],
    );
  }

  Widget _buildHazardSection() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _box(
            label: 'HAZARDOUS CARGO TYPE',
            value: waybill.hazardousCargoType,
            height: 58,
          ),
        ),
        Expanded(
          child: _box(label: 'UN NUMBER', value: waybill.unNumber, height: 58),
        ),
        Expanded(
          child: _box(label: 'TREMCARD', value: waybill.tremcard, height: 58),
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
            height: 62,
          ),
        ),
        Expanded(
          child: _box(
            label: 'VEHICLE NO.',
            value: waybill.vehicleNumber,
            height: 62,
          ),
        ),
        Expanded(
          child: _box(
            label: 'DRIVER NAME',
            value: waybill.driverName,
            height: 62,
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureSection() {
    return Row(
      children: [
        Expanded(
          child: _signatureBox(
            label: 'DRIVER SIGNATURE',
            value: waybill.driverSignatureUrl.isEmpty
                ? ''
                : 'Driver Signature Captured',
            signatureBytes: driverSignatureBytes,
            signatureUrl: waybill.driverSignatureUrl,
          ),
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
            value: waybill.signatureUrl.isEmpty
                ? ''
                : 'Receiver Signature Captured',
            signatureBytes: receiverSignatureBytes,
            signatureUrl: waybill.signatureUrl,
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

  Widget _signatureBox({
    required String label,
    required String value,
    Uint8List? signatureBytes,
    String? signatureUrl,
  }) {
    final hasSignatureUrl =
        signatureUrl != null && signatureUrl.trim().isNotEmpty;

    return Container(
      height: 110,
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
          const SizedBox(height: 4),
          Expanded(
            child: signatureBytes != null
                ? Image.memory(
                    signatureBytes,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.centerLeft,
                  )
                : hasSignatureUrl
                ? Image.network(
                    signatureUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.centerLeft,
                    errorBuilder: (context, error, stackTrace) {
                      return Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  )
                : Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
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
