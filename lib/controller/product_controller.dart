import 'package:get/get.dart';
import 'package:test_bill/models/product_model.dart';
import 'package:test_bill/service/api_service.dart';

class ProductController extends GetxController {
  final ApiService _api = ApiService.instance;

  final RxList<Product> products = <Product>[].obs;
  final RxList<String> categories = <String>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
    fetchCategories();
  }

  final RxInt bulkTotal = 0.obs;
  final RxInt bulkDone = 0.obs;
  final RxBool isBulkImporting = false.obs;


  Future<Map<String, int>> bulkImportProducts(List<Product> items) async {
    isBulkImporting.value = true;
    bulkTotal.value = items.length;
    bulkDone.value = 0;
    int success = 0, failed = 0;

    for (final p in items) {
      try {
        final data = await _api.createProduct({
          'name': p.name,
          'category': p.category,
          'price': p.price,
          'unit': p.unit,
          if (p.description != null) 'description': p.description,
        });
        products.add(Product.fromJson(data));
        success++;
      } catch (_) {
        failed++;
      } finally {
        bulkDone.value++;
      }
    }

    await fetchCategories();
    isBulkImporting.value = false;
    return {'success': success, 'failed': failed};
  }

  Future<void> fetchProducts({String? search, String? category}) async {
    isLoading.value = true;
    error.value = '';
    try {
      final data = await _api.getProducts(search: search, category: category);
      products.assignAll(
        data.map((e) => Product.fromJson(e as Map<String, dynamic>)),
      );
    } on ApiException catch (e) {
      error.value = e.message;
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchCategories() async {
    try {
      final data = await _api.getCategories();
      categories.assignAll(data);
    } on ApiException catch (e) {
      error.value = e.message;
    }
  }

  Future<bool> addProduct(Product p) async {
    isSaving.value = true;
    try {
      // The server assigns the id — never send a client-generated one.
      final payload = p.toJson()
        ..remove('id')
        ..remove('_id');
      final data = await _api.createProduct(payload);
      final created = Product.fromJson(data);
      products.add(created);
      if (!categories.contains(created.category))
        categories.add(created.category);
      return true;
    } on ApiException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> updateProduct(Product p) async {
    isSaving.value = true;
    try {
      final payload = p.toJson()
        ..remove('id')
        ..remove('_id');
      final data = await _api.updateProduct(p.id, payload);
      final updated = Product.fromJson(data);
      final idx = products.indexWhere((x) => x.id == updated.id);
      if (idx >= 0) products[idx] = updated;
      if (!categories.contains(updated.category))
        categories.add(updated.category);
      return true;
    } on ApiException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> removeProduct(String id) async {
    try {
      await _api.deleteProduct(id);
      products.removeWhere((p) => p.id == id);
      return true;
    } on ApiException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }
}
