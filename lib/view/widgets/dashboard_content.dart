import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/bill_controller.dart';
import 'package:test_bill/models/bill_model.dart';
import 'package:test_bill/theme/colors.dart';
import 'package:test_bill/view/widgets/billing_row.dart';
import 'package:test_bill/view/widgets/section_card.dart';

enum _DashRange { today, yesterday, week, month, all }

class DashboardContent extends StatefulWidget {
  const DashboardContent();

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  late final BillController _billController;

  static const _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  bool _manualRefreshing = false;

  _DashRange _range = _DashRange.today;

  @override
  void initState() {
    super.initState();
    _billController = Get.find<BillController>();
    if (_billController.bills.isEmpty) {
      _billController.fetchBills();
    }
  }

  Future<void> _refresh() async {
    if (_manualRefreshing) return;
    setState(() => _manualRefreshing = true);
    try {
      await _billController.fetchBills();
    } finally {
      if (mounted) setState(() => _manualRefreshing = false);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeek(DateTime d) =>
      _startOfDay(d.subtract(Duration(days: d.weekday - 1)));

  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  /// Returns (start, end-exclusive) for the currently selected range.
  (DateTime, DateTime) _rangeBounds(_DashRange range, DateTime now) {
    switch (range) {
      case _DashRange.today:
        final s = _startOfDay(now);
        return (s, s.add(const Duration(days: 1)));
      case _DashRange.yesterday:
        final s = _startOfDay(now).subtract(const Duration(days: 1));
        return (s, s.add(const Duration(days: 1)));
      case _DashRange.week:
        final s = _startOfWeek(now);
        return (s, s.add(const Duration(days: 7)));
      case _DashRange.month:
        final s = _startOfMonth(now);
        final e = DateTime(s.year, s.month + 1, 1);
        return (s, e);
      case _DashRange.all:
        return (DateTime(2000), now.add(const Duration(days: 1)));
    }
  }

  /// Bounds of the period immediately preceding the current one, of the
  /// same length — used for the "+X% vs previous period" comparison.
  (DateTime, DateTime) _previousRangeBounds(_DashRange range, DateTime now) {
    final (start, end) = _rangeBounds(range, now);
    final length = end.difference(start);
    return (start.subtract(length), start);
  }

  List<Bill> _billsInRange(List<Bill> bills, DateTime start, DateTime end) =>
      bills
          .where(
            (b) => !b.createdAt.isBefore(start) && b.createdAt.isBefore(end),
          )
          .toList();

  String _rangeLabel(_DashRange range) {
    switch (range) {
      case _DashRange.today:
        return "Today";
      case _DashRange.yesterday:
        return "Yesterday";
      case _DashRange.week:
        return "This Week";
      case _DashRange.month:
        return "This Month";
      case _DashRange.all:
        return "All Time";
    }
  }

  String _comparisonLabel(_DashRange range) {
    switch (range) {
      case _DashRange.today:
        return 'vs yesterday';
      case _DashRange.yesterday:
        return 'vs day before';
      case _DashRange.week:
        return 'vs last week';
      case _DashRange.month:
        return 'vs last month';
      case _DashRange.all:
        return '';
    }
  }

  String _statusLabel(BillStatus status) {
    final name = status.name;
    return name.isEmpty ? 'Unknown' : name[0].toUpperCase() + name.substring(1);
  }

  List<double> _dailyTotals(List<Bill> bills, int days) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final day = now.subtract(Duration(days: days - 1 - i));
      return bills
          .where((b) => _isSameDay(b.createdAt, day))
          .fold(0.0, (s, b) => s + b.grandTotal);
    });
  }

  /// Aggregates qty sold per item name across the given bills.
  List<MapEntry<String, double>> _topItems(List<Bill> bills, {int limit = 5}) {
    final Map<String, double> qtyByName = {};
    for (final b in bills) {
      for (final item in b.items) {
        qtyByName[item.name] = (qtyByName[item.name] ?? 0) + item.qty;
      }
    }
    final sorted = qtyByName.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final allBills = _billController.bills;
      final loading = _billController.isLoadingBills.value;

      if (loading && allBills.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: kBlue));
      }

      if (allBills.isEmpty) {
        return _EmptyState(onRefresh: () => _billController.fetchBills());
      }

      final now = DateTime.now();

      // ── Filtered bills for the selected range, plus the previous period
      // of equal length so we can show a meaningful % comparison ──
      final (rangeStart, rangeEnd) = _rangeBounds(_range, now);
      final (prevStart, prevEnd) = _previousRangeBounds(_range, now);

      final rangeBills = _billsInRange(allBills, rangeStart, rangeEnd);
      final prevBills = _billsInRange(allBills, prevStart, prevEnd);

      final rangeSales = rangeBills.fold(0.0, (s, b) => s + b.grandTotal);
      final prevSales = prevBills.fold(0.0, (s, b) => s + b.grandTotal);

      final salesChangePct = prevSales == 0
          ? (rangeSales > 0 ? 100.0 : 0.0)
          : ((rangeSales - prevSales) / prevSales) * 100;

      final avgBillValue = rangeBills.isEmpty
          ? 0.0
          : rangeSales / rangeBills.length;

      // NOTE: assumes BillStatus has members literally named `pending` and
      // `overdue`. If your enum uses different names, change these two.
      final pendingBills = rangeBills
          .where((b) => b.status == BillStatus.pending)
          .toList();
      final overdueBills = rangeBills
          .where((b) => b.status == BillStatus.overdue)
          .toList();
      final pendingAmount = pendingBills.fold(0.0, (s, b) => s + b.grandTotal);
      final overdueAmount = overdueBills.fold(0.0, (s, b) => s + b.grandTotal);

      // Trend chart always shows the last 7 calendar days for context,
      // regardless of filter — so you can still see the shape of the week
      // even while looking at "This Month" totals above it.
      final daily = _dailyTotals(allBills, 7);
      final dailyMax = daily.fold(0.0, (m, v) => v > m ? v : m);

      final topItems = _topItems(rangeBills);
      final topItemsMaxQty = topItems.isEmpty ? 1.0 : topItems.first.value;

      final recentBills =
          (rangeBills.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
              .take(8)
              .toList();

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Range filter ────────────────────────────────────────────
            Row(
              children: [
                Text(
                  _rangeLabel(_range),
                  style: const TextStyle(
                    color: kTextDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                // ── Manual refresh button ───────────────────────────
                _manualRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kBlue,
                        ),
                      )
                    : InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _refresh,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: kBlue,
                          ),
                        ),
                      ),
                const Spacer(),
                _RangeChip(
                  'Today',
                  _range == _DashRange.today,
                  () => setState(() => _range = _DashRange.today),
                ),

                const SizedBox(width: 6),
                _RangeChip(
                  'Yesterday',
                  _range == _DashRange.yesterday,
                  () => setState(() => _range = _DashRange.yesterday),
                ),
                const SizedBox(width: 6),
                _RangeChip(
                  'This Week',
                  _range == _DashRange.week,
                  () => setState(() => _range = _DashRange.week),
                ),
                const SizedBox(width: 6),
                _RangeChip(
                  'This Month',
                  _range == _DashRange.month,
                  () => setState(() => _range = _DashRange.month),
                ),
                const SizedBox(width: 6),
                _RangeChip(
                  'All Time',
                  _range == _DashRange.all,
                  () => setState(() => _range = _DashRange.all),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Header stat strip (all driven by the selected range) ────
            Row(
              children: [
                _StatTile(
                  label: '${_rangeLabel(_range)} Sales',
                  value: '₹${rangeSales.toStringAsFixed(0)}',
                  sub: _comparisonLabel(_range).isEmpty
                      ? '${rangeBills.length} bills'
                      : '${salesChangePct >= 0 ? '+' : ''}${salesChangePct.toStringAsFixed(0)}% ${_comparisonLabel(_range)}',
                  icon: Icons.trending_up_rounded,
                  color: kGreen,
                ),
                const SizedBox(width: 16),
                _StatTile(
                  label: 'Bills',
                  value: '${rangeBills.length}',
                  sub: '${pendingBills.length} pending',
                  icon: Icons.receipt_long_rounded,
                  color: kBlue,
                ),
                const SizedBox(width: 16),
                _StatTile(
                  label: 'Avg Bill Value',
                  value: '₹${avgBillValue.toStringAsFixed(0)}',
                  sub: 'Per bill · ${_rangeLabel(_range).toLowerCase()}',
                  icon: Icons.calculate_rounded,
                  color: kDarkBlue,
                ),
                const SizedBox(width: 16),
                _StatTile(
                  label: 'Outstanding',
                  value:
                      '₹${(pendingAmount + overdueAmount).toStringAsFixed(0)}',
                  sub:
                      '${pendingBills.length + overdueBills.length} unpaid bills',
                  icon: Icons.error_outline_rounded,
                  color: kOrange,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── 7-day trend (context, not range-filtered) ────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales — Last 7 Days',
                    style: TextStyle(
                      color: kTextDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 110,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (i) {
                        final day = now.subtract(Duration(days: 6 - i));
                        final value = daily[i];
                        final height = dailyMax == 0
                            ? 4.0
                            : (value / dailyMax) * 78 + 4;
                        final isToday = _isSameDay(day, now);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (value > 0)
                                  Text(
                                    '₹${value.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isToday ? kBlue : kTextGray,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: height,
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? kBlue
                                        : kBlue.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _weekdayLabels[day.weekday - 1],
                                  style: TextStyle(
                                    color: isToday ? kBlue : kTextGray,
                                    fontSize: 10,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Recent bills for selected range ──────────────────────
                Expanded(
                  flex: 3,
                  child: SectionCard(
                    title: 'Bills · ${_rangeLabel(_range)}',
                    action: 'View All',
                    child: recentBills.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No bills in this period',
                                style: TextStyle(color: kTextGray),
                              ),
                            ),
                          )
                        : Column(
                            children: recentBills
                                .map(
                                  (b) => BillRow(
                                    '#${b.billNumber}',
                                    b.customerName?.trim().isNotEmpty == true
                                        ? b.customerName!
                                        : 'Walk-in Customer',
                                    '₹${b.grandTotal.toStringAsFixed(0)}',
                                    // _statusLabel(b.status),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
                const SizedBox(width: 20),

                // ── Top selling items for selected range ─────────────────
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Selling · ${_rangeLabel(_range)}',
                          style: const TextStyle(
                            color: kTextDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (topItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No item data in this period',
                              style: TextStyle(color: kTextGray, fontSize: 12),
                            ),
                          )
                        else
                          ...topItems.map((e) {
                            final qty = e.value == e.value.toInt()
                                ? e.value.toInt().toString()
                                : e.value.toStringAsFixed(1);
                            final ratio = e.value / topItemsMaxQty;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.key,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: kTextDark,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '$qty sold',
                                        style: const TextStyle(
                                          color: kTextGray,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 6,
                                      backgroundColor: kBgGray,
                                      valueColor: const AlwaysStoppedAnimation(
                                        kBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

// ── Filter chip ─────────────────────────────────────────────────────────
class _RangeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RangeChip(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kBlue.withOpacity(0.12) : kWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? kBlue : kBgGray),
          boxShadow: active
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
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
  }
}

// ── Compact stat tile used in the header strip ────────────────────────────
class _StatTile extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: kTextGray, fontSize: 11),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      color: kTextDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(color: color, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

// ── Empty state when there's no bill data at all yet ──────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined, color: kTextGray, size: 56),
          const SizedBox(height: 16),
          const Text(
            'No bills yet',
            style: TextStyle(
              color: kTextDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Once you create some bills, your dashboard will fill up here.',
            style: TextStyle(color: kTextGray, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
