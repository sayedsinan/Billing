import 'package:flutter/material.dart';
import 'package:test_bill/view/home_page.dart';

import '../../core/constants/colors.dart';

class BillRow extends StatelessWidget {
  final String id, customer, amount;
  const BillRow(this.id, this.customer, this.amount);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            id,
            style: const TextStyle(
              color: AppColors.kTextGray,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              customer,
              style: const TextStyle(color: AppColors.kTextDark, fontSize: 13),
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              color: AppColors.kTextDark,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
         
        ],
      ),
    );
  }
}
