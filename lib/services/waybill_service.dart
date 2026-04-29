import '../models/waybill_model.dart';

class WaybillService {
  static final List<WaybillModel> waybills = [];

  static void addWaybill(WaybillModel waybill) {
    waybills.add(waybill);
  }

  static List<WaybillModel> getAllWaybills() {
    return waybills;
  }

  static List<WaybillModel> getPendingWaybills() {
    return waybills
        .where((waybill) => waybill.status == 'Pending Delivery')
        .toList();
  }

  static List<WaybillModel> getDeliveredWaybills() {
    return waybills.where((waybill) => waybill.status == 'Delivered').toList();
  }

  static List<WaybillModel> getInvoicedWaybills() {
    return waybills.where((waybill) => waybill.status == 'Invoiced').toList();
  }

  static void updateWaybill(int index, WaybillModel updatedWaybill) {
    if (index >= 0 && index < waybills.length) {
      waybills[index] = updatedWaybill;
    }
  }
}
