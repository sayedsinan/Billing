import 'package:get/get.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/models/product_model.dart';
import 'package:test_bill/service/api_service.dart';
import 'package:test_bill/service/print_service.dart';

class BillController extends GetxController {
  final ApiService _api = ApiService.instance;
  final PrintService _printer = PrintService.instance;

  // ── Cart (running order before checkout) ────────────────────────────
  final RxList<CartItem> cart = <CartItem>[].obs;
  final RxDouble taxRate = 5.0.obs; // percent
  final RxDouble discount = 0.0.obs;

  double get cartSubtotal => cart.fold(0, (sum, item) => sum + item.total);
  double get cartTaxAmount => ((cartSubtotal - discount.value) * taxRate.value / 100);
  double get cartGrandTotal => cartSubtotal - discount.value + cartTaxAmount;
  int get cartItemCount => cart.fold(0, (sum, item) => sum + item.qty.toInt());

  void addToCart(Product product, {double qty = 1}) {
    final idx = cart.indexWhere((c) => c.product.id == product.id);
    if (idx >= 0) {
      cart[idx].qty += qty;
      cart.refresh();
    } else {
      cart.add(CartItem(product: product, qty: qty));
    }
  }

  void incrementQty(String productId) {
    final idx = cart.indexWhere((c) => c.product.id == productId);
    if (idx >= 0) {
      cart[idx].qty += 1;
      cart.refresh();
    }
  }

  void decrementQty(String productId) {
    final idx = cart.indexWhere((c) => c.product.id == productId);
    if (idx >= 0) {
      if (cart[idx].qty > 1) {
        cart[idx].qty -= 1;
        cart.refresh();
      } else {
        cart.removeAt(idx);
      }
    }
  }

  void removeFromCart(String productId) {
    cart.removeWhere((c) => c.product.id == productId);
  }

  /// Clears the cart so a brand-new bill can be started (counter sale).
  void clearCart() {
    cart.clear();
    discount.value = 0;
  }

  /// Resets everything needed to start a fresh bill after the current one
  /// has been paid/printed: clears the cart and forgets the last bill so
  /// the UI doesn't keep showing stale totals.
  void startNewBill() {
    clearCart();
    lastBill.value = null;
  }

  // ── Checkout ─────────────────────────────────────────────────────────
  final RxBool isCheckingOut = false.obs;
  final Rxn<Bill> lastBill = Rxn<Bill>();

  /// Builds a bill directly from the current cart (counter/retail sale).
  /// Returns the created [Bill] on success, or null on failure (a snackbar is shown).
  Future<Bill?> checkout({String? customerName}) async {
    if (cart.isEmpty) {
      Get.snackbar('Empty cart', 'Add at least one product before checking out',
          snackPosition: SnackPosition.BOTTOM);
      return null;
    }

    isCheckingOut.value = true;
    try {
      final items = cart
          .map((c) => {'productId': c.product.id, 'qty': c.qty})
          .toList();

      final data = await _api.createDirectBill(
        items: items,
        customerName: customerName,
        taxRate: taxRate.value,
        discount: discount.value,
      );

      final bill = Bill.fromJson(data);
      lastBill.value = bill;
      bills.insert(0, bill);
      clearCart();
      return bill;
    } on ApiException catch (e) {
      Get.snackbar('Checkout failed', e.message, snackPosition: SnackPosition.BOTTOM);
      return null;
    } finally {
      isCheckingOut.value = false;
    }
  }

  /// Generates a bill from a restaurant table's current order instead of the cart.
  Future<Bill?> checkoutTable(String tableMongoId, {double? taxRatePct, double? discountAmt}) async {
    isCheckingOut.value = true;
    try {
      final data = await _api.generateTableBill(
        tableMongoId,
        taxRate: taxRatePct ?? taxRate.value,
        discount: discountAmt ?? discount.value,
      );
      final bill = Bill.fromJson(data);
      lastBill.value = bill;
      bills.insert(0, bill);
      return bill;
    } on ApiException catch (e) {
      Get.snackbar('Failed to generate bill', e.message, snackPosition: SnackPosition.BOTTOM);
      return null;
    } finally {
      isCheckingOut.value = false;
    }
  }

  // ── Printing ─────────────────────────────────────────────────────────
  final RxBool isPrinting = false.obs;
  final RxString selectedPrinter = ''.obs;

  /// Loads the list of Windows printers available right now.
  Future<List<String>> availablePrinters() => _printer.getAvailablePrinters();

  /// Loads the saved printer (if any) into [selectedPrinter] so UI can show it.
  Future<void> loadSavedPrinter() async {
    final saved = _printer.savedPrinter ?? await _printer.resolvePrinter();
    selectedPrinter.value = saved ?? '';
  }

  /// Remembers which printer to use for future bills.
  Future<void> setPrinter(String printerName) async {
    await _printer.savePrinter(printerName);
    selectedPrinter.value = printerName;
  }

  /// Prints any bill. Returns true on success; shows a snackbar on failure.
  Future<bool> printBill(Bill bill) async {
    isPrinting.value = true;
    try {
      await _printer.printBill(
        bill,
        printerName: selectedPrinter.value.isEmpty ? null : selectedPrinter.value,
      );
      return true;
    } on PrintException catch (e) {
      Get.snackbar('Print failed', e.message, snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isPrinting.value = false;
    }
  }

  /// Convenience: print whatever bill was generated most recently.
  Future<bool> printLastBill() async {
    final bill = lastBill.value;
    if (bill == null) {
      Get.snackbar('Nothing to print', 'Generate a bill first', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return printBill(bill);
  }

  // ── Bill history ─────────────────────────────────────────────────────
  final RxList<Bill> bills = <Bill>[].obs;
  final RxBool isLoadingBills = false.obs;
  final RxDouble totalRevenue = 0.0.obs;

  Future<void> fetchBills({String? status, String? tableId, DateTime? from, DateTime? to}) async {
    isLoadingBills.value = true;
    try {
      final data = await _api.getBills(status: status, tableId: tableId, from: from, to: to);
      bills.assignAll(data.map((e) => Bill.fromJson(e as Map<String, dynamic>)));
    } on ApiException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoadingBills.value = false;
    }
  }

  Future<bool> payBill(String billId, String paymentMethod) async {
    try {
      final data = await _api.payBill(billId, paymentMethod);
      final updated = Bill.fromJson(data);
      final idx = bills.indexWhere((b) => b.id == updated.id);
      if (idx >= 0) bills[idx] = updated;
      if (lastBill.value?.id == updated.id) lastBill.value = updated;
      return true;
    } on ApiException catch (e) {
      Get.snackbar('Payment failed', e.message, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> cancelBill(String billId) async {
    try {
      final data = await _api.cancelBill(billId);
      final updated = Bill.fromJson(data);
      final idx = bills.indexWhere((b) => b.id == updated.id);
      if (idx >= 0) bills[idx] = updated;
      return true;
    } on ApiException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }
}