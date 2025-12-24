import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        color: const Color(0xFF04161D),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(
              iconPath: 'assets/icons_1/home.svg',
              index: 0,
            ),
            _buildNavItem(
              iconPath: 'assets/icons_1/calender.svg',
              index: 1,
            ),
            _buildNavItem(
              iconPath: 'assets/icons_1/search.svg',
              index: 2,
            ),
            _buildNavItem(
              iconPath: 'assets/icons_1/map.svg',
              index: 3,
            ),
            _buildNavItem(
              icon: Icons.folder_outlined,
              index: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({String? iconPath, IconData? icon, required int index}) {
    bool isSelected = selectedIndex == index;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.all(0),
      ),
      onPressed: () => onItemSelected(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconPath != null)
            SvgPicture.asset(
              iconPath,
              height: 26,
              colorFilter: const ColorFilter.mode(
                Color(0xff71C2E4),
                BlendMode.srcIn,
              ),
            )
          else if (icon != null)
            Icon(
              icon,
              size: 26,
              color: const Color(0xff71C2E4),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 2,
            width: isSelected ? 20 : 0,
            color: isSelected ? const Color(0xff71C2E4) : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
