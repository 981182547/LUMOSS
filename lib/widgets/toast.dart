import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// 轻量操作反馈。
///
/// 之前发送成功后界面毫无反应,用户不知道到底成没成 —— 尤其蓝牙这种
/// 看不见摸不着的通道,没有反馈就只能盯着灯板猜。
class Toast {
  static void success(BuildContext context, String msg) =>
      _show(context, msg, okGreen, Icons.check_circle_rounded, light: true);

  static void error(BuildContext context, String msg) => _show(
      context, msg, const Color(0xFFFF5A6E), Icons.error_outline_rounded);

  static void info(BuildContext context, String msg) =>
      _show(context, msg, accent, Icons.info_outline_rounded);

  static void _show(
    BuildContext context,
    String msg,
    Color color,
    IconData icon, {
    bool light = false,
  }) {
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: cardSurface,
          elevation: 0,
          duration: Duration(milliseconds: light ? 1400 : 2600),
          // 抬高一些,避开首页底部那条悬浮导航栏(高约 92)
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: glassBorder, width: 0.8),
          ),
          content: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(msg,
                    style: const TextStyle(
                        fontSize: 13, color: textPrimary, height: 1.35)),
              ),
            ],
          ),
        ),
      );
  }
}
