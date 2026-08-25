import 'package:flutter/material.dart';
import 'package:test_bill/view/attendance/attendance_page.dart';

import '../billing/billing_page.dart';

class StatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color iconColor, iconBg;

  const StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: kTextGray, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: kTextDark, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(color: iconColor, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

