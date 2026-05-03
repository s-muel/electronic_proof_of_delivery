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
    bool readOnly = false,
    IconData? icon,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: icon == null ? null : Icon(icon),
        filled: true,
        fillColor: readOnly ? const Color(0xFFEFF3F8) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> pickDate() async {
    final currentDate = DateTime.tryParse(dateController.text) ?? DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null) return;

    setState(() {
      dateController.text = _formatDate(selectedDate);
    });
  }

  Widget buildDateField() {
    return TextFormField(
      controller: dateController,
      readOnly: true,
      onTap: pickDate,
      decoration: InputDecoration(
        labelText: 'Date',
        helperText: 'Tap to select date',
        prefixIcon: const Icon(Icons.calendar_today),
        suffixIcon: IconButton(
          onPressed: pickDate,
          icon: const Icon(Icons.event),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Date is required';
        }

        return null;
      },
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE3E8EF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.blue, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(spacing: 16, runSpacing: 16, children: children),
          ],
        ),
      ),
    );
  }

  Widget _fieldBox({
    required bool isWideScreen,
    required Widget child,
    double? wideWidth,
  }) {
    return SizedBox(
      width: isWideScreen ? (wideWidth ?? 452) : double.infinity,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 750;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(
          'Edit Waybill ${widget.waybill.waybillNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172033),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEAF3FF), Color(0xFFFFFFFF)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFD8E7FB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.edit_document,
                            color: Colors.blue,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Edit Waybill',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF172033),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Update ${widget.waybill.waybillNumber} details before delivery is completed.',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionCard(
                    title: 'Reference Details',
                    icon: Icons.tag,
                    children: [
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        child: buildTextField(
                          label: 'BAJ Number',
                          controller: bajNumberController,
                          icon: Icons.confirmation_number,
                        ),
                      ),
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        child: buildTextField(
                          label: 'Waybill Number',
                          controller: waybillNumberController,
                          icon: Icons.receipt_long,
                        ),
                      ),
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        child: buildDateField(),
                      ),
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        child: buildTextField(
                          label: 'P.O. Number',
                          controller: poNumberController,
                          requiredField: false,
                          icon: Icons.assignment,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionCard(
                    title: 'Parties & Delivery',
                    icon: Icons.local_shipping,
                    children: [
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        child: buildTextField(
                          label: 'Shipping/Vendor',
                          controller: shippingVendorController,
                          icon: Icons.business,
                        ),
                      ),
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        child: buildTextField(
                          label: 'Consignee/Receiver',
                          controller: consigneeReceiverController,
                          icon: Icons.person,
                        ),
                      ),
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        child: buildTextField(
                          label: 'Other Delivery Address',
                          controller: deliveryAddressController,
                          requiredField: false,
                          icon: Icons.location_on,
                        ),
                      ),
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        child: buildTextField(
                          label: 'Vehicle Number',
                          controller: vehicleNumberController,
                          requiredField: false,
                          icon: Icons.directions_car,
                        ),
                      ),
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        child: buildTextField(
                          label: 'Driver Name',
                          controller: driverNameController,
                          requiredField: false,
                          icon: Icons.badge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionCard(
                    title: 'Cargo Details',
                    icon: Icons.inventory_2,
                    children: [
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        child: buildTextField(
                          label: 'Gross Weight',
                          controller: grossWeightController,
                          requiredField: false,
                          icon: Icons.scale,
                        ),
                      ),
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        wideWidth: isWideScreen ? 920 : null,
                        child: buildTextField(
                          label: 'Description of Cargo',
                          controller: cargoDescriptionController,
                          maxLines: 2,
                          icon: Icons.description,
                        ),
                      ),
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        wideWidth: isWideScreen ? 920 : null,
                        child: buildTextField(
                          label: 'Comments/Special Instruction',
                          controller: commentsController,
                          requiredField: false,
                          maxLines: 2,
                          icon: Icons.notes,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionCard(
                    title: 'Hazardous Cargo',
                    icon: Icons.warning_amber,
                    children: [
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        child: buildTextField(
                          label: 'Hazardous Cargo Type',
                          controller: hazardousCargoTypeController,
                          requiredField: false,
                          icon: Icons.dangerous,
                        ),
                      ),
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        wideWidth: 220,
                        child: buildTextField(
                          label: 'UN',
                          controller: unNumberController,
                          requiredField: false,
                          icon: Icons.pin,
                        ),
                      ),
                      _fieldBox(
                        isWideScreen: isWideScreen,
                        wideWidth: 220,
                        child: buildTextField(
                          label: 'Tremcard',
                          controller: tremcardController,
                          requiredField: false,
                          icon: Icons.article,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: isWideScreen ? 260 : double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: updateWaybill,
                        icon: const Icon(Icons.save),
                        label: const Text('Update Waybill'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
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
