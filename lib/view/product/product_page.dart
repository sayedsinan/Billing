import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/product_controller.dart';
import 'package:test_bill/models/product_model.dart';
import 'package:test_bill/theme/colors.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String _search = '';
  String? _filterCat;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ProductController>();

    return Scaffold(
      backgroundColor: kBgGray,
      body: Obx(() {
        final cats = controller.categories;
        final all = controller.products;
        final loading = controller.isLoading.value;
        final err = controller.error.value;

        final filtered = all.where((p) {
          final q = _search.toLowerCase();
          final ms =
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q);
          final mc = _filterCat == null || p.category == _filterCat;
          return ms && mc;
        }).toList();

        final Map<String, List<Product>> grouped = {};
        for (final p in filtered) {
          grouped.putIfAbsent(p.category, () => []).add(p);
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ── Toolbar ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          hintStyle: const TextStyle(
                            color: kTextGray,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: kTextGray,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: kBgGray,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                       const SizedBox(width: 12),
    // Chips scroll horizontally instead of overflowing when there
    // are many categories.
    Expanded(
      flex: 4,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(
              'All',
              _filterCat == null,
              () => setState(() => _filterCat = null),
            ),
            ...cats.map(
              (c) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _chip(
                  c,
                  _filterCat == c,
                  () => setState(() => _filterCat = c),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(width: 12),
    if (loading) const Spacer(),
                    if (loading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kBlue,
                        ),
                      )
                    else
                      Text(
                        '${all.length} products',
                        style: const TextStyle(color: kTextGray, fontSize: 12),
                      ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlue,
                        foregroundColor: kWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Add Product',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _openEditor(context, controller),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (err.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: kRed,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            err,
                            style: const TextStyle(color: kRed, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () => controller.fetchProducts(),
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              color: kRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Grid ─────────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  color: kBlue,
                  onRefresh: () async {
                    await controller.fetchProducts();
                    await controller.fetchCategories();
                  },
                  child: loading && all.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: kBlue),
                        )
                      : filtered.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_offer_outlined,
                                    color: kTextGray,
                                    size: 48,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No products found',
                                    style: TextStyle(
                                      color: kTextGray,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          children: grouped.entries
                              .map(
                                (e) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                        top: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: kBlue,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            e.key,
                                            style: const TextStyle(
                                              color: kTextDark,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${e.value.length} items',
                                            style: const TextStyle(
                                              color: kTextGray,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 220,
                                            mainAxisExtent: 130,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                          ),
                                      itemCount: e.value.length,
                                      itemBuilder: (_, i) => _ProductCard(
                                        product: e.value[i],
                                        onEdit: () => _openEditor(
                                          context,
                                          controller,
                                          existing: e.value[i],
                                        ),
                                        onDelete: () => _confirmDelete(
                                          context,
                                          controller,
                                          e.value[i],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _openEditor(
    BuildContext ctx,
    ProductController controller, {
    Product? existing,
  }) async {
    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) =>
          ProductEditorDialog(existing: existing, controller: controller),
    );
  }

  void _confirmDelete(
    BuildContext ctx,
    ProductController controller,
    Product p,
  ) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Product?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('"${p.name}" will be removed from the menu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: kWhite,
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await controller.removeProduct(p.id);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

Widget _chip(String label, bool active, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: active ? kBlue.withOpacity(0.12) : kBgGray,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? kBlue : Colors.transparent),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: active ? kBlue : kTextGray,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
);

// ─── Product Card ─────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit, onDelete;
  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kLightBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: kBlue,
                    size: 18,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: kBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: kBlue,
                      size: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: kRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.delete_rounded,
                      color: kRed,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              style: const TextStyle(
                color: kTextDark,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: kBgGray,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.unit,
                    style: const TextStyle(color: kTextGray, fontSize: 10),
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: kBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Product Editor Dialog ────────────────────────────────────────────────────
class ProductEditorDialog extends StatefulWidget {
  final Product? existing;
  final ProductController controller;
  const ProductEditorDialog({
    super.key,
    this.existing,
    required this.controller,
  });

  @override
  State<ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<ProductEditorDialog> {
  late TextEditingController _name, _price, _unit, _desc, _catCtrl;
  String _category = 'Grocery';
  bool _customCat = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _price = TextEditingController(
      text: e != null ? e.price.toStringAsFixed(0) : '',
    );
    _unit = TextEditingController(text: e?.unit ?? 'pcs');
    _desc = TextEditingController(text: e?.description ?? '');
    _catCtrl = TextEditingController();
    final cats = widget.controller.categories;
    _category = e?.category ?? (cats.isNotEmpty ? cats.first : 'Grocery');
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _unit, _desc, _catCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter product name'),
          backgroundColor: kRed,
        ),
      );
      return;
    }
    final cat = _customCat ? _catCtrl.text.trim() : _category;
    // For a new product the id is assigned by the server; for an edit we
    // keep the existing id so the controller can PUT to the right endpoint.
    final p = Product(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      category: cat.isEmpty ? 'General' : cat,
      price: double.tryParse(_price.text) ?? 0,
      unit: _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
    );
    final ok = widget.existing == null
        ? await widget.controller.addProduct(p)
        : await widget.controller.updateProduct(p);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
Future<void> _bulkUpload(
  BuildContext ctx,
  ProductController controller,
) async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true, // ensures bytes are populated, required for web too
    );
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.single;
    final bytes = pickedFile.bytes;
    if (bytes == null) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Could not read file data'),
            backgroundColor: kRed,
          ),
        );
      }
      return;
    }
    final content = utf8.decode(bytes);

    final rows = Csv(lineDelimiter: '\n').decode(content);
    if (rows.isEmpty) return;

    final header = rows.first
        .map((e) => e.toString().trim().toLowerCase())
        .toList();
    final nameIdx = header.indexOf('name');
    final catIdx = header.indexOf('category');
    final priceIdx = header.indexOf('price');
    final unitIdx = header.indexOf('unit');
    final descIdx = header.indexOf('description');

    if (nameIdx == -1 || priceIdx == -1) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('CSV needs at least "name" and "price" columns'),
            backgroundColor: kRed,
          ),
        );
      }
      return;
    }

    final items = <Product>[];
    for (final row in rows.skip(1)) {
      if (row.length <= nameIdx) continue;
      final name = row[nameIdx].toString().trim();
      if (name.isEmpty) continue;
      items.add(
        Product(
          id: '',
          name: name,
          category:
              catIdx != -1 &&
                  row.length > catIdx &&
                  row[catIdx].toString().trim().isNotEmpty
              ? row[catIdx].toString().trim()
              : 'General',
          price: double.tryParse(row[priceIdx].toString()) ?? 0,
          unit:
              unitIdx != -1 &&
                  row.length > unitIdx &&
                  row[unitIdx].toString().trim().isNotEmpty
              ? row[unitIdx].toString().trim()
              : 'pcs',
          description:
              descIdx != -1 &&
                  row.length > descIdx &&
                  row[descIdx].toString().trim().isNotEmpty
              ? row[descIdx].toString().trim()
              : null,
        ),
      );
    }
    if (items.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Import Products?'),
        content: Text('${items.length} products found in CSV. Import all?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: kWhite,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await controller.bulkImportProducts(items);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${res['success']} products'
            '${res['failed']! > 0 ? ', ${res['failed']} failed' : ''}',
          ),
          backgroundColor: res['failed'] == 0 ? kGreen : kOrange,
        ),
      );
    }
  } catch (e, st) {
    debugPrint('Bulk upload error: $e\n$st');
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: kRed),
      );
    }
  }
}
    final isEdit = widget.existing != null;
    final cats = widget.controller.categories;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: kBlue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit_rounded : Icons.add_rounded,
                    color: kWhite,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'Edit Product' : 'Add Product to Menu',
                    style: const TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: kWhite),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lf('Product Name *', _name, hint: 'e.g. Wheat Flour 5kg'),
                  const SizedBox(height: 14),

                  const Text(
                    'Category',
                    style: TextStyle(
                      color: kTextGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!_customCat)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: cats.contains(_category)
                                ? _category
                                : (cats.isNotEmpty ? cats.first : null),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: kBgGray,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: cats
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _category = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => setState(() => _customCat = true),
                          child: const Text(
                            '+ New',
                            style: TextStyle(color: kBlue, fontSize: 12),
                          ),
                        ),
                        // next to "Add Product" button
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kBlue,
                            side: const BorderSide(color: kBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text(
                            'Bulk Upload',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => _bulkUpload(context, widget.controller),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _catCtrl,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'New category name...',
                              filled: true,
                              fillColor: kBgGray,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => setState(() => _customCat = false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _lf(
                          'Price (₹) *',
                          _price,
                          hint: '0',
                          kb: TextInputType.number,
                          num: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _lf('Unit', _unit, hint: 'pcs, kg, L, box...'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _lf(
                    'Description (optional)',
                    _desc,
                    hint: 'Short description or variant info',
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  Obx(
                    () => ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlue,
                        foregroundColor: kWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      icon: widget.controller.isSaving.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kWhite,
                              ),
                            )
                          : Icon(
                              isEdit ? Icons.save_rounded : Icons.add_rounded,
                              size: 18,
                            ),
                      label: Text(
                        isEdit ? 'Save' : 'Add to Menu',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: widget.controller.isSaving.value
                          ? null
                          : _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _lf(
  String label,
  TextEditingController ctrl, {
  String hint = '',
  TextInputType kb = TextInputType.text,
  bool num = false,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      label,
      style: const TextStyle(
        color: kTextGray,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    const SizedBox(height: 6),
    TextField(
      controller: ctrl,
      keyboardType: kb,
      inputFormatters: num
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : [],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
        filled: true,
        fillColor: kBgGray,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBlue, width: 1.5),
        ),
      ),
    ),
  ],
);
