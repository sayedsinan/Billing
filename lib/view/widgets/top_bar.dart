import 'package:flutter/material.dart';
import 'package:test_bill/view/attendance/attendance_page.dart';
import 'package:test_bill/view/billing/billing_page.dart';

class TopBar extends StatelessWidget {
  final String title;
  const TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: kWhite,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kTextDark,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // Search bar
          Container(
            width: 240,
            height: 38,
            decoration: BoxDecoration(
              color: kBgGray,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDE3ED)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 10),
                Icon(Icons.search_rounded, color: kTextGray, size: 18),
                SizedBox(width: 8),
                Text('Search...', style: TextStyle(color: kTextGray, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Notifications
          Stack(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: kBgGray,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDDE3ED)),
                ),
                child: const Icon(Icons.notifications_none_rounded, color: kTextGray, size: 20),
              ),
              Positioned(
                top: 6, right: 6,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // New Bill CTA
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: kWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Bill', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
