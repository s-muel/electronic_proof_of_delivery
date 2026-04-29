import 'package:flutter/material.dart';
import '../models/waybill_model.dart';
import '../widgets/waybill_template_widget.dart';
import 'edit_waybill_screen.dart';
import '../services/waybill_service.dart';

class WaybillDetailsScreen extends StatefulWidget {
  final WaybillModel waybill;
  final int index;

  const WaybillDetailsScreen({
    super.key,
    required this.waybill,
    required this.index,
  });

  @override
  State<WaybillDetailsScreen> createState() => _WaybillDetailsScreenState();
}

class _WaybillDetailsScreenState extends State<WaybillDetailsScreen> {
  late WaybillModel currentWaybill;

  @override
  void initState() {
    super.initState();
    currentWaybill = widget.waybill;
  }

  void editWaybill() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditWaybillScreen(waybill: currentWaybill, index: widget.index),
      ),
    );

    if (result == true) {
      setState(() {
        currentWaybill = WaybillService.getAllWaybills()[widget.index];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = currentWaybill.status == 'Pending Delivery';

    return Scaffold(
      appBar: AppBar(
        title: Text('Waybill No: ${currentWaybill.waybillNumber}'),
        actions: [
          if (canEdit)
            TextButton.icon(
              onPressed: editWaybill,
              icon: const Icon(Icons.edit, color: Colors.blue),
              label: const Text('Edit', style: TextStyle(color: Colors.blue)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: const Color(0xFFE9EEF5),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: WaybillTemplateWidget(waybill: currentWaybill),
            ),
          ),
        ),
      ),
    );
  }
}
