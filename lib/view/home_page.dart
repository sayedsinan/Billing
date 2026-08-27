import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/auth_controller.dart';
import 'package:test_bill/models/nav_item.dart';
import 'package:test_bill/theme/colors.dart';
import 'package:test_bill/view/attendance/attendance_page.dart';
import 'package:test_bill/view/billing/billing_page.dart';
import 'package:test_bill/view/customers/customers_page.dart';
import 'package:test_bill/view/login/login_screen.dart';
import 'package:test_bill/view/product/product_page.dart';
import 'package:test_bill/view/reports/reports_page.dart';
import 'package:test_bill/view/settings/settings_page.dart';
import 'package:test_bill/view/stock/stock_page.dart';
import 'package:test_bill/view/transactions/transactions_page.dart';
import 'package:test_bill/view/widgets/dashboard_content.dart';
import 'package:test_bill/view/widgets/nav_tile.dart';
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
  final AuthController _authController = Get.find<AuthController>();

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to log out of your session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kRed,
              foregroundColor: AppColors.kWhite,
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _authController.logout();
              Get.offAll(() => const LoginPage());
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgGray,
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────
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
                  padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 8 : 16),
                  decoration: const BoxDecoration(color: Color(0xFF122540)),
                  child: _sidebarCollapsed
                      ? Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(
                              () => _sidebarCollapsed = !_sidebarCollapsed,
                            ),
                            child: Tooltip(
                              message: 'Expand Sidebar',
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.kBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.kWhite,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Row(
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
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Smart Billing',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.kWhite,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Text(
                                    'Bill Today, Grow Tomorrow',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.kSidebarText,
                                      fontSize: 9,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(
                                () => _sidebarCollapsed = !_sidebarCollapsed,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.chevron_left_rounded,
                                  color: AppColors.kSidebarText,
                                  size: 22,
                                ),
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
                Obx(() {
                  final user = _authController.currentUser.value;
                  final userName = user?['name']?.toString() ?? 'Admin';
                  final userRole = user?['role']?.toString().toUpperCase() ?? 'STAFF';

                  if (!_sidebarCollapsed) {
                    return Container(
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
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                              style: const TextStyle(
                                color: AppColors.kBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.kWhite,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  userRole,
                                  style: const TextStyle(
                                    color: AppColors.kSidebarText,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _confirmLogout,
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: AppColors.kSidebarText,
                              size: 18,
                            ),
                            tooltip: 'Logout',
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IconButton(
                      onPressed: _confirmLogout,
                      icon: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.kBlue.withOpacity(0.2),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                          style: const TextStyle(
                            color: AppColors.kBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      tooltip: 'Logout',
                    ),
                  );
                }),
              ],
            ),
          ),

          // ── Main Page View with IndexedStack for Zero-Lag Navigation ─────
          Expanded(
            child: Column(
              children: [
                TopBar(title: kNavItems[_selectedIndex].label),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: const [
                      DashboardContent(),  // Index 0
                      TableOrderPage(),    // Index 1
                      StockPage(),         // Index 2
                      ReportsPage(),       // Index 3
                      CustomersPage(),     // Index 4
                      ProductsPage(),      // Index 5
                      TransactionsPage(),  // Index 6
                      AttendancePage(),    // Index 7
                      SettingsPage(),      // Index 8
                    ],
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
