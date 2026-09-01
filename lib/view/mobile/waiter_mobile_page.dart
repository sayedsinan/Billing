import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/auth_controller.dart';
import 'package:test_bill/controller/product_controller.dart';
import 'package:test_bill/controller/table_controller.dart';
import 'package:test_bill/core/constants/colors.dart';
import 'package:test_bill/models/product_model.dart';
import 'package:test_bill/models/table_model.dart';
import 'package:test_bill/view/login/login_screen.dart';
import 'package:test_bill/view/mobile/widgets/server_ip_dialog.dart';
import 'package:test_bill/view/mobile/widgets/waiter_order_sheet.dart';

class WaiterMobilePage extends StatefulWidget {
  const WaiterMobilePage({super.key});

  @override
  State<WaiterMobilePage> createState() => _WaiterMobilePageState();
}

class _WaiterMobilePageState extends State<WaiterMobilePage> with SingleTickerProviderStateMixin {
  final TableController _tableController = Get.find<TableController>();
  final ProductController _productController = Get.find<ProductController>();
  final AuthController _authController = Get.find<AuthController>();

  late TabController _tabController;
  DiningTable? _selectedTable;
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Local draft order items for the currently selected table
  final Map<String, List<OrderItem>> _draftOrders = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _productController.fetchProducts();
    _tableController.fetchTables();

    // Auto-select first table if available
    ever(_tableController.tables, (List<DiningTable> tables) {
      if (tables.isNotEmpty && _selectedTable == null) {
        setState(() {
          _selectedTable = tables.first;
          _syncDraftItemsWithTable(_selectedTable!);
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _syncDraftItemsWithTable(DiningTable table, {bool force = false}) {
    if (force || !_draftOrders.containsKey(table.id)) {
      _draftOrders[table.id] = table.items
          .map((i) => OrderItem(name: i.name, qty: i.qty, rate: i.rate))
          .toList();
    }
  }

  List<OrderItem> get _currentTableItems {
    if (_selectedTable == null) return [];
    return _draftOrders[_selectedTable!.id] ?? [];
  }

  void _addItemToCurrentTable(Product product) {
    if (_selectedTable == null) {
      Get.snackbar('Select Table', 'Please pick a table before adding items!', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() {
      final items = _draftOrders[_selectedTable!.id] ?? [];
      final idx = items.indexWhere((i) => i.name == product.name);
      if (idx >= 0) {
        items[idx].qty += 1;
      } else {
        items.add(OrderItem(name: product.name, qty: 1, rate: product.price));
      }
      _draftOrders[_selectedTable!.id] = items;
    });

    Get.snackbar(
      'Added ${product.name}',
      'Added to Table ${_selectedTable!.tableId}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      margin: const EdgeInsets.all(12),
    );
  }

  void _openServerIpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const ServerIpDialog(),
    ).then((updated) {
      if (updated == true) {
        _tableController.fetchTables();
        _productController.fetchProducts();
      }
    });
  }

  void _openOrderReviewSheet() {
    if (_selectedTable == null) return;

    // Attach current draft items to selected table
    final currentDraft = _currentTableItems;
    final tableWithDrafts = _selectedTable!.copyWith(items: currentDraft);

    showModalBottomSheet<List<OrderItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WaiterOrderSheet(table: tableWithDrafts),
    ).then((updatedItems) {
      if (updatedItems != null && _selectedTable != null) {
        setState(() {
          _draftOrders[_selectedTable!.id] = updatedItems;
        });
      }
      _tableController.fetchTables().then((_) {
        if (_selectedTable != null) {
          final refreshed = _tableController.tables.firstWhereOrNull((t) => t.id == _selectedTable!.id);
          if (refreshed != null) {
            setState(() {
              _selectedTable = refreshed;
            });
          }
        }
      });
    });
  }

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return AppColors.kGreen;
      case TableStatus.occupied:
        return Colors.orange.shade700;
      case TableStatus.billing:
        return AppColors.kBlue;
      case TableStatus.reserved:
        return Colors.purple;
      case TableStatus.cleaning:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authController.currentUser.value;
    final waiterName = user?['name']?.toString() ?? 'Waiter';

    return Scaffold(
      backgroundColor: AppColors.kBgGray,
      appBar: AppBar(
        backgroundColor: const Color(0xFF122540),
        elevation: 2,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.kBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.touch_app_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Waiter Order Mode',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Staff: $waiterName',
                    style: const TextStyle(fontSize: 11, color: AppColors.kSidebarText),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () {
              _authController.logout();
              Get.offAll(() => const LoginPage());
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.kBlue,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.kSidebarText,
          tabs: const [
            Tab(icon: Icon(Icons.table_restaurant_rounded), text: 'Tables Grid'),
            Tab(icon: Icon(Icons.menu_book_rounded), text: 'Menu & Ordering'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Active Selected Table Header Strip
          Obx(() {
            final tables = _tableController.tables;
            if (tables.isEmpty) return const SizedBox.shrink();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.table_restaurant_outlined, color: AppColors.kBlue, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Active Table: ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  DropdownButton<String>(
                    value: _selectedTable?.id,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.kBlue,
                      fontSize: 14,
                    ),
                    items: tables.map((t) {
                      return DropdownMenuItem<String>(
                        value: t.id,
                        child: Text('Table ${t.tableId} (${t.status.name.toUpperCase()})'),
                      );
                    }).toList(),
                    onChanged: (id) {
                      final found = tables.firstWhere((t) => t.id == id);
                      setState(() {
                        _selectedTable = found;
                        _syncDraftItemsWithTable(found);
                      });
                    },
                  ),
                  const Spacer(),
                  if (_selectedTable != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.kBlue,
                        side: const BorderSide(color: AppColors.kBlue),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _openOrderReviewSheet,
                      icon: const Icon(Icons.receipt_long_rounded, size: 14),
                      label: const Text('View Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_selectedTable!.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedTable!.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(_selectedTable!.status),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

          // Main View Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTablesGridTab(),
                _buildMenuOrderingTab(),
              ],
            ),
          ),
        ],
      ),

      // Floating Cart Action Bar
      bottomNavigationBar: _selectedTable == null
          ? null
          : Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2035),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.kBlue,
                      radius: 20,
                      child: Text(
                        '${_currentTableItems.fold<double>(0, (sum, i) => sum + i.qty).toInt()}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Table ${_selectedTable!.tableId} Order',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '₹${_currentTableItems.fold<double>(0, (sum, i) => sum + i.total).toStringAsFixed(2)}',
                            style: const TextStyle(color: AppColors.kGreen, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _openOrderReviewSheet,
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text('View Order', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _openOrderReviewSheet,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Send Order', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Tables View ─────────────────────────────────────────────────────────────
  Widget _buildTablesGridTab() {
    return Obx(() {
      if (_tableController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final tables = _tableController.tables;
      if (tables.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.table_restaurant_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No tables setup yet'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _tableController.fetchTables(),
                child: const Text('Refresh Tables'),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => _tableController.fetchTables(),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemCount: tables.length,
          itemBuilder: (ctx, i) {
            final t = tables[i];
            final isSelected = _selectedTable?.id == t.id;
            final color = _getStatusColor(t.status);

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedTable = t;
                  _syncDraftItemsWithTable(t);
                });
                _openOrderReviewSheet();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.kBlue : Colors.grey.shade200,
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Table ${t.tableId}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.kTextDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Seats: ${t.seats} • ${t.items.length} items',
                      style: const TextStyle(fontSize: 11, color: AppColors.kSubtext),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${t.subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.kBlue,
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTable = t;
                                  _syncDraftItemsWithTable(t);
                                });
                                _tabController.animateTo(1);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.kBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add_rounded, size: 16, color: AppColors.kBlue),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTable = t;
                                  _syncDraftItemsWithTable(t);
                                });
                                _openOrderReviewSheet();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.receipt_long_rounded, size: 16, color: Colors.orange.shade800),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }

  // ── Menu & Ordering View ──────────────────────────────────────────────────
  Widget _buildMenuOrderingTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search food or beverage item...',
              prefixIcon: const Icon(Icons.search_rounded),
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Category Filter Chips
        Obx(() {
          final categories = ['All', ..._productController.categories];
          return SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.kBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.kTextDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    backgroundColor: Colors.white,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              },
            ),
          );
        }),

        const SizedBox(height: 8),

        // Products List
        Expanded(
          child: Obx(() {
            if (_productController.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            final search = _searchController.text.trim().toLowerCase();
            final products = _productController.products.where((p) {
              final matchesSearch = search.isEmpty || p.name.toLowerCase().contains(search);
              final matchesCat = _selectedCategory == 'All' || p.category == _selectedCategory;
              return matchesSearch && matchesCat;
            }).toList();

            if (products.isEmpty) {
              return const Center(
                child: Text('No menu items found', style: TextStyle(color: AppColors.kSubtext)),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final p = products[i];

                // Check draft quantity added for selected table
                final currentItems = _currentTableItems;
                final existingIdx = currentItems.indexWhere((item) => item.name == p.name);
                final currentQty = existingIdx >= 0 ? currentItems[existingIdx].qty.toInt() : 0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.kBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fastfood_rounded, color: AppColors.kBlue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.kTextDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.category} • ₹${p.price.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.kSubtext),
                            ),
                          ],
                        ),
                      ),

                      // Add Item Button / Counter
                      if (currentQty > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.kGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$currentQty in cart',
                            style: const TextStyle(
                              color: AppColors.kGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _addItemToCurrentTable(p),
                        child: const Row(
                          children: [
                            Icon(Icons.add_rounded, size: 16),
                            SizedBox(width: 4),
                            Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
