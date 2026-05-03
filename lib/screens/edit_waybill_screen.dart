import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../services/firestore_waybill_service.dart';
import '../services/waybill_service.dart';
import '../utils/platform_flags.dart';

class EditWaybillScreen extends StatefulWidget {
  final WaybillModel waybill;
  final int index;

  const EditWaybillScreen({
    super.key,
    required this.waybill,
    required this.index,
  });

  @override
  State<EditWaybillScreen> createState() => _EditWaybillScreenState();
}

class _EditWaybillScreenState extends State<EditWaybillScreen> {
  final _formKey = GlobalKey<FormState>();

  final bajNumberController = TextEditingController();
  final waybillNumberController = TextEditingController();
  final dateController = TextEditingController();
  final poNumberController = TextEditingController();
  final shippingVendorController = TextEditingController();
  final consigneeReceiverController = TextEditingController();
  final deliveryAddressController = TextEditingController();
  final cargoDescriptionController = TextEditingController();
  final grossWeightController = TextEditingController();
  final vehicleNumberController = TextEditingController();
  final driverNameController = TextEditingController();
  final commentsController = TextEditingController();
  final hazardousCargoTypeController = TextEditingController();
  final unNumberController = TextEditingController();
  final tremcardController = TextEditingController();

  @override
  void initState() {
    super.initState();

    bajNumberController.text = widget.waybill.bajNumber;
    waybillNumberController.text = widget.waybill.waybillNumber;
    dateController.text = widget.waybill.date;
    poNumberController.text = widget.waybill.poNumber;
    shippingVendorController.text = widget.waybill.shippingVendor;
    consigneeReceiverController.text = widget.waybill.consigneeReceiver;
    deliveryAddressController.text = widget.waybill.deliveryAddress;
    cargoDescriptionController.text = widget.waybill.cargoDescription;
    grossWeightController.text = widget.waybill.grossWeight;
    vehicleNumberController.text = widget.waybill.vehicleNumber;
    driverNameController.text = widget.waybill.driverName;
    commentsController.text = widget.waybill.comments;
    hazardousCargoTypeController.text = widget.waybill.hazardousCargoType;
    unNumberController.text = widget.waybill.unNumber;
    tremcardController.text = widget.waybill.tremcard;
  }

  @override
  void dispose() {
    bajNumberController.dispose();
    waybillNumberController.dispose();
    dateController.dispose();
    poNumberController.dispose();
    shippingVendorController.dispose();
    consigneeReceiverController.dispose();
    deliveryAddressController.dispose();
    cargoDescriptionController.dispose();
    grossWeightController.dispose();
    vehicleNumberController.dispose();
    driverNameController.dispose();
    commentsController.dispose();
    hazardousCargoTypeController.dispose();
    unNumberController.dispose();
    tremcardController.dispose();
    super.dispose();
  }

  Future<void> updateWaybill() async {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now().toIso8601String();
      final updatedWaybill = widget.waybill.copyWith(
        bajNumber: bajNumberController.text.trim(),
        waybillNumber: waybillNumberController.text.trim(),
        date: dateController.text.trim(),
        poNumber: poNumberController.text.trim(),
        shippingVendor: shippingVendorController.text.trim(),
        consigneeReceiver: consigneeReceiverController.text.trim(),
        deliveryAddress: deliveryAddressController.text.trim(),
        cargoDescription: cargoDescriptionController.text.trim(),
        grossWeight: grossWeightController.text.trim(),
        vehicleNumber: vehicleNumberController.text.trim(),
        driverName: driverNameController.text.trim(),
        comments: commentsController.text.trim(),
        hazardousCargoType: hazardousCargoTypeController.text.trim(),
        unNumber: unNumberController.text.trim(),
        tremcard: tremcardController.text.trim(),
        updatedAt: now,
      );

      await WaybillService.updateWaybill(widget.index, updatedWaybill);
      if (shouldUseFirestoreData) {
        try {
          await FirestoreWaybillService.updateWaybill(updatedWaybill);
        } catch (_) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Waybill updated locally. It will need internet to sync online.',
              ),
            ),
          );
          Navigator.pop(context, true);
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waybill updated successfully')),
      );

      Navigator.pop(context, true);
    }
  }

  Widget buildTextField({
    required String label,
    required TextEditingController controller,
    bool requiredField = true,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }
              return null;
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 750;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Waybill No: ${widget.waybill.waybillNumber}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: isWideScreen ? 480 : double.infinity,
                        child: buildTextField(
                          label: 'BAJ Number',
                          controller: bajNumberController,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 480 : double.infinity,
                        child: buildTextField(
                          label: 'Waybill Number',
                          controller: waybillNumberController,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 480 : double.infinity,
                        child: buildTextField(
                          label: 'Date',
                          controller: dateController,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 480 : double.infinity,
                        child: buildTextField(
                          label: 'P.O. Number',
                          controller: poNumberController,
                          requiredField: false,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 480 : double.infinity,
                        child: buildTextField(
                          label: 'Shipping/Vendor',
                          controller: shippingVendorController,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 480 : double.infinity,
                        child: buildTextField(
                          label: 'Consignee/Receiver',
                          controller: consigneeReceiverController,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 480 : double.infinity,
                        child: buildTextField(
                          label: 'Other Delivery Address',
                          controller: deliveryAddressController,
                          requiredField: false,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 480 : double.infinity,
                        child: buildTextField(
                          label: 'Gross Weight',
                          controller: grossWeightController,
                          requiredField: false,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 480 : double.infinity,
                        child: buildTextField(
                          label: 'Vehicle Number',
                          controller: vehicleNumberController,
                          requiredField: false,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 480 : double.infinity,
                        child: buildTextField(
                          label: 'Driver Name',
                          controller: driverNameController,
                          requiredField: false,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 976 : double.infinity,
                        child: buildTextField(
                          label: 'Description of Cargo',
                          controller: cargoDescriptionController,
                          maxLines: 2,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 976 : double.infinity,
                        child: buildTextField(
                          label: 'Comments/Special Instruction',
                          controller: commentsController,
                          requiredField: false,
                          maxLines: 2,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 480 : double.infinity,
                        child: buildTextField(
                          label: 'Hazardous Cargo Type',
                          controller: hazardousCargoTypeController,
                          requiredField: false,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 240 : double.infinity,
                        child: buildTextField(
                          label: 'UN',
                          controller: unNumberController,
                          requiredField: false,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 240 : double.infinity,
                        child: buildTextField(
                          label: 'Tremcard',
                          controller: tremcardController,
                          requiredField: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: isWideScreen ? 250 : double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: updateWaybill,
                      icon: const Icon(Icons.save),
                      label: const Text('Update Waybill'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
