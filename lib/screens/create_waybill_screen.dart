import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../services/firestore_waybill_service.dart';
import '../services/waybill_service.dart';
import '../utils/platform_flags.dart';

class CreateWaybillScreen extends StatefulWidget {
  const CreateWaybillScreen({super.key});

  @override
  State<CreateWaybillScreen> createState() => _CreateWaybillScreenState();
}

class _CreateWaybillScreenState extends State<CreateWaybillScreen> {
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
    dateController.text = DateTime.now().toString().split(' ')[0];
    waybillNumberController.text = WaybillService.generateNextWaybillNumber();
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

  Future<void> saveWaybill() async {
    if (_formKey.currentState!.validate()) {
      var waybillNumber = waybillNumberController.text.trim();

      if (shouldUseFirestoreData) {
        try {
          waybillNumber =
              await FirestoreWaybillService.generateNextWaybillNumber();
          waybillNumberController.text = waybillNumber;
        } catch (_) {
          waybillNumber = waybillNumberController.text.trim();
        }
      }

      if (WaybillService.getIndexByWaybillNumber(waybillNumber) != -1) {
        waybillNumberController.text =
            WaybillService.generateNextWaybillNumber();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Waybill number already exists. New number assigned: ${waybillNumberController.text}',
            ),
          ),
        );
        return;
      }

      final now = DateTime.now().toIso8601String();

      final waybill = WaybillModel(
        bajNumber: bajNumberController.text.trim(),
        waybillNumber: waybillNumber,
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
        createdAt: now,
        updatedAt: now,
        hazardousCargoType: hazardousCargoTypeController.text.trim(),
        unNumber: unNumberController.text.trim(),
        tremcard: tremcardController.text.trim(),
      );

      await WaybillService.addWaybill(waybill);
      if (shouldUseFirestoreData) {
        try {
          await FirestoreWaybillService.createWaybill(waybill);
        } catch (_) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Waybill saved locally. It will need internet to sync online.',
              ),
            ),
          );
          Navigator.pop(context);
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waybill created successfully')),
      );

      Navigator.pop(context);
    }
  }

  Widget buildTextField({
    required String label,
    required TextEditingController controller,
    bool requiredField = true,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: readOnly,
        fillColor: readOnly ? const Color(0xFFEFF3F8) : null,
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
      appBar: AppBar(title: const Text('Create Waybill')),
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
                          readOnly: true,
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
                          maxLines: 3,
                        ),
                      ),
                      SizedBox(
                        width: isWideScreen ? 976 : double.infinity,
                        child: buildTextField(
                          label: 'Comments/Special Instruction',
                          controller: commentsController,
                          requiredField: false,
                          maxLines: 1,
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
                          label: 'UN Number',
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
                      onPressed: saveWaybill,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Waybill'),
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
