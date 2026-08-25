import 'package:flutter/material.dart';
import 'package:test_bill/view/attendance/attendance_page.dart';
import 'package:test_bill/view/billing/billing_page.dart';

class PlaceholderContent extends StatelessWidget {
  final String label;
  const PlaceholderContent({
    super.key,
    required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction_rounded, color: kBlue.withOpacity(0.3), size: 64),
          const SizedBox(height: 16),
          Text(
            '$label Page',
            style: const TextStyle(color: kTextDark, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('Content coming soon...', style: TextStyle(color: kTextGray)),
        ],
      ),
    );
  }
}