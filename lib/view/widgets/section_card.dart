import 'package:flutter/material.dart';
import 'package:test_bill/theme/colors.dart';

import '../billing/billing_page.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final String? action;
  final Widget child;

  const SectionCard({required this.title, this.action, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 15)),
              if (action != null)
                Text(action!, style: const TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
