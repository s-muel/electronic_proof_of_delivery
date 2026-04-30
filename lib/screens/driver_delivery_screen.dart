import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../services/waybill_service.dart';
import '../widgets/waybill_template_widget.dart';

import 'dart:typed_data';
import 'signature_capture_screen.dart';

class DriverDeliveryScreen extends StatefulWidget {
  final WaybillModel waybill;
  final int index;

  const DriverDeliveryScreen({
    super.key,
    required this.waybill,
    required this.index,
  });

  @override
  State<DriverDeliveryScreen> createState() => _DriverDeliveryScreenState();
}

class _DriverDeliveryScreenState extends State<DriverDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();

  Uint8List? receiverSignatureBytes;
  Uint8List? driverSignatureBytes;

  final receiverNameController = TextEditingController();
  final driverNameController = TextEditingController();

  bool isOk = false;
  bool isShort = false;
  bool isOver = false;
  bool isDamaged = false;
  bool isParkingUnsuitable = false;
  bool isPartOrder = false;
  bool isCompleteOrder = false;

  bool receiverSignatureCaptured = false;
  bool driverSignatureCaptured = false;

  late WaybillModel currentWaybill;

  @override
  void initState() {
    super.initState();
    currentWaybill = widget.waybill;

    receiverNameController.text = widget.waybill.receiverName;
    driverNameController.text = widget.waybill.driverName;

    isOk = widget.waybill.isOk;
    isShort = widget.waybill.isShort;
    isOver = widget.waybill.isOver;
    isDamaged = widget.waybill.isDamaged;
    isParkingUnsuitable = widget.waybill.isParkingUnsuitable;
    isPartOrder = widget.waybill.isPartOrder;
    isCompleteOrder = widget.waybill.isCompleteOrder;

    receiverSignatureCaptured = widget.waybill.signatureUrl.isNotEmpty;
    driverSignatureCaptured = widget.waybill.driverSignatureUrl.isNotEmpty;
  }

  @override
  void dispose() {
    receiverNameController.dispose();
    driverNameController.dispose();
    super.dispose();
  }

  Future<void> captureReceiverSignature() async {
    final result = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const SignatureCaptureScreen(title: 'Receiver Signature'),
      ),
    );

    if (result != null) {
      setState(() {
        receiverSignatureBytes = result;
        receiverSignatureCaptured = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receiver signature captured')),
      );
    }
  }

  Future<void> captureDriverSignature() async {
    final result = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => const SignatureCaptureScreen(title: 'Driver Signature'),
      ),
    );

    if (result != null) {
      setState(() {
        driverSignatureBytes = result;
        driverSignatureCaptured = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver signature captured')),
      );
    }
  }

  bool get hasSelectedCondition {
    return isOk ||
        isShort ||
        isOver ||
        isDamaged ||
        isParkingUnsuitable ||
        isPartOrder ||
        isCompleteOrder;
  }

  WaybillModel getPreviewWaybill() {
    return currentWaybill.copyWith(
      receiverName: receiverNameController.text.trim(),
      driverName: driverNameController.text.trim(),
      isOk: isOk,
      isShort: isShort,
      isOver: isOver,
      isDamaged: isDamaged,
      isParkingUnsuitable: isParkingUnsuitable,
      isPartOrder: isPartOrder,
      isCompleteOrder: isCompleteOrder,
      signatureUrl: receiverSignatureCaptured
          ? 'receiver-signature-captured-placeholder'
          : '',
      driverSignatureUrl: driverSignatureCaptured
          ? 'driver-signature-captured-placeholder'
          : '',
    );
  }

  void submitDelivery() {
    if (_formKey.currentState!.validate()) {
      if (!hasSelectedCondition) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one delivery condition'),
          ),
        );
        return;
      }

      if (!receiverSignatureCaptured) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please capture receiver signature')),
        );
        return;
      }

      if (!driverSignatureCaptured) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please capture driver signature')),
        );
        return;
      }

      final updatedWaybill = currentWaybill.copyWith(
        receiverName: receiverNameController.text.trim(),
        driverName: driverNameController.text.trim(),
        isOk: isOk,
        isShort: isShort,
        isOver: isOver,
        isDamaged: isDamaged,
        isParkingUnsuitable: isParkingUnsuitable,
        isPartOrder: isPartOrder,
        isCompleteOrder: isCompleteOrder,
        signatureUrl: 'receiver-signature-captured-placeholder',
        driverSignatureUrl: 'driver-signature-captured-placeholder',
        receiverSignatureBytes: receiverSignatureBytes,
driverSignatureBytes: driverSignatureBytes,
        status: 'Delivered',
        deliveredAt: DateTime.now().toIso8601String(),
      );

      WaybillService.updateWaybill(widget.index, updatedWaybill);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery submitted successfully')),
      );

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text('Confirm Delivery - ${currentWaybill.waybillNumber}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1250),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery Confirmation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 18),

                          const Text(
                            'Delivery Condition',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),

                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              _conditionCheckbox(
                                label: 'OK',
                                value: isOk,
                                onChanged: (value) {
                                  setState(() => isOk = value ?? false);
                                },
                              ),
                              _conditionCheckbox(
                                label: 'Short',
                                value: isShort,
                                onChanged: (value) {
                                  setState(() => isShort = value ?? false);
                                },
                              ),
                              _conditionCheckbox(
                                label: 'Over',
                                value: isOver,
                                onChanged: (value) {
                                  setState(() => isOver = value ?? false);
                                },
                              ),
                              _conditionCheckbox(
                                label: 'Damaged',
                                value: isDamaged,
                                onChanged: (value) {
                                  setState(() => isDamaged = value ?? false);
                                },
                              ),
                              _conditionCheckbox(
                                label: 'Parking Unsuitable',
                                value: isParkingUnsuitable,
                                onChanged: (value) {
                                  setState(
                                    () => isParkingUnsuitable = value ?? false,
                                  );
                                },
                              ),
                              _conditionCheckbox(
                                label: 'Part Order',
                                value: isPartOrder,
                                onChanged: (value) {
                                  setState(() => isPartOrder = value ?? false);
                                },
                              ),
                              _conditionCheckbox(
                                label: 'Complete Order',
                                value: isCompleteOrder,
                                onChanged: (value) {
                                  setState(
                                    () => isCompleteOrder = value ?? false,
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          isWideScreen
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildReceiverField()),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildReceiverSignatureBox(),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildDriverField()),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildDriverSignatureBox()),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildReceiverField(),
                                    const SizedBox(height: 16),
                                    _buildReceiverSignatureBox(),
                                    const SizedBox(height: 16),
                                    _buildDriverField(),
                                    const SizedBox(height: 16),
                                    _buildDriverSignatureBox(),
                                  ],
                                ),

                          const SizedBox(height: 20),

                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: isWideScreen ? 230 : double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: submitDelivery,
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Submit Delivery'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Waybill Preview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: WaybillTemplateWidget(
                    waybill: getPreviewWaybill(),
                    receiverSignatureBytes: receiverSignatureBytes,
                    driverSignatureBytes: driverSignatureBytes,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _conditionCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return SizedBox(
      width: label.length > 10 ? 190 : 120,
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label),
      ),
    );
  }

  Widget _buildReceiverField() {
    return TextFormField(
      controller: receiverNameController,
      decoration: const InputDecoration(
        labelText: 'Receiver Name',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person),
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Receiver name is required';
        }
        return null;
      },
    );
  }

  Widget _buildDriverField() {
    return TextFormField(
      controller: driverNameController,
      decoration: const InputDecoration(
        labelText: 'Driver Name',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.local_shipping),
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Driver name is required';
        }
        return null;
      },
    );
  }

  Widget _buildReceiverSignatureBox() {
    return _signatureButton(
      title: 'Receiver Signature',
      isCaptured: receiverSignatureCaptured,
      signatureBytes: receiverSignatureBytes,
      onTap: captureReceiverSignature,
    );
  }

  Widget _buildDriverSignatureBox() {
    return _signatureButton(
      title: 'Driver Signature',
      isCaptured: driverSignatureCaptured,
      signatureBytes: driverSignatureBytes,
      onTap: captureDriverSignature,
    );
  }

  Widget _signatureButton({
    required String title,
    required bool isCaptured,
    required VoidCallback onTap,
    Uint8List? signatureBytes,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: isCaptured ? Colors.green : Colors.grey),
          borderRadius: BorderRadius.circular(6),
          color: isCaptured
              ? Colors.green.withValues(alpha: 0.08)
              : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              isCaptured ? Icons.check_circle : Icons.draw,
              color: isCaptured ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isCaptured && signatureBytes != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$title Captured',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Image.memory(
                            signatureBytes,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Tap to Capture $title',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
