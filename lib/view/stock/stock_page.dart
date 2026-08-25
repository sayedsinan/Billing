import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Shared Colors ────────────────────────────────────────────────────────────
const kBlue = Color(0xFF2196F3);
const kDarkBlue = Color(0xFF1565C0);
const kLightBlue = Color(0xFFE3F2FD);
const kBgGray = Color(0xFFF5F7FA);
const kWhite = Colors.white;
const kTextDark = Color(0xFF1A2A3A);
const kTextGray = Color(0xFF6B7A8D);
const kGreen = Color(0xFF4CAF50);
const kOrange = Color(0xFFFF9800);
const kRed = Color(0xFFF44336);
const kPurple = Color(0xFF9C27B0);
const kTeal = Color(0xFF009688);
const kDivider = Color(0xFFEEF2F7);

// ─── Models ───────────────────────────────────────────────────────────────────
enum StockCategory { grocery, dairy, beverages, snacks, household, personal, other }

class StockItem {
  String id;
  String name;
  String sku;
  StockCategory category;
  double quantity;
  String unit; // kg, L, pcs, box, etc.
  double costPrice;
  double sellPrice;
  double lowStockThreshold;
  String supplier;
  DateTime lastUpdated;
  String? notes;

  StockItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.costPrice,
    required this.sellPrice,
    required this.lowStockThreshold,
    this.supplier = '',
    required this.lastUpdated,
    this.notes,
  });

  bool get isLow => quantity <= lowStockThreshold;
  bool get isOut => quantity == 0;
  double get margin => sellPrice > 0 ? ((sellPrice - costPrice) / sellPrice * 100) : 0;
  double get stockValue => quantity * costPrice;
}

// ─── Sample Data ──────────────────────────────────────────────────────────────
List<StockItem> _sampleStock() => [
  StockItem(id: 'S001', name: 'Wheat Flour 5kg', sku: 'WF-5KG', category: StockCategory.grocery, quantity: 3, unit: 'bag', costPrice: 200, sellPrice: 240, lowStockThreshold: 10, supplier: 'Aashirvaad Foods', lastUpdated: DateTime.now().subtract(const Duration(hours: 2))),
  StockItem(id: 'S002', name: 'Cooking Oil 1L', sku: 'CO-1L', category: StockCategory.grocery, quantity: 5, unit: 'bottle', costPrice: 150, sellPrice: 180, lowStockThreshold: 20, supplier: 'Fortune Edible', lastUpdated: DateTime.now().subtract(const Duration(hours: 5))),
  StockItem(id: 'S003', name: 'Basmati Rice 1kg', sku: 'BR-1KG', category: StockCategory.grocery, quantity: 2, unit: 'pack', costPrice: 80, sellPrice: 95, lowStockThreshold: 15, supplier: 'India Gate', lastUpdated: DateTime.now().subtract(const Duration(days: 1))),
  StockItem(id: 'S004', name: 'Sugar 1kg', sku: 'SG-1KG', category: StockCategory.grocery, quantity: 4, unit: 'pack', costPrice: 42, sellPrice: 50, lowStockThreshold: 25, supplier: 'Local Wholesale', lastUpdated: DateTime.now().subtract(const Duration(days: 1))),
  StockItem(id: 'S005', name: 'Toor Dal 500g', sku: 'TD-500G', category: StockCategory.grocery, quantity: 6, unit: 'pack', costPrice: 62, sellPrice: 75, lowStockThreshold: 30, supplier: 'Rajdhani', lastUpdated: DateTime.now().subtract(const Duration(days: 2))),
  StockItem(id: 'S006', name: 'Full Cream Milk 1L', sku: 'FM-1L', category: StockCategory.dairy, quantity: 25, unit: 'pouch', costPrice: 54, sellPrice: 62, lowStockThreshold: 10, supplier: 'Milma Kerala', lastUpdated: DateTime.now().subtract(const Duration(hours: 1))),
  StockItem(id: 'S007', name: 'Curd 400g', sku: 'CR-400G', category: StockCategory.dairy, quantity: 18, unit: 'cup', costPrice: 28, sellPrice: 35, lowStockThreshold: 5, supplier: 'Milma Kerala', lastUpdated: DateTime.now().subtract(const Duration(hours: 3))),
  StockItem(id: 'S008', name: 'Coca Cola 2L', sku: 'CC-2L', category: StockCategory.beverages, quantity: 32, unit: 'bottle', costPrice: 65, sellPrice: 80, lowStockThreshold: 10, supplier: 'Hindustan Coca-Cola', lastUpdated: DateTime.now().subtract(const Duration(days: 3))),
  StockItem(id: 'S009', name: 'Lays Classic 100g', sku: 'LC-100G', category: StockCategory.snacks, quantity: 0, unit: 'pack', costPrice: 15, sellPrice: 20, lowStockThreshold: 20, supplier: 'PepsiCo India', lastUpdated: DateTime.now().subtract(const Duration(days: 4))),
  StockItem(id: 'S010', name: 'Surf Excel 1kg', sku: 'SE-1KG', category: StockCategory.household, quantity: 14, unit: 'box', costPrice: 110, sellPrice: 130, lowStockThreshold: 5, supplier: 'HUL', lastUpdated: DateTime.now().subtract(const Duration(days: 2))),
  StockItem(id: 'S011', name: 'Colgate 200g', sku: 'CG-200G', category: StockCategory.personal, quantity: 22, unit: 'tube', costPrice: 88, sellPrice: 105, lowStockThreshold: 5, supplier: 'Colgate-Palmolive', lastUpdated: DateTime.now().subtract(const Duration(days: 5))),
  StockItem(id: 'S012', name: 'Maggi Noodles 70g', sku: 'MN-70G', category: StockCategory.snacks, quantity: 48, unit: 'pack', costPrice: 12, sellPrice: 15, lowStockThreshold: 20, supplier: 'Nestle India', lastUpdated: DateTime.now().subtract(const Duration(days: 1))),
];

// ─── Stock Page ───────────────────────────────────────────────────────────────
class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> with SingleTickerProviderStateMixin {
  late List<StockItem> _stock;
  String _search = '';
  StockCategory? _filterCat;
  String _filterLevel = 'all'; // all, low, out, ok
  int _sortCol = 0;
  bool _sortAsc = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _stock = _sampleStock();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<StockItem> get _filtered {
    var list = _stock.where((s) {
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.sku.toLowerCase().contains(q) ||
          s.supplier.toLowerCase().contains(q);
      final matchCat = _filterCat == null || s.category == _filterCat;
      final matchLevel = _filterLevel == 'all' ||
          (_filterLevel == 'out' && s.isOut) ||
          (_filterLevel == 'low' && s.isLow && !s.isOut) ||
          (_filterLevel == 'ok' && !s.isLow);
      return matchSearch && matchCat && matchLevel;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case 0: cmp = a.name.compareTo(b.name); break;
        case 1: cmp = a.category.name.compareTo(b.category.name); break;
        case 2: cmp = a.quantity.compareTo(b.quantity); break;
        case 3: cmp = a.sellPrice.compareTo(b.sellPrice); break;
        case 4: cmp = a.stockValue.compareTo(b.stockValue); break;
        default: cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  void _openEditor({StockItem? existing}) async {
    final result = await showDialog<StockItem>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StockEditorDialog(existing: existing),
    );
    if (result != null) {
      setState(() {
        if (existing != null) {
          final idx = _stock.indexWhere((s) => s.id == existing.id);
          if (idx >= 0) _stock[idx] = result;
        } else {
          _stock.insert(0, result);
        }
      });
    }
  }

  void _openAdjust(StockItem item) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => StockAdjustDialog(item: item),
    );
    if (result != null) {
      setState(() {
        final idx = _stock.indexWhere((s) => s.id == item.id);
        if (idx >= 0) {
          _stock[idx].quantity = (_stock[idx].quantity + result).clamp(0, double.infinity);
          _stock[idx].lastUpdated = DateTime.now();
        }
      });
    }
  }

  void _delete(StockItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remove "${item.name}" from stock permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: kWhite, elevation: 0),
            onPressed: () { setState(() => _stock.removeWhere((s) => s.id == item.id)); Navigator.pop(context); },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalItems = _stock.length;
    final lowCount = _stock.where((s) => s.isLow && !s.isOut).length;
    final outCount = _stock.where((s) => s.isOut).length;
    final totalValue = _stock.fold(0.0, (s, i) => s + i.stockValue);

    return Scaffold(
      backgroundColor: kBgGray,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary Cards ────────────────────────────────────────────
            Row(children: [
              _SCard('Total Products', '$totalItems', Icons.inventory_2_rounded, kBlue),
              const SizedBox(width: 16),
              _SCard('In Stock Value', '₹${_fmtVal(totalValue)}', Icons.account_balance_wallet_rounded, kGreen),
              const SizedBox(width: 16),
              _SCard('Low Stock', '$lowCount items', Icons.warning_amber_rounded, kOrange),
              const SizedBox(width: 16),
              _SCard('Out of Stock', '$outCount items', Icons.remove_circle_outline_rounded, kRed),
            ]),

            const SizedBox(height: 20),

            // ── Tabs ─────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Toolbar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(children: [
                      // Search
                      Expanded(
                        flex: 3,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search product, SKU, supplier...',
                            hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: kTextGray, size: 18),
                            filled: true,
                            fillColor: kBgGray,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          onChanged: (v) => setState(() => _search = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Level filter
                      _Chip('All', _filterLevel == 'all', () => setState(() => _filterLevel = 'all')),
                      const SizedBox(width: 6),
                      _Chip('Low Stock', _filterLevel == 'low', () => setState(() => _filterLevel = 'low'), color: kOrange),
                      const SizedBox(width: 6),
                      _Chip('Out of Stock', _filterLevel == 'out', () => setState(() => _filterLevel = 'out'), color: kRed),
                      const SizedBox(width: 6),
                      _Chip('In Stock', _filterLevel == 'ok', () => setState(() => _filterLevel = 'ok'), color: kGreen),
                      const Spacer(),
                      // Category dropdown
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: kBgGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<StockCategory?>(
                            value: _filterCat,
                            hint: const Text('All Categories', style: TextStyle(color: kTextGray, fontSize: 12)),
                            style: const TextStyle(color: kTextDark, fontSize: 12),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Categories')),
                              ...StockCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(_catName(c)))),
                            ],
                            onChanged: (v) => setState(() => _filterCat = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Add button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBlue, foregroundColor: kWhite, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w600)),
                        onPressed: () => _openEditor(),
                      ),
                    ]),
                  ),

                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: const BoxDecoration(color: kBgGray),
                    child: Row(children: [
                      _CH('Product', 0, flex: 4, sc: _sortCol, sa: _sortAsc, os: _onSort),
                      _CH('Category', 1, flex: 2, sc: _sortCol, sa: _sortAsc, os: _onSort),
                      _CH('Stock', 2, flex: 2, sc: _sortCol, sa: _sortAsc, os: _onSort),
                      const Expanded(flex: 2, child: Text('Threshold', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600))),
                      _CH('Price', 3, flex: 2, sc: _sortCol, sa: _sortAsc, os: _onSort),
                      _CH('Value', 4, flex: 2, sc: _sortCol, sa: _sortAsc, os: _onSort),
                      const Expanded(flex: 2, child: Text('Status', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600))),
                      const SizedBox(width: 110, child: Text('Actions', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600))),
                    ]),
                  ),

                  // Rows
                  SizedBox(
                    height: MediaQuery.of(context).size.height - 380,
                    child: filtered.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_outlined, color: kTextGray, size: 48),
                                SizedBox(height: 12),
                                Text('No products found', style: TextStyle(color: kTextGray, fontSize: 15)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: kDivider),
                            itemBuilder: (_, i) => _StockRow(
                              item: filtered[i],
                              onEdit: () => _openEditor(existing: filtered[i]),
                              onAdjust: () => _openAdjust(filtered[i]),
                              onDelete: () => _delete(filtered[i]),
                            ),
                          ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: const BoxDecoration(
                      color: kBgGray,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                    ),
                    child: Row(
                      children: [
                        Text('${filtered.length} products', style: const TextStyle(color: kTextGray, fontSize: 12)),
                        const Spacer(),
                        Text(
                          'Filtered value: ₹${_fmtVal(filtered.fold(0.0, (s, i) => s + i.stockValue))}',
                          style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
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

  void _onSort(int col) => setState(() {
    _sortCol == col ? _sortAsc = !_sortAsc : (_sortCol = col, _sortAsc = true);
  });
}

String _catName(StockCategory c) => switch (c) {
  StockCategory.grocery => 'Grocery',
  StockCategory.dairy => 'Dairy',
  StockCategory.beverages => 'Beverages',
  StockCategory.snacks => 'Snacks',
  StockCategory.household => 'Household',
  StockCategory.personal => 'Personal Care',
  StockCategory.other => 'Other',
};

Color _catColor(StockCategory c) => switch (c) {
  StockCategory.grocery => kGreen,
  StockCategory.dairy => const Color(0xFF00BCD4),
  StockCategory.beverages => kBlue,
  StockCategory.snacks => kOrange,
  StockCategory.household => kPurple,
  StockCategory.personal => const Color(0xFFE91E63),
  StockCategory.other => kTextGray,
};

String _fmtVal(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

// ─── Summary Card ─────────────────────────────────────────────────────────────
Widget _SCard(String label, String value, IconData icon, Color color) => Expanded(
  child: Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: kWhite,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: kTextGray, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(color: kTextDark, fontSize: 17, fontWeight: FontWeight.w700)),
      ]),
    ]),
  ),
);

// ─── Filter Chip ──────────────────────────────────────────────────────────────
Widget _Chip(String label, bool active, VoidCallback onTap, {Color color = kBlue}) =>
  GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.12) : kBgGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? color : Colors.transparent),
      ),
      child: Text(label, style: TextStyle(color: active ? color : kTextGray, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );

// ─── Column Header ────────────────────────────────────────────────────────────
Widget _CH(String label, int col, {required int flex, required int sc, required bool sa, required Function(int) os}) =>
  Expanded(
    flex: flex,
    child: GestureDetector(
      onTap: () => os(col),
      child: Row(children: [
        Text(label, style: const TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Icon(
          sc == col ? (sa ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded,
          size: 13,
          color: sc == col ? kBlue : kTextGray,
        ),
      ]),
    ),
  );

// ─── Stock Row ────────────────────────────────────────────────────────────────
class _StockRow extends StatelessWidget {
  final StockItem item;
  final VoidCallback onEdit, onAdjust, onDelete;
  const _StockRow({required this.item, required this.onEdit, required this.onAdjust, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final stockColor = item.isOut ? kRed : item.isLow ? kOrange : kGreen;
    final pct = (item.quantity / (item.lowStockThreshold * 2)).clamp(0.0, 1.0);
    final catColor = _catColor(item.category);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        // Product
        Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Row(children: [
            Text(item.sku, style: const TextStyle(color: kTextGray, fontSize: 11)),
            if (item.supplier.isNotEmpty) ...[
              const Text(' · ', style: TextStyle(color: kTextGray, fontSize: 11)),
              Text(item.supplier, style: const TextStyle(color: kTextGray, fontSize: 11)),
            ],
          ]),
        ])),

        // Category
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(_catName(item.category), style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.w600)),
        )),

        // Stock qty + bar
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${item.quantity} ${item.unit}', style: TextStyle(color: stockColor, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation(stockColor),
            ),
          ),
        ])),

        // Threshold
        Expanded(flex: 2, child: Text('${item.lowStockThreshold} ${item.unit}', style: const TextStyle(color: kTextGray, fontSize: 12))),

        // Price
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('₹${item.sellPrice.toStringAsFixed(0)}', style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 13)),
          Text('Cost: ₹${item.costPrice.toStringAsFixed(0)}', style: const TextStyle(color: kTextGray, fontSize: 11)),
        ])),

        // Stock value
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('₹${_fmtVal(item.stockValue)}', style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w600, fontSize: 13)),
          Text('${item.margin.toStringAsFixed(0)}% margin', style: TextStyle(color: item.margin > 20 ? kGreen : kOrange, fontSize: 11)),
        ])),

        // Status badge
        Expanded(flex: 2, child: _StatusBadge(item)),

        // Actions
        SizedBox(width: 110, child: Row(children: [
          _ActionBtn(Icons.add_rounded, kGreen, onAdjust, tooltip: 'Adjust Stock'),
          const SizedBox(width: 6),
          _ActionBtn(Icons.edit_rounded, kBlue, onEdit, tooltip: 'Edit'),
          const SizedBox(width: 6),
          _ActionBtn(Icons.delete_rounded, kRed, onDelete, tooltip: 'Delete'),
        ])),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final StockItem item;
  const _StatusBadge(this.item);

  @override
  Widget build(BuildContext context) {
    final (label, color) = item.isOut
        ? ('Out of Stock', kRed)
        : item.isLow
            ? ('Low Stock', kOrange)
            : ('In Stock', kGreen);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

Widget _ActionBtn(IconData icon, Color color, VoidCallback onTap, {String tooltip = ''}) => Tooltip(
  message: tooltip,
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(7),
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, color: color, size: 15),
    ),
  ),
);

// ─── Stock Adjust Dialog ──────────────────────────────────────────────────────
class StockAdjustDialog extends StatefulWidget {
  final StockItem item;
  const StockAdjustDialog({super.key, required this.item});

  @override
  State<StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<StockAdjustDialog> {
  final _ctrl = TextEditingController();
  String _type = 'add'; // add or remove

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final val = double.tryParse(_ctrl.text) ?? 0;
    final preview = _type == 'add'
        ? widget.item.quantity + val
        : (widget.item.quantity - val).clamp(0, double.infinity);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: kBlue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                const Icon(Icons.tune_rounded, color: kWhite, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Adjust Stock', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(widget.item.name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: kWhite), padding: EdgeInsets.zero),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                // Current stock display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: kBgGray, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Current Stock', style: TextStyle(color: kTextGray, fontSize: 13)),
                    Text('${widget.item.quantity} ${widget.item.unit}',
                        style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 16)),
                  ]),
                ),
                const SizedBox(height: 16),

                // Add / Remove toggle
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _type = 'add'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _type == 'add' ? kGreen.withOpacity(0.12) : kBgGray,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _type == 'add' ? kGreen : Colors.transparent),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_circle_rounded, color: _type == 'add' ? kGreen : kTextGray, size: 18),
                        const SizedBox(width: 6),
                        Text('Add Stock', style: TextStyle(color: _type == 'add' ? kGreen : kTextGray, fontWeight: FontWeight.w600, fontSize: 13)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _type = 'remove'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _type == 'remove' ? kRed.withOpacity(0.12) : kBgGray,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _type == 'remove' ? kRed : Colors.transparent),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.remove_circle_rounded, color: _type == 'remove' ? kRed : kTextGray, size: 18),
                        const SizedBox(width: 6),
                        Text('Remove Stock', style: TextStyle(color: _type == 'remove' ? kRed : kTextGray, fontWeight: FontWeight.w600, fontSize: 13)),
                      ]),
                    ),
                  )),
                ]),
                const SizedBox(height: 16),

                // Quantity input
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Quantity (${widget.item.unit})',
                    filled: true,
                    fillColor: kBgGray,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kBlue, width: 1.5),
                    ),
                    suffixText: widget.item.unit,
                  ),
                ),
                const SizedBox(height: 16),

                // Preview
                if (val > 0)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (_type == 'add' ? kGreen : kRed).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: (_type == 'add' ? kGreen : kRed).withOpacity(0.3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('New stock will be', style: TextStyle(color: kTextGray, fontSize: 13)),
                      Text('$preview ${widget.item.unit}',
                          style: TextStyle(
                            color: _type == 'add' ? kGreen : kRed,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          )),
                    ]),
                  ),
              ]),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _type == 'add' ? kGreen : kRed,
                    foregroundColor: kWhite, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: val <= 0 ? null : () => Navigator.pop(context, _type == 'add' ? val : -val),
                  child: Text(_type == 'add' ? 'Add Stock' : 'Remove Stock', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stock Editor Dialog ──────────────────────────────────────────────────────
class StockEditorDialog extends StatefulWidget {
  final StockItem? existing;
  const StockEditorDialog({super.key, this.existing});

  @override
  State<StockEditorDialog> createState() => _StockEditorDialogState();
}

class _StockEditorDialogState extends State<StockEditorDialog> {
  late TextEditingController _name, _sku, _qty, _unit, _cost, _sell, _threshold, _supplier, _notes;
  late StockCategory _category;
  static int _idCounter = 13;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _sku = TextEditingController(text: e?.sku ?? '');
    _qty = TextEditingController(text: e != null ? e.quantity.toString() : '0');
    _unit = TextEditingController(text: e?.unit ?? 'pcs');
    _cost = TextEditingController(text: e != null ? e.costPrice.toStringAsFixed(0) : '');
    _sell = TextEditingController(text: e != null ? e.sellPrice.toStringAsFixed(0) : '');
    _threshold = TextEditingController(text: e != null ? e.lowStockThreshold.toStringAsFixed(0) : '10');
    _supplier = TextEditingController(text: e?.supplier ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? StockCategory.grocery;
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _qty, _unit, _cost, _sell, _threshold, _supplier, _notes]) c.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter product name'), backgroundColor: kRed));
      return;
    }
    final id = widget.existing?.id ?? 'S${(_idCounter++).toString().padLeft(3, '0')}';
    Navigator.pop(context, StockItem(
      id: id,
      name: _name.text.trim(),
      sku: _sku.text.trim().isEmpty ? id : _sku.text.trim(),
      category: _category,
      quantity: double.tryParse(_qty.text) ?? 0,
      unit: _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
      costPrice: double.tryParse(_cost.text) ?? 0,
      sellPrice: double.tryParse(_sell.text) ?? 0,
      lowStockThreshold: double.tryParse(_threshold.text) ?? 10,
      supplier: _supplier.text.trim(),
      lastUpdated: DateTime.now(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final margin = () {
      final c = double.tryParse(_cost.text) ?? 0;
      final s = double.tryParse(_sell.text) ?? 0;
      return s > 0 ? ((s - c) / s * 100) : 0.0;
    }();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 580,
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
              child: Row(children: [
                Icon(isEdit ? Icons.edit_rounded : Icons.add_box_rounded, color: kWhite),
                const SizedBox(width: 10),
                Text(isEdit ? 'Edit Product' : 'Add New Product',
                    style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: kWhite), padding: EdgeInsets.zero),
              ]),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Name + SKU
                  Row(children: [
                    Expanded(flex: 3, child: _LF('Product Name *', _name, hint: 'e.g. Wheat Flour 5kg')),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _LF('SKU / Code', _sku, hint: 'e.g. WF-5KG')),
                  ]),
                  const SizedBox(height: 16),

                  // Category + Unit
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Category', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<StockCategory>(
                        value: _category,
                        decoration: InputDecoration(
                          filled: true, fillColor: kBgGray,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        items: StockCategory.values.map((c) =>
                          DropdownMenuItem(value: c, child: Text(_catName(c), style: const TextStyle(fontSize: 13)))
                        ).toList(),
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                    ])),
                    const SizedBox(width: 16),
                    Expanded(child: _LF('Unit', _unit, hint: 'kg, L, pcs, box...')),
                    const SizedBox(width: 16),
                    Expanded(child: _LF('Supplier', _supplier, hint: 'Supplier name')),
                  ]),
                  const SizedBox(height: 16),

                  // Qty + Threshold
                  Row(children: [
                    Expanded(child: _LF('Current Qty *', _qty, hint: '0', kb: TextInputType.number, num: true)),
                    const SizedBox(width: 16),
                    Expanded(child: _LF('Low Stock Alert', _threshold, hint: '10', kb: TextInputType.number, num: true)),
                  ]),
                  const SizedBox(height: 16),

                  // Cost + Sell price
                  Row(children: [
                    Expanded(child: _LF('Cost Price (₹)', _cost, hint: '0.00', kb: TextInputType.number, num: true, onChange: (_) => setState(() {}))),
                    const SizedBox(width: 16),
                    Expanded(child: _LF('Selling Price (₹)', _sell, hint: '0.00', kb: TextInputType.number, num: true, onChange: (_) => setState(() {}))),
                    const SizedBox(width: 16),
                    // Margin preview
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Profit Margin', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: margin > 20 ? kGreen.withOpacity(0.1) : kOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${margin.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: margin > 20 ? kGreen : kOrange,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ])),
                  ]),
                  const SizedBox(height: 16),

                  // Notes
                  _LF('Notes (optional)', _notes, hint: 'Storage instructions, expiry info, etc.'),
                ]),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue, foregroundColor: kWhite, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  icon: Icon(isEdit ? Icons.save_rounded : Icons.add_box_rounded, size: 18),
                  label: Text(isEdit ? 'Save Changes' : 'Add Product', style: const TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: _save,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _LF(String label, TextEditingController ctrl, {
  String hint = '',
  TextInputType kb = TextInputType.text,
  bool num = false,
  Function(String)? onChange,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(label, style: const TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    TextField(
      controller: ctrl,
      keyboardType: kb,
      onChanged: onChange,
      inputFormatters: num ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : [],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
        filled: true, fillColor: kBgGray,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBlue, width: 1.5),
        ),
      ),
    ),
  ],
);