import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../services/waybill_service.dart';
import '../widgets/waybill_template_widget.dart';

import 'dart:typed_data';
import 'signature_capture_screen.dart';
import 'stamp_capture_screen.dart';

import '../services/cloudinary_service.dart';
import '../services/delivery_email_service.dart';
import '../services/firestore_waybill_service.dart';
import '../services/whatsapp_share_service.dart';
import '../utils/platform_flags.dart';

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
  Uint8List? receiverStampBytes;

  final receiverNameController = TextEditingController();
  final receiverEmailController = TextEditingController();
  final receiverPhoneController = TextEditingController();
  final driverNameController = TextEditingController();
  final remarksController = TextEditingController();

  bool isOk = false;
  bool isShort = false;
  bool isOver = false;
  bool isDamaged = false;
  bool isParkingUnsuitable = false;
  bool isPartOrder = false;
  bool isCompleteOrder = false;

  bool receiverSignatureCaptured = false;
  bool driverSignatureCaptured = false;
  bool receiverStampCaptured = false;

  late WaybillModel currentWaybill;

  @override
  void initState() {
    super.initState();
    currentWaybill = widget.waybill;

    receiverNameController.text = widget.waybill.receiverName;
    receiverEmailController.text = widget.waybill.receiverEmail;
    receiverPhoneController.text = widget.waybill.receiverPhone;
    driverNameController.text = widget.waybill.driverName;
    remarksController.text = widget.waybill.deliveryRemarks;

    isOk = widget.waybill.isOk;
    isShort = widget.waybill.isShort;
    isOver = widget.waybill.isOver;
    isDamaged = widget.waybill.isDamaged;
    isParkingUnsuitable = widget.waybill.isParkingUnsuitable;
    isPartOrder = widget.waybill.isPartOrder;
    isCompleteOrder = widget.waybill.isCompleteOrder;

    receiverSignatureBytes = widget.waybill.receiverSignatureBytes;
    driverSignatureBytes = widget.waybill.driverSignatureBytes;
    receiverStampBytes = widget.waybill.receiverStampBytes;

    receiverSignatureCaptured =
        widget.waybill.receiverSignatureUrl.isNotEmpty ||
        receiverSignatureBytes != null;
    driverSignatureCaptured =
        widget.waybill.driverSignatureUrl.isNotEmpty ||
        driverSignatureBytes != null;
    receiverStampCaptured =
        widget.waybill.receiverStampUrl.isNotEmpty ||
        receiverStampBytes != null;
  }

  @override
  void dispose() {
    receiverNameController.dispose();
    receiverEmailController.dispose();
    receiverPhoneController.dispose();
    driverNameController.dispose();
    remarksController.dispose();
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

  Future<void> captureReceiverStamp() async {
    final result = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => const StampCaptureScreen()),
    );

    if (result != null) {
      setState(() {
        receiverStampBytes = result;
        receiverStampCaptured = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Receiver stamp captured')));
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
      receiverEmail: receiverEmailController.text.trim(),
      receiverPhone: receiverPhoneController.text.trim(),
      driverName: driverNameController.text.trim(),
      deliveryRemarks: remarksController.text.trim(),
      isOk: isOk,
      isShort: isShort,
      isOver: isOver,
      isDamaged: isDamaged,
      isParkingUnsuitable: isParkingUnsuitable,
      isPartOrder: isPartOrder,
      isCompleteOrder: isCompleteOrder,
      receiverSignatureUrl: receiverSignatureCaptured
          ? 'receiver-signature-captured-placeholder'
          : '',
      driverSignatureUrl: driverSignatureCaptured
          ? 'driver-signature-captured-placeholder'
          : '',
      receiverStampUrl: receiverStampCaptured
          ? 'receiver-stamp-captured-placeholder'
          : '',
    );
  }

  Future<void> submitDelivery() async {
    if (_formKey.currentState!.validate()) {
      if (!hasSelectedCondition) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one delivery condition'),
          ),
        );
        return;
      }

      if (!receiverSignatureCaptured || receiverSignatureBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please capture receiver signature')),
        );
        return;
      }

      if (!driverSignatureCaptured || driverSignatureBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please capture driver signature')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving delivery, please wait...')),
      );

      final safeWaybillNumber = currentWaybill.waybillNumber.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );

      final receiverSignatureUrl = await CloudinaryService.uploadSignature(
        signatureBytes: receiverSignatureBytes!,
        fileName: 'receiver_signature_$safeWaybillNumber',
      );

      final driverSignatureUrl = receiverSignatureUrl == null
          ? null
          : await CloudinaryService.uploadSignature(
              signatureBytes: driverSignatureBytes!,
              fileName: 'driver_signature_$safeWaybillNumber',
            );

      final receiverStampUrl =
          driverSignatureUrl == null || receiverStampBytes == null
          ? null
          : await CloudinaryService.uploadStamp(
              stampBytes: receiverStampBytes!,
              fileName: 'receiver_stamp_$safeWaybillNumber',
            );

      final bool uploadedOnline =
          receiverSignatureUrl != null &&
          driverSignatureUrl != null &&
          (receiverStampBytes == null || receiverStampUrl != null);
      final now = DateTime.now().toIso8601String();

      final updatedWaybill = currentWaybill.copyWith(
        receiverName: receiverNameController.text.trim(),
        receiverEmail: receiverEmailController.text.trim(),
        receiverPhone: receiverPhoneController.text.trim(),
        driverName: driverNameController.text.trim(),
        deliveryRemarks: remarksController.text.trim(),
        isOk: isOk,
        isShort: isShort,
        isOver: isOver,
        isDamaged: isDamaged,
        isParkingUnsuitable: isParkingUnsuitable,
        isPartOrder: isPartOrder,
        isCompleteOrder: isCompleteOrder,
        receiverSignatureUrl: receiverSignatureUrl ?? '',
        driverSignatureUrl: driverSignatureUrl ?? '',
        receiverStampUrl: receiverStampUrl ?? '',
        receiverSignatureBytes: receiverSignatureBytes,
        driverSignatureBytes: driverSignatureBytes,
        receiverStampBytes: receiverStampBytes,
        status: uploadedOnline
            ? WaybillService.deliveredStatus
            : WaybillService.pendingSyncStatus,
        syncStatus: uploadedOnline ? 'Synced' : 'Pending',
        deliveredAt: now,
        updatedAt: now,
      );

      var savedWaybill = updatedWaybill;
      var deliveryReadyForSharing = uploadedOnline;

      await WaybillService.updateWaybillByNumber(savedWaybill);
      if (uploadedOnline && shouldUseFirestoreData) {
        try {
          await FirestoreWaybillService.updateWaybill(savedWaybill);
        } catch (error) {
          debugPrint('DELIVERY FIRESTORE UPDATE ERROR: $error');
          savedWaybill = savedWaybill.copyWith(
            status: WaybillService.pendingSyncStatus,
            syncStatus: 'Pending',
            updatedAt: DateTime.now().toIso8601String(),
          );
          deliveryReadyForSharing = false;
          await WaybillService.updateWaybillByNumber(savedWaybill);
        }
      }

      final receiverEmail = receiverEmailController.text.trim();
      final receiverPhone = receiverPhoneController.text.trim();
      DeliveryEmailResult? emailResult;
      if (deliveryReadyForSharing && receiverEmail.isNotEmpty) {
        emailResult = await DeliveryEmailService.sendSignedWaybill(
          waybill: savedWaybill,
          receiverEmail: receiverEmail,
        );
      }

      WhatsAppShareResult? whatsappResult;
      if (deliveryReadyForSharing && receiverPhone.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing WhatsApp PDF. Please wait...'),
            duration: Duration(seconds: 2),
          ),
        );

        whatsappResult = await WhatsAppShareService.shareWaybillPdfToPhone(
          waybill: savedWaybill,
          receiverPhone: receiverPhone,
          receiverSignatureBytes: receiverSignatureBytes,
          driverSignatureBytes: driverSignatureBytes,
          receiverStampBytes: receiverStampBytes,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _deliveryResultMessage(
              uploadedOnline: deliveryReadyForSharing,
              emailResult: emailResult,
              whatsappResult: whatsappResult,
              phoneProvided: receiverPhone.isNotEmpty,
            ),
          ),
        ),
      );

      Navigator.pop(context, true);
    }
  }

  String _deliveryResultMessage({
    required bool uploadedOnline,
    required bool phoneProvided,
    WhatsAppShareResult? whatsappResult,
    DeliveryEmailResult? emailResult,
  }) {
    if (!uploadedOnline) {
      return 'Delivery saved offline. It will sync when internet is available.';
    }

    if (emailResult == null) {
      return _appendWhatsappMessage(
        'Delivery submitted successfully',
        phoneProvided: phoneProvided,
        whatsappResult: whatsappResult,
      );
    }

    final message = emailResult.sent
        ? 'Delivery submitted successfully. ${emailResult.message}'
        : 'Delivery submitted, but ${emailResult.message}';

    return _appendWhatsappMessage(
      message,
      phoneProvided: phoneProvided,
      whatsappResult: whatsappResult,
    );
  }

  String _appendWhatsappMessage(
    String message, {
    required bool phoneProvided,
    WhatsAppShareResult? whatsappResult,
  }) {
    if (!phoneProvided) return message;
    if (whatsappResult == null) {
      return '$message WhatsApp PDF was not sent.';
    }
    return '$message ${whatsappResult.message}';
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

                          _buildRemarksField(),

                          const SizedBox(height: 20),

                          _buildReceiverContactFields(isWideScreen),

                          const SizedBox(height: 16),

                          isWideScreen
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                    _buildReceiverSignatureBox(),
                                    const SizedBox(height: 16),
                                    _buildDriverField(),
                                    const SizedBox(height: 16),
                                    _buildDriverSignatureBox(),
                                  ],
                                ),

                          const SizedBox(height: 16),

                          _buildReceiverStampBox(),

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
                    receiverStampBytes: receiverStampBytes,
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

  Widget _buildReceiverEmailField() {
    return TextFormField(
      controller: receiverEmailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'Receiver Email (Optional)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.email),
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final email = value?.trim() ?? '';
        if (email.isEmpty) return null;
        if (!email.contains('@')) return 'Enter a valid email address';
        return null;
      },
    );
  }

  Widget _buildReceiverPhoneField() {
    return TextFormField(
      controller: receiverPhoneController,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        labelText: 'Receiver Phone (Optional)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.phone),
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final phone = value?.trim() ?? '';
        if (phone.isEmpty) return null;
        final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length < 9) return 'Enter a valid phone number';
        return null;
      },
    );
  }

  Widget _buildReceiverContactFields(bool isWideScreen) {
    if (isWideScreen) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildReceiverField()),
          const SizedBox(width: 16),
          Expanded(child: _buildReceiverEmailField()),
          const SizedBox(width: 16),
          Expanded(child: _buildReceiverPhoneField()),
        ],
      );
    }

    return Column(
      children: [
        _buildReceiverField(),
        const SizedBox(height: 16),
        _buildReceiverEmailField(),
        const SizedBox(height: 16),
        _buildReceiverPhoneField(),
      ],
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

  Widget _buildRemarksField() {
    return TextFormField(
      controller: remarksController,
      decoration: const InputDecoration(
        labelText: 'Remarks',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.notes),
      ),
      minLines: 2,
      maxLines: 4,
      onChanged: (_) => setState(() {}),
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

  Widget _buildReceiverStampBox() {
    return _signatureButton(
      title: 'Receiver Stamp (Optional)',
      isCaptured: receiverStampCaptured,
      signatureBytes: receiverStampBytes,
      onTap: captureReceiverStamp,
      emptyIcon: Icons.camera_alt,
    );
  }

  Widget _signatureButton({
    required String title,
    required bool isCaptured,
    required VoidCallback onTap,
    Uint8List? signatureBytes,
    IconData emptyIcon = Icons.draw,
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
              isCaptured ? Icons.check_circle : emptyIcon,
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
