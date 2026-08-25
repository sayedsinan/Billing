import 'package:get/get.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/models/table_model.dart';
import 'package:test_bill/service/api_service.dart';

class TableController extends GetxController {
  final ApiService _api = ApiService.instance;

  final RxList<DiningTable> tables = <DiningTable>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchTables();
  }

  Future<void> fetchTables({String? search, TableStatus? status}) async {
    isLoading.value = true;
    error.value = '';
    try {
      final data = await _api.getTables(
        search: search,
        status: status != null ? tableStatusToString(status) : null,
      );
      tables.assignAll(data.map((e) => DiningTable.fromJson(e as Map<String, dynamic>)));
    } on ApiException catch (e) {
      error.value = e.message;
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addTable(String tableId, int seats) async {
    isSaving.value = true;
    try {
      final data = await _api.createTable(tableId, seats);
      tables.add(DiningTable.fromJson(data));
      return true;
    } on ApiException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Persists edits made in TableOrderDialog (seats, waiter, status, items).
  Future<bool> saveTable(DiningTable table) async {
    isSaving.value = true;
    try {
      final payload = table.toJson()..remove('tableId'); // immutable after creation
      final data = await _api.updateTable(table.id, payload);
      final updated = DiningTable.fromJson(data);
      final idx = tables.indexWhere((t) => t.id == updated.id);
      if (idx >= 0) {
        tables[idx] = updated;
      } else {
        tables.add(updated);
      }
      return true;
    } on ApiException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> setStatus(String tableMongoId, TableStatus status) async {
    try {
      final data = await _api.updateTableStatus(tableMongoId, tableStatusToString(status));
      final updated = DiningTable.fromJson(data);
      final idx = tables.indexWhere((t) => t.id == updated.id);
      if (idx >= 0) tables[idx] = updated;
      return true;
    } on ApiException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> removeTable(String tableMongoId) async {
    try {
      await _api.deleteTable(tableMongoId);
      tables.removeWhere((t) => t.id == tableMongoId);
      return true;
    } on ApiException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  /// Generates a bill for the table's current order. On success the table is
  /// flipped to `billing` locally (server does the same) so the UI reflects
  /// it immediately without a full refetch.
  Future<Bill?> generateBill(String tableMongoId, {double taxRate = 5, double discount = 0}) async {
    try {
      final data = await _api.generateTableBill(tableMongoId, taxRate: taxRate, discount: discount);
      final bill = Bill.fromJson(data);
      final idx = tables.indexWhere((t) => t.id == tableMongoId);
      if (idx >= 0) tables[idx] = tables[idx].copyWith(status: TableStatus.billing);
      return bill;
    } on ApiException catch (e) {
      Get.snackbar('Failed to generate bill', e.message, snackPosition: SnackPosition.BOTTOM);
      return null;
    }
  }
}