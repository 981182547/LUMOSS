import 'dart:math' as math;

import 'led_matrix.dart';
import 'pattern_paint.dart';

// ============================================================
// 高级 / 温馨 / 动物 三类动画。
//
// 设计前提:这是贴在车尾的竖屏(20 宽 × 40 高),看它的是后车的人。
// 所以"高级"不是炫技,是【克制】—— 慢速、渐变、留白、有呼吸感;
// 硬边实心色块在点阵屏上会显得廉价,一律用柔光叠加。
// 竖屏这个约束反而是优势:水母、气泡、花瓣、烛光天生就是竖着的。
// ============================================================

// ------------------------------------------------------------
// 高级
// ------------------------------------------------------------

/// 流光:一道柔和光带缓慢斜扫而过,像丝绸反光
void pxSilk(Painter p, int f, int c) {
  const n = 40;
  final t = f / n;
  for (var y = 0; y < p.h; y++) {
    for (var x = 0; x < p.w; x++) {
      // 斜向的带状高光
      final u = (x / p.w) * 0.35 + (y / p.h) * 0.65;
      final d = (u - (t * 1.6 - 0.3)).abs();
      final v = 1.0 - d / 0.22;
      if (v <= 0) continue;
      final e = v * v * v;
      // 底色是极暗的同色系,高光处才亮起来
      p.add(x, y, c, 0.06 + e * 0.94);
    }
  }
}

/// 呼吸:整屏在两个高级色之间缓慢呼吸(香槟金 ↔ 玫瑰金)
void pxBreath(Painter p, int f, int c) {
  const n = 60;
  final t = (math.sin(f / n * math.pi * 2) * 0.5 + 0.5);
  final champagne = rgb(255, 205, 140);
  final rose = rgb(230, 130, 150);
  final col = rgb(
    (((champagne >> 16) & 0xFF) * (1 - t) + ((rose >> 16) & 0xFF) * t).round(),
    (((champagne >> 8) & 0xFF) * (1 - t) + ((rose >> 8) & 0xFF) * t).round(),
    ((champagne & 0xFF) * (1 - t) + (rose & 0xFF) * t).round(),
  );
  // 中间亮、四周暗,形成柔和的光晕而不是死板的纯色块
  p.glow(0.5, 0.5, 0.95, col, intensity: 0.35 + t * 0.35, falloff: 1.4);
}

/// 气泡:细小光点缓缓上浮,像香槟里的气泡
void pxBubbles(Painter p, int f, int c) {
  const n = 60;
  for (var i = 0; i < 16; i++) {
    final rnd = math.Random(i * 3607);
    final x = 0.08 + rnd.nextDouble() * 0.84;
    final speed = 0.5 + rnd.nextDouble() * 0.9;
    final size = 0.02 + rnd.nextDouble() * 0.045;
    // 上浮时轻微左右摇摆
    final prog = ((f / n) * speed + rnd.nextDouble()) % 1.0;
    final y = 1.05 - prog * 1.1;
    final sway = math.sin(prog * math.pi * 4 + i) * 0.03;
    // 快到顶时淡出
    final fade = prog < 0.85 ? 1.0 : (1 - prog) / 0.15;
    p.glow(x + sway, y, size, c, intensity: 0.9 * fade, falloff: 1.6);
  }
}

/// 涟漪:水面滴落的同心圆,慢慢扩散消散
void pxRipple(Painter p, int f, int c) {
  const n = 50;
  final cx = 0.5, cy = 0.5;
  for (var k = 0; k < 3; k++) {
    final prog = ((f / n) + k / 3.0) % 1.0;
    final r = prog * 0.55;
    final alpha = (1 - prog) * (1 - prog);
    if (alpha < 0.02) continue;
    // 画一圈细环
    const steps = 90;
    for (var i = 0; i < steps; i++) {
      final a = i * math.pi * 2 / steps;
      p.glow(cx + math.cos(a) * r, cy + math.sin(a) * r * (p.w / p.h),
          0.035, c, intensity: alpha * 0.5, falloff: 2.2);
    }
  }
}

/// 星轨:星点绕中心缓慢旋转,拖出长曝光的轨迹
void pxStarTrail(Painter p, int f, int c) {
  const n = 80;
  final base = f / n * math.pi * 2;
  for (var i = 0; i < 10; i++) {
    final rnd = math.Random(i * 8191);
    final r = 0.12 + rnd.nextDouble() * 0.38;
    final a0 = rnd.nextDouble() * math.pi * 2;
    final hue = (rnd.nextInt(60) + 150) & 0xFF; // 蓝紫色系
    // 每颗星拖一段尾巴
    for (var k = 0; k < 10; k++) {
      final a = a0 + base * (0.5 + r) - k * 0.05;
      final x = 0.5 + math.cos(a) * r;
      final y = 0.5 + math.sin(a) * r * (p.w / p.h);
      p.glow(x, y, 0.026, hsv(hue, 150),
          intensity: (1 - k / 10) * 0.8, falloff: 2.0);
    }
  }
}

/// 水墨:一团颜色从中心慢慢晕开,边缘不规则
void pxInk(Painter p, int f, int c) {
  const n = 60;
  final prog = (f / n);
  final r = 0.12 + prog * 0.42;
  final fade = prog < 0.75 ? 1.0 : (1 - prog) / 0.25;
  const steps = 64;
  for (var i = 0; i < steps; i++) {
    final a = i * math.pi * 2 / steps;
    // 用噪声让边缘不规则,才像墨在纸上散开
    final wob = math.sin(a * 3 + prog * 4) * 0.05 +
        math.sin(a * 7 - prog * 3) * 0.03;
    final rr = r + wob;
    // 从中心到边缘铺满
    for (var s = 0; s <= 8; s++) {
      final t = s / 8;
      p.glow(0.5 + math.cos(a) * rr * t,
          0.5 + math.sin(a) * rr * t * (p.w / p.h), 0.09, c,
          intensity: (1 - t * 0.55) * 0.12 * fade, falloff: 1.5);
    }
  }
}

// ------------------------------------------------------------
// 温馨
// ------------------------------------------------------------

/// 萤火虫:暖黄光点随机飘动、明灭
void wmFirefly(Painter p, int f, int c) {
  const n = 70;
  final warm = rgb(255, 225, 120);
  for (var i = 0; i < 9; i++) {
    final rnd = math.Random(i * 2113);
    final ax = rnd.nextDouble(), ay = rnd.nextDouble();
    final sx = 0.10 + rnd.nextDouble() * 0.25;
    final sy = 0.12 + rnd.nextDouble() * 0.30;
    final t = f / n * math.pi * 2;
    // 用两个不同频率的正弦合成飘忽的轨迹
    final x = ax * 0.8 + 0.1 + math.sin(t * (0.6 + ax) + i) * sx * 0.5;
    final y = ay * 0.8 + 0.1 + math.cos(t * (0.5 + ay) + i * 2) * sy * 0.5;
    // 明灭:各自不同周期
    final blink = math.sin(t * (1.4 + rnd.nextDouble()) + i * 1.7);
    final b = blink > 0 ? blink * blink : 0.0;
    if (b < 0.03) continue;
    p.glow(x, y, 0.045, warm, intensity: b, falloff: 1.8);
  }
}

/// 暖阳:温暖的橙黄光晕缓慢脉动,像日落
void wmSunset(Painter p, int f, int c) {
  const n = 60;
  final t = (math.sin(f / n * math.pi * 2) * 0.5 + 0.5);
  // 背景:上暗紫、下暖橙
  p.vGradient(rgb(30, 12, 40), rgb(120, 40, 20));
  // 太阳缓慢起伏
  final sy = 0.62 - t * 0.05;
  p.glow(0.5, sy, 0.45, rgb(255, 140, 40), intensity: 0.55, falloff: 1.3);
  p.glow(0.5, sy, 0.20, rgb(255, 220, 150), intensity: 0.9, falloff: 1.6);
}

/// 花瓣:粉色花瓣缓缓飘落,带旋转
void wmPetals(Painter p, int f, int c) {
  const n = 80;
  final pink = rgb(255, 150, 185);
  for (var i = 0; i < 12; i++) {
    final rnd = math.Random(i * 5087);
    final speed = 0.5 + rnd.nextDouble() * 0.7;
    final prog = ((f / n) * speed + rnd.nextDouble()) % 1.0;
    final y = prog * 1.1 - 0.05;
    // 边落边左右摇摆,像真的花瓣
    final x = 0.1 + rnd.nextDouble() * 0.8 +
        math.sin(prog * math.pi * 3 + i) * 0.07;
    final fade = prog < 0.9 ? 1.0 : (1 - prog) / 0.1;
    p.glow(x, y, 0.045, pink, intensity: 0.85 * fade, falloff: 1.7);
  }
}

/// 烛光:一簇温暖火苗轻轻摇曳
void wmCandle(Painter p, int f, int c) {
  const n = 40;
  final t = f / n * math.pi * 2;
  // 蜡烛本体
  p.rect(0.38, 0.70, 0.24, 0.28, rgb(230, 220, 200));
  // 火苗:高度和左右都在轻微抖动
  final sway = math.sin(t * 1.7) * 0.02 + math.sin(t * 3.1) * 0.012;
  final tall = 0.16 + math.sin(t * 2.3) * 0.02;
  final baseY = 0.66;
  p.glow(0.5 + sway, baseY - tall * 0.2, tall * 1.5, rgb(255, 120, 20),
      intensity: 0.5, falloff: 1.4);
  p.glow(0.5 + sway, baseY - tall * 0.35, tall * 0.7, rgb(255, 210, 110),
      intensity: 0.95, falloff: 1.8);
  p.glow(0.5 + sway * 0.5, baseY - tall * 0.45, tall * 0.28,
      rgb(255, 255, 220), intensity: 1.0, falloff: 2.2);
  // 烛光洒在下方的暖晕
  p.glow(0.5, 0.88, 0.35, rgb(255, 150, 60), intensity: 0.18, falloff: 1.2);
}

/// 气球:彩色气球缓缓升空
void wmBalloons(Painter p, int f, int c) {
  const n = 90;
  const colors = [
    0xFFFF5A7A, 0xFFFFC24B, 0xFF5AD7FF, 0xFFB07CFF, 0xFF6BE58A,
  ];
  for (var i = 0; i < 5; i++) {
    final rnd = math.Random(i * 1471);
    final speed = 0.55 + rnd.nextDouble() * 0.6;
    final prog = ((f / n) * speed + i / 5.0) % 1.0;
    final y = 1.1 - prog * 1.2;
    final x = 0.15 + rnd.nextDouble() * 0.7 +
        math.sin(prog * math.pi * 2 + i) * 0.04;
    final col = colors[i % colors.length];
    // 气球本体 + 一点高光
    p.glow(x, y, 0.075, col, intensity: 0.9, falloff: 1.5);
    p.glow(x - 0.02, y - 0.02, 0.025, rgb(255, 255, 255),
        intensity: 0.35, falloff: 2.0);
    // 细线
    p.line(x, y + 0.055, x, y + 0.11, rgb(90, 80, 70));
  }
}

/// 雪夜的窗:雪花飘落,窗里透出暖光
void wmWinterWindow(Painter p, int f, int c) {
  const n = 80;
  // 夜空
  p.vGradient(rgb(8, 12, 30), rgb(20, 26, 52));
  // 窗户:暖黄的光
  p.rect(0.28, 0.58, 0.44, 0.30, rgb(255, 190, 90));
  p.rect(0.28, 0.58, 0.44, 0.30, rgb(120, 80, 30), fill: false);
  p.line(0.5, 0.58, 0.5, 0.88, rgb(120, 80, 30));
  p.line(0.28, 0.73, 0.72, 0.73, rgb(120, 80, 30));
  // 窗外洒出的光
  p.glow(0.5, 0.73, 0.42, rgb(255, 170, 60), intensity: 0.20, falloff: 1.2);
  // 雪
  for (var i = 0; i < 16; i++) {
    final rnd = math.Random(i * 3391);
    final speed = 0.4 + rnd.nextDouble() * 0.8;
    final prog = ((f / n) * speed + rnd.nextDouble()) % 1.0;
    final x = rnd.nextDouble() + math.sin(prog * math.pi * 2 + i) * 0.04;
    p.glow(x, prog, 0.022, rgb(230, 240, 255),
        intensity: 0.85, falloff: 1.8);
  }
}

// ------------------------------------------------------------
// 动物 —— 都按 20×40 竖屏构图
// ------------------------------------------------------------

/// 水母:伞盖收缩,触须飘动。竖屏的绝配
void anJellyfish(Painter p, int f, int c) {
  const n = 48;
  final t = f / n * math.pi * 2;
  final pulse = math.sin(t) * 0.5 + 0.5;
  final bell = 0.20 + pulse * 0.045;
  final cy = 0.30 - pulse * 0.03;
  final body = rgb(180, 130, 255);
  final tip = rgb(120, 230, 255);

  // 伞盖:多层柔光叠出通透感
  p.glow(0.5, cy, bell * 1.5, body, intensity: 0.25, falloff: 1.3);
  p.glow(0.5, cy, bell, body, intensity: 0.65, falloff: 1.6);
  p.glow(0.5, cy - bell * 0.25, bell * 0.5, rgb(230, 210, 255),
      intensity: 0.7, falloff: 2.0);

  // 触须:每根有自己的相位,飘起来才自然
  for (var i = 0; i < 5; i++) {
    final ox = -0.14 + i * 0.07;
    for (var s = 0; s < 14; s++) {
      final u = s / 13.0;
      final y = cy + bell * 0.7 + u * 0.48;
      final x = 0.5 + ox * (1 - u * 0.3) +
          math.sin(t * 1.2 + u * 3.4 + i) * 0.05 * u;
      final col = u < 0.6 ? body : tip;
      p.glow(x, y, 0.022, col, intensity: (1 - u * 0.7) * 0.8, falloff: 2.0);
    }
  }
}

/// 蝴蝶:扇动翅膀,翅膀是渐变彩色
void anButterfly(Painter p, int f, int c) {
  const n = 24;
  final t = f / n * math.pi * 2;
  // 扇动:翅膀横向压缩
  final open = 0.35 + (math.sin(t) * 0.5 + 0.5) * 0.65;
  final cy = 0.48 + math.sin(t) * 0.02;

  for (final side in [-1, 1]) {
    for (var i = 0; i < 26; i++) {
      final a = (i / 25.0) * math.pi;
      // 上翅大、下翅小
      for (final wing in [0, 1]) {
        final rx = (wing == 0 ? 0.30 : 0.20) * open;
        final ry = wing == 0 ? 0.16 : 0.12;
        final oy = wing == 0 ? -0.07 : 0.09;
        for (var s = 2; s <= 6; s++) {
          final u = s / 6.0;
          final x = 0.5 + side * math.cos(a) * rx * u;
          final y = cy + oy + math.sin(a) * ry * u * (wing == 0 ? -1 : 1);
          final hue = (20 + u * 120 + i * 3).toInt() & 0xFF;
          p.glow(x, y, 0.03, hsv(hue, 230),
              intensity: 0.30 * (1.1 - u * 0.4), falloff: 1.8);
        }
      }
    }
  }
  // 身体和触角
  p.rect(0.48, cy - 0.12, 0.04, 0.26, rgb(70, 50, 40));
  p.line(0.49, cy - 0.12, 0.43, cy - 0.20, rgb(70, 50, 40));
  p.line(0.51, cy - 0.12, 0.57, cy - 0.20, rgb(70, 50, 40));
}

/// 小鱼:从下往上游,尾巴摆动
void anFish(Painter p, int f, int c) {
  const n = 60;
  final prog = (f / n);
  final y = 1.05 - prog * 1.15;
  final t = f / n * math.pi * 2;
  final sway = math.sin(t * 4) * 0.04;
  final x = 0.5 + sway;
  final body = rgb(255, 150, 60);

  // 水:淡蓝背景 + 气泡
  p.vGradient(rgb(4, 14, 30), rgb(8, 30, 55));
  for (var i = 0; i < 6; i++) {
    final rnd = math.Random(i * 811);
    final bp = ((f / n) * (0.6 + rnd.nextDouble()) + rnd.nextDouble()) % 1.0;
    p.glow(rnd.nextDouble(), 1 - bp, 0.018, rgb(150, 210, 255),
        intensity: 0.35, falloff: 2.0);
  }

  // 鱼身
  p.glow(x, y, 0.10, body, intensity: 0.85, falloff: 1.6);
  p.glow(x, y - 0.02, 0.05, rgb(255, 220, 150), intensity: 0.7, falloff: 2.0);
  // 尾巴:跟着摆
  final tailSway = math.sin(t * 4 + 1.0) * 0.05;
  p.polygon([
    [x - 0.02, y + 0.07],
    [x + 0.02, y + 0.07],
    [x + 0.10 + tailSway, y + 0.16],
    [x - 0.10 + tailSway, y + 0.16],
  ], body);
  // 眼睛
  p.dot(x - 0.04, y - 0.03, rgb(20, 20, 20));
}

/// 猫咪:眨眼 + 耳朵轻动 + 尾巴摇
void anCat(Painter p, int f, int c) {
  const n = 60;
  final t = f / n * math.pi * 2;
  final orange = rgb(255, 165, 70);
  final cy = 0.40;

  // 耳朵:轻微抖动
  final ear = math.sin(t * 2) * 0.012;
  p.polygon([
    [0.24, cy - 0.06],
    [0.31, cy - 0.20 + ear],
    [0.40, cy - 0.07]
  ], orange);
  p.polygon([
    [0.76, cy - 0.06],
    [0.69, cy - 0.20 - ear],
    [0.60, cy - 0.07]
  ], orange);

  // 头
  p.glow(0.5, cy, 0.30, orange, intensity: 0.8, falloff: 1.4);

  // 眼睛:大部分时间睁着,偶尔眨一下
  final blink = (f % n) > n - 5;
  if (blink) {
    p.rect(0.32, cy - 0.02, 0.12, 0.018, rgb(40, 30, 20));
    p.rect(0.56, cy - 0.02, 0.12, 0.018, rgb(40, 30, 20));
  } else {
    p.glow(0.37, cy - 0.02, 0.05, rgb(90, 230, 140),
        intensity: 0.95, falloff: 2.2);
    p.glow(0.63, cy - 0.02, 0.05, rgb(90, 230, 140),
        intensity: 0.95, falloff: 2.2);
    p.dot(0.37, cy - 0.02, rgb(20, 20, 20));
    p.dot(0.63, cy - 0.02, rgb(20, 20, 20));
  }

  // 鼻子和胡须
  p.dot(0.5, cy + 0.07, rgb(255, 140, 170));
  p.line(0.20, cy + 0.05, 0.40, cy + 0.08, rgb(240, 230, 220));
  p.line(0.80, cy + 0.05, 0.60, cy + 0.08, rgb(240, 230, 220));

  // 身体 + 摇尾巴
  p.glow(0.5, 0.78, 0.26, orange, intensity: 0.6, falloff: 1.4);
  final tail = math.sin(t * 1.5);
  for (var s = 0; s < 9; s++) {
    final u = s / 8.0;
    p.glow(0.72 + u * 0.18 * (0.4 + tail * 0.6), 0.84 - u * 0.22 * (1 - u),
        0.028, orange, intensity: 0.75, falloff: 2.0);
  }
}

/// 鲸鱼:缓缓游动 + 喷水
void anWhale(Painter p, int f, int c) {
  const n = 70;
  final t = f / n * math.pi * 2;
  final blue = rgb(80, 150, 255);
  final cy = 0.55 + math.sin(t) * 0.03;

  p.vGradient(rgb(4, 10, 26), rgb(6, 24, 48));

  // 身体
  p.glow(0.48, cy, 0.30, blue, intensity: 0.75, falloff: 1.4);
  p.glow(0.44, cy + 0.05, 0.20, rgb(190, 225, 255),
      intensity: 0.45, falloff: 1.6);
  // 尾鳍
  final tail = math.sin(t * 1.4) * 0.05;
  p.polygon([
    [0.74, cy - 0.02],
    [0.94, cy - 0.12 + tail],
    [0.90, cy + 0.02],
    [0.94, cy + 0.12 + tail],
  ], blue);
  // 眼睛
  p.dot(0.34, cy - 0.03, rgb(15, 15, 25));

  // 喷水:周期性从头顶喷出
  final spout = (f % n) / n;
  if (spout < 0.42) {
    final sp = spout / 0.42;
    for (var i = 0; i < 9; i++) {
      final u = i / 8.0;
      final spread = u * 0.10 * sp;
      final y = cy - 0.16 - u * 0.22 * sp;
      p.glow(0.40 - spread, y, 0.022, rgb(200, 235, 255),
          intensity: (1 - u) * 0.8 * (1 - sp * 0.4), falloff: 2.0);
      p.glow(0.40 + spread, y, 0.022, rgb(200, 235, 255),
          intensity: (1 - u) * 0.8 * (1 - sp * 0.4), falloff: 2.0);
    }
  }
}

/// 小鸟:扇翅膀往上飞
void anBird(Painter p, int f, int c) {
  const n = 20;
  final t = f / n * math.pi * 2;
  final flap = math.sin(t);
  final cy = 0.5 - math.sin(t) * 0.03;
  final body = rgb(90, 200, 255);

  // 身体
  p.glow(0.5, cy, 0.11, body, intensity: 0.9, falloff: 1.6);
  // 翅膀:扇动
  for (final side in [-1, 1]) {
    for (var s = 1; s <= 8; s++) {
      final u = s / 8.0;
      final x = 0.5 + side * u * 0.34;
      final y = cy - flap * u * 0.16;
      p.glow(x, y, 0.035, body,
          intensity: (1 - u * 0.5) * 0.75, falloff: 1.8);
    }
  }
  // 尾巴和喙
  p.polygon([
    [0.46, cy + 0.08],
    [0.54, cy + 0.08],
    [0.50, cy + 0.17]
  ], body);
  p.polygon([
    [0.50, cy - 0.08],
    [0.54, cy - 0.13],
    [0.50, cy - 0.11]
  ], rgb(255, 190, 60));
  p.dot(0.53, cy - 0.05, rgb(20, 20, 20));
}
