import 'package:flutter/material.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/service/api_service.dart';
import 'package:test_bill/service/print_service.dart';
import 'package:test_bill/theme/colors.dart';

enum SalesReportPreset { today, yesterday, thisMonth, custom }

/// Manual Sales Summary Report dialog:
/// Lets staff pick Today, Yesterday, This Month, or a Custom Date Range,
/// inspect total sales & most-sold items, and print a manual receipt copy.
class SalesReportPrintDialog extends StatefulWidget {
  final SalesReportPreset initialPreset;
  final DateTimeRange? initialCustomRange;

  const SalesReportPrintDialog({
    super.key,
    this.initialPreset = SalesReportPreset.today,
    this.initialCustomRange,
  });

  static Future<void> show(
    BuildContext context, {
    SalesReportPreset initialPreset = SalesReportPreset.today,
    DateTimeRange? initialCustomRange,
  }) {
    return showDialog(
      context: context,
      builder: (_) => SalesReportPrintDialog(
        initialPreset: initialPreset,
        initialCustomRange: initialCustomRange,
      ),
    );
  }

  @override
  State<SalesReportPrintDialog> createState() => _SalesReportPrintDialogState();
}

class _SalesReportPrintDialogState extends State<SalesReportPrintDialog> {
  late SalesReportPreset _preset;
  late DateTime _customStart;
  late DateTime _customEnd;

  bool _loading = true;
  bool _printing = false;
  bool _includeAllItems = false;
  String? _error;
  List<Bill> _bills = [];

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _preset = widget.initialPreset;
    _customStart = widget.initialCustomRange?.start ?? today;
    _customEnd = widget.initialCustomRange?.end ?? today;
    _loadSales();
  }

  (DateTime, DateTime) get _bounds {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (_preset) {
      case SalesReportPreset.today:
        return (
          todayStart,
          todayStart
              .add(const Duration(days: 1))
              .subtract(const Duration(milliseconds: 1)),
        );
      case SalesReportPreset.yesterday:
        final yStart = todayStart.subtract(const Duration(days: 1));
        return (
          yStart,
          todayStart.subtract(const Duration(milliseconds: 1)),
        );
      case SalesReportPreset.thisMonth:
        final mStart = DateTime(now.year, now.month, 1);
        final mEnd = DateTime(now.year, now.month + 1, 1)
            .subtract(const Duration(milliseconds: 1));
        return (mStart, mEnd);
      case SalesReportPreset.custom:
        final s = DateTime(
          _customStart.year,
          _customStart.month,
          _customStart.day,
        );
        final e = DateTime(_customEnd.year, _customEnd.month, _customEnd.day)
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        return (s, e);
    }
  }

  String get _periodLabel {
    switch (_preset) {
      case SalesReportPreset.today:
        return 'Today';
      case SalesReportPreset.yesterday:
        return 'Yesterday';
      case SalesReportPreset.thisMonth:
        return 'This Month';
      case SalesReportPreset.custom:
        return 'Custom Range';
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  String get _dateRangeLabel {
    final (start, end) = _bounds;
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    return sameDay ? _fmtDate(start) : '${_fmtDate(start)} - ${_fmtDate(end)}';
  }

  Future<void> _loadSales() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (from, to) = _bounds;
      final res = await ApiService.instance.getBills(from: from, to: to);
      final raw = (res['data'] as List<dynamic>? ?? []);
      final parsed = raw
          .map((e) => Bill.fromJson(e as Map<String, dynamic>))
          .where((b) {
            final dt = b.createdAt.toLocal();
            return !dt.isBefore(from) && !dt.isAfter(to);
          })
          .toList();
      if (!mounted) return;
      setState(() {
        _bills = parsed;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load sales: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(start: _customStart, end: _customEnd),
      helpText: 'Select Sales Report Date Range',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kBlue,
            onPrimary: kWhite,
            surface: kWhite,
            onSurface: kTextDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _preset = SalesReportPreset.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
      });
      await _loadSales();
    }
  }

  _SalesSummaryData _computeSummary() {
    int paidOrders = 0;
    int pendingOrders = 0;
    int cancelledOrders = 0;
    double totalRevenue = 0;
    double totalDiscount = 0;
    double totalItemsSold = 0;
    final Map<String, double> paymentBreakdown = {};
    final Map<String, Map<String, dynamic>> itemMap = {};

    for (final b in _bills) {
      if (b.status == BillStatus.cancelled) {
        cancelledOrders++;
        continue;
      }
      if (b.status == BillStatus.paid) {
        paidOrders++;
      } else {
        pendingOrders++;
      }

      final billNet = b.subtotal - b.discount;
      totalRevenue += billNet;
      totalDiscount += b.discount;

      final pm = b.paymentMethod.trim().isEmpty
          ? 'other'
          : b.paymentMethod.trim().toLowerCase();
      paymentBreakdown[pm] = (paymentBreakdown[pm] ?? 0) + billNet;

      for (final item in b.items) {
        totalItemsSold += item.qty;
        final existing = itemMap[item.name];
        if (existing != null) {
          existing['qty'] = (existing['qty'] as double) + item.qty;
          existing['total'] = (existing['total'] as double) + item.total;
        } else {
          itemMap[item.name] = {
            'name': item.name,
            'qty': item.qty,
            'rate': item.rate,
            'total': item.total,
          };
        }
      }
    }

    final itemSales = itemMap.values.toList()
      ..sort((a, b) {
        final cmpQty = (b['qty'] as num).compareTo(a['qty'] as num);
        if (cmpQty != 0) return cmpQty;
        return (b['total'] as num).compareTo(a['total'] as num);
      });

    return _SalesSummaryData(
      totalOrders: paidOrders + pendingOrders,
      paidOrders: paidOrders,
      pendingOrders: pendingOrders,
      cancelledOrders: cancelledOrders,
      totalRevenue: totalRevenue,
      totalDiscount: totalDiscount,
      totalItemsSold: totalItemsSold,
      paymentBreakdown: paymentBreakdown,
      itemSales: itemSales,
    );
  }

  Future<void> _printReport(_SalesSummaryData summary) async {
    setState(() => _printing = true);
    try {
      await PrintService.instance.printSalesSummaryReport(
        periodLabel: _periodLabel,
        dateRangeLabel: _dateRangeLabel,
        totalOrders: summary.totalOrders,
        paidOrders: summary.paidOrders,
        pendingOrders: summary.pendingOrders,
        cancelledOrders: summary.cancelledOrders,
        totalRevenue: summary.totalRevenue,
        totalDiscount: summary.totalDiscount,
        totalItemsSold: summary.totalItemsSold,
        paymentBreakdown: summary.paymentBreakdown,
        itemSales: summary.itemSales,
        includeAllItems: _includeAllItems,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sales report ($_dateRangeLabel) sent to printer'),
            backgroundColor: kGreen,
          ),
        );
      }
    } on PrintException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: kRed),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e'), backgroundColor: kRed),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  String _fmtQty(num q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final summary = _computeSummary();
    final mostSold = summary.itemSales.isNotEmpty
        ? summary.itemSales.first
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: const BoxDecoration(
                color: kBlue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.print_rounded, color: kWhite, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Print Sales Summary Report',
                          style: TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_periodLabel · $_dateRangeLabel',
                          style: TextStyle(
                            color: kWhite.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: kWhite),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Range Selector
                    const Text(
                      'Select Date Range',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kTextGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _presetChip('Today', SalesReportPreset.today),
                        _presetChip('Yesterday', SalesReportPreset.yesterday),
                        _presetChip('This Month', SalesReportPreset.thisMonth),
                        GestureDetector(
                          onTap: _pickCustomRange,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _preset == SalesReportPreset.custom
                                  ? kBlue
                                  : kBgGray,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: _preset == SalesReportPreset.custom
                                    ? kBlue
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.date_range_rounded,
                                  size: 14,
                                  color: _preset == SalesReportPreset.custom
                                      ? kWhite
                                      : kTextDark,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _preset == SalesReportPreset.custom
                                      ? _dateRangeLabel
                                      : 'Custom Date Range',
                                  style: TextStyle(
                                    color: _preset == SalesReportPreset.custom
                                        ? kWhite
                                        : kTextDark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 42),
                        child: Center(
                          child: CircularProgressIndicator(color: kBlue),
                        ),
                      )
                    else if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kRed.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
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
                                _error!,
                                style: const TextStyle(
                                  color: kRed,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadSales,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // KPI Summary Strip
                      Row(
                        children: [
                          _miniStat(
                            'Total Sales',
                            '${summary.totalOrders}',
                            '${summary.paidOrders} paid · ${summary.pendingOrders} pending',
                            kBlue,
                          ),
                          const SizedBox(width: 10),
                          _miniStat(
                            'Total Revenue',
                            '₹${summary.totalRevenue.toStringAsFixed(0)}',
                            'Avg ₹${summary.totalOrders > 0 ? (summary.totalRevenue / summary.totalOrders).toStringAsFixed(0) : '0'} / bill',
                            kGreen,
                          ),
                          const SizedBox(width: 10),
                          _miniStat(
                            'Items Sold',
                            '${_fmtQty(summary.totalItemsSold)} pcs',
                            '${summary.itemSales.length} menu items',
                            kOrange,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Most Sold Highlight Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kPurple.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kPurple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                color: kPurple,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'MOST SOLD ITEM',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: kPurple,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mostSold == null
                                        ? 'No sales in this period'
                                        : mostSold['name'].toString(),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: kTextDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (mostSold != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${_fmtQty(mostSold['qty'] as num)} sold',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: kPurple,
                                    ),
                                  ),
                                  Text(
                                    '₹${(mostSold['total'] as num).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: kGreen,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      // Payment Breakdown Chips
                      if (summary.paymentBreakdown.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: summary.paymentBreakdown.entries
                              .where((e) => e.value > 0)
                              .map((e) {
                                final label = e.key.isEmpty
                                    ? 'Other'
                                    : '${e.key[0].toUpperCase()}${e.key.substring(1)}';
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kBgGray,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$label: ₹${e.value.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: kTextDark,
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Top Selling Items Preview + Print Scope Toggle
                      Row(
                        children: [
                          Text(
                            'Items Sold Breakdown (${summary.itemSales.length})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: kTextDark,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _includeAllItems,
                                activeColor: kBlue,
                                visualDensity: VisualDensity.compact,
                                onChanged: (v) => setState(
                                  () => _includeAllItems = v ?? false,
                                ),
                              ),
                              const Text(
                                'Print all items (default: Top 10)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: kTextGray,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: kBgGray,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: summary.itemSales.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'No items sold during this period',
                                    style: TextStyle(
                                      color: kTextGray,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                itemCount: summary.itemSales.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, color: kWhite),
                                itemBuilder: (_, idx) {
                                  final item = summary.itemSales[idx];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 26,
                                          child: Text(
                                            '#${idx + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: idx == 0
                                                  ? kPurple
                                                  : kTextGray,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item['name'].toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: kTextDark,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${_fmtQty(item['qty'] as num)} sold',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: kBlue,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        SizedBox(
                                          width: 72,
                                          child: Text(
                                            '₹${(item['total'] as num).toStringAsFixed(0)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: kGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBlue,
                      foregroundColor: kWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: (_loading || _printing || _error != null)
                        ? null
                        : () => _printReport(summary),
                    icon: _printing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kWhite,
                            ),
                          )
                        : const Icon(Icons.print_rounded, size: 18),
                    label: Text(
                      _printing ? 'Printing...' : 'Print Sales Report',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _presetChip(String label, SalesReportPreset preset) {
    final active = _preset == preset;
    return GestureDetector(
      onTap: () {
        if (_preset == preset) return;
        setState(() => _preset = preset);
        _loadSales();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kBlue : kBgGray,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? kWhite : kTextDark,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, String sub, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: kTextGray),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesSummaryData {
  final int totalOrders;
  final int paidOrders;
  final int pendingOrders;
  final int cancelledOrders;
  final double totalRevenue;
  final double totalDiscount;
  final double totalItemsSold;
  final Map<String, double> paymentBreakdown;
  final List<Map<String, dynamic>> itemSales;

  const _SalesSummaryData({
    required this.totalOrders,
    required this.paidOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.totalRevenue,
    required this.totalDiscount,
    required this.totalItemsSold,
    required this.paymentBreakdown,
    required this.itemSales,
  });
}
