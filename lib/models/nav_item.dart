import 'package:flutter/material.dart';

class NavItem {
  final IconData icon;
  final String label;
  final String? badge;
  const NavItem(this.icon, this.label, {this.badge});
}

const kNavItems = [
  NavItem(Icons.home_rounded, 'Dashboard'),
  NavItem(Icons.receipt_long_rounded, 'Billing', badge: 'New'),
  NavItem(Icons.inventory_2_rounded, 'Stock'),
  NavItem(Icons.bar_chart_rounded, 'Reports'),
  NavItem(Icons.people_rounded, 'Customers'),
  NavItem(Icons.local_offer_rounded, 'Products'),
  NavItem(Icons.swap_horiz_rounded, 'Transactions'),
  NavItem(Icons.support_agent_rounded, 'Support'),
  NavItem(Icons.settings_rounded, 'Settings'),
];