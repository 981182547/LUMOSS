import 'package:flutter/material.dart';

import '../theme.dart';

enum AppTab {
  control('控制', Icons.tune_rounded),
  scenes('场景', Icons.grid_view_rounded),
  create('创作', Icons.brush_rounded),
  car('车灯', Icons.directions_car_rounded);

  final String label;
  final IconData icon;
  const AppTab(this.label, this.icon);
}

/// 页面内容底部要留出的空间,避免被浮动底栏遮住
const bottomBarSpace = 92.0;

class MainScaffold extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final Widget child;

  const MainScaffold({
    super.key,
    required this.current,
    required this.onSelect,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: appBackground,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomBar(current: current, onSelect: onSelect),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  const _BottomBar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: glassBorder, width: 0.8),
        ),
        child: Row(
          children: AppTab.values.map((tab) {
            final selected = tab == current;
            return Expanded(
              flex: selected ? 16 : 10,
              child: GestureDetector(
                onTap: () => onSelect(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    gradient: selected ? brandGradient : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tab.icon,
                          size: 20,
                          color: selected ? Colors.white : textSecondary),
                      if (selected) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tab.label,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
