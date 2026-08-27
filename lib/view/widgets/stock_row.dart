import 'package:flutter/material.dart';
import 'package:test_bill/theme/colors.dart';
class StockRow extends StatelessWidget {
  final String name;
  final int current, max;
  const StockRow(this.name, this.current, this.max);

  @override
  Widget build(BuildContext context) {
    final pct = current / max;
    final color = pct < 0.2 ? kRed : pct < 0.4 ? kOrange : kGreen;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: kTextDark, fontSize: 12)),
              Text('$current/$max units', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
