import 'package:flutter/material.dart';
import 'package:test_bill/models/nav_item.dart';
import 'package:test_bill/view/attendance/attendance_page.dart';
import 'package:test_bill/view/billing/billing_page.dart';

import 'package:test_bill/view/product/product_page.dart';
import 'package:test_bill/view/reports/reports_page.dart';
import 'package:test_bill/view/stock/stock_page.dart';
import 'package:test_bill/view/widgets/dashboard_content.dart';
import 'package:test_bill/view/widgets/nav_tile.dart';
import 'package:test_bill/view/widgets/placeholder.dart';
import 'package:test_bill/view/widgets/top_bar.dart';

import '../core/constants/colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgGray,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: _sidebarCollapsed ? 72 : 240,
            decoration: const BoxDecoration(
              color: AppColors.kSidebarBg,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo header
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(color: Color(0xFF122540)),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.kBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_rounded,
                          color: AppColors.kWhite,
                          size: 22,
                        ),
                      ),
                      if (!_sidebarCollapsed) ...[
                        const SizedBox(width: 12),
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Billing',
                              style: TextStyle(
                                color: AppColors.kWhite,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              'Bill Today, Grow Tomorrow',
                              style: TextStyle(
                                color: AppColors.kSidebarText,
                                fontSize: 9,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(
                          () => _sidebarCollapsed = !_sidebarCollapsed,
                        ),
                        child: Icon(
                          _sidebarCollapsed
                              ? Icons.chevron_right_rounded
                              : Icons.chevron_left_rounded,
                          color: AppColors.kSidebarText,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Nav items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    itemCount: kNavItems.length,
                    itemBuilder: (ctx, i) {
                      final item = kNavItems[i];
                      final selected = _selectedIndex == i;
                      return NavTile(
                        item: item,
                        selected: selected,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _selectedIndex = i),
                      );
                    },
                  ),
                ),

                // Bottom user card
                if (!_sidebarCollapsed)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2035),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.kBlue.withOpacity(0.2),
                          child: const Text(
                            'A',
                            style: TextStyle(
                              color: AppColors.kBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin',
                                style: TextStyle(
                                  color: AppColors.kWhite,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Super Admin',
                                style: TextStyle(
                                  color: AppColors.kSidebarText,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.logout_rounded,
                          color: AppColors.kSidebarText,
                          size: 18,
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor:AppColors. kBlue.withOpacity(0.2),
                      child: const Text(
                        'A',
                        style: TextStyle(
                          color: AppColors.kBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                // Top bar
                TopBar(title: kNavItems[_selectedIndex].label),
                // Page body
                Expanded(
                  child: _selectedIndex == 0
                      ? const DashboardContent()
                      : _selectedIndex == 1
                      ? const TableOrderPage()
                      : _selectedIndex == 2
                      ? const StockPage()
                      :   _selectedIndex == 3
                      ? const ReportsPage()
                      : _selectedIndex == 5
                      ? const ProductsPage()
                       : _selectedIndex == 7
                      ? const AttendancePage()
                      : PlaceholderContent(
                          label: kNavItems[_selectedIndex].label,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
