import 'package:flutter/material.dart';
import 'package:test_bill/core/constants/colors.dart';
import 'package:test_bill/models/nav_item.dart';
import 'package:test_bill/theme/colors.dart';


import '../billing/billing_page.dart';

class NavTile extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const NavTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Tooltip(
            message: collapsed ? item.label : '',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 14, vertical: 11),
              decoration: BoxDecoration(
                color: selected ? AppColors.kSidebarActive.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: selected
                    ? const Border(left: BorderSide(color: AppColors.kSidebarActive, width: 3))
                    : const Border(),
              ),
              child: collapsed
                  ? Center(
                      child: Icon(
                        item.icon,
                        color: selected ? kBlue : AppColors.kSidebarText,
                        size: 22,
                      ),
                    )
                  : Row(
                      children: [
                        Icon(
                          item.icon,
                          color: selected ? kBlue : AppColors.kSidebarText,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? kWhite : AppColors.kSidebarText,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        if (item.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: kBlue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item.badge!,
                              style: const TextStyle(color: kWhite, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
