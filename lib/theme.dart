import 'package:flutter/material.dart';

// 深色高级风(深色底 + 紫粉渐变 + 玻璃拟态),与原版配色一致
const accent = Color(0xFF7C5CFF); // 主色 · 紫
const accentPressed = Color(0xFF6A49F2);

// 紫 -> 粉 渐变
const gradA = Color(0xFF7C5CFF);
const gradB = Color(0xFFC24BE0);
const brandGradient = LinearGradient(colors: [gradA, gradB]);

const appBackground = Color(0xFF0E0D17); // 页面深底
const cardSurface = Color(0xFF1A1826); // 卡片(玻璃拟态基色)
const cardSurfaceAlt = Color(0xFF15141F); // 次级
const glassBorder = Color(0x14FFFFFF); // 卡片微光描边(白 8%)
const accentContainer = Color(0x267C5CFF); // 紫色低透明徽章底

const textPrimary = Color(0xFFF3F3F8); // 近白标题
const textSecondary = Color(0xFF9A98AD); // 淡紫灰说明
const onAccentContainer = Color(0xFFB9A9FF);

const panelBg = Color(0xFF08080D); // 灯板黑底(比页面更深)
const okGreen = Color(0xFF34D399);
const warnAmber = Color(0xFFF59E0B);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: appBackground,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      surface: cardSurface,
    ),
    fontFamily: null,
  );
}
