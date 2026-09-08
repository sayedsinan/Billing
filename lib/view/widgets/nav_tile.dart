import 'package:flutter/material.dart';
import 'package:test_bill/models/nav_item.dart';
import 'package:test_bill/theme/colors.dart';

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
    final activeColor = AppColors.kSidebarActive;
    final inactiveTextColor = AppColors.kSidebarText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Tooltip(
            message: collapsed ? item.label : '',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 8 : 12,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: selected ? activeColor.withOpacity(0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: selected
                    ? Border(left: BorderSide(color: activeColor, width: 4))
                    : const Border(left: BorderSide(color: Colors.transparent, width: 4)),
              ),
              child: collapsed
                  ? Center(
                      child: Icon(
                        item.icon,
                        color: selected ? activeColor : inactiveTextColor,
                        size: 22,
                      ),
                    )
                  : Row(
                      children: [
                        Icon(
                          item.icon,
                          color: selected ? activeColor : inactiveTextColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? Colors.white : inactiveTextColor,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        if (item.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: activeColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
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
