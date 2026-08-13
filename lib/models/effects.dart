import 'dart:math' as math;

import 'led_matrix.dart';

/// 调色板:0=用户色 1=彩虹 2=火焰 3=海洋 4=糖果
class Palettes {
  static const count = 5;
  static const names = ['单色', '彩虹', '火焰', '海洋', '糖果'];

  static int color(int palette, int userColor, int pos) {
    switch (palette) {
      case 1:
        return hsv(pos);
      case 2: // 火焰:黑->红->橙->黄->白
        final p = pos & 0xFF;
        if (p < 64) return rgb(p * 4, 0, 0);
        if (p < 128) return rgb(255, (p - 64) * 3, 0);
        if (p < 192) return rgb(255, 192 + (p - 128), (p - 128) * 2);
        return rgb(255, 255, 128 + (p - 192) * 2);
      case 3: // 海洋:深蓝->青->白
        final p = pos & 0xFF;
        if (p < 128) return rgb(0, p, 128 + p ~/ 2);
        return rgb((p - 128) * 2, 128 + (p - 128), 255);
      case 4: // 糖果:低饱和彩虹
        return hsv(pos, 180, 255);
      default:
        return userColor;
    }
  }
}

class EffectDef {
  final int id;
  final String label;
  final String desc;
  const EffectDef(this.id, this.label, this.desc);
}

class Effects {
  static const all = <EffectDef>[
    EffectDef(0, '纯色', '静态单色'),
    EffectDef(1, '彩虹', '整屏彩虹流动'),
    EffectDef(2, '呼吸', '明暗渐变'),
    EffectDef(3, '流星', '拖尾扫过'),
    EffectDef(4, '火焰', '跳动火苗'),
    EffectDef(5, '等离子', '流体色块'),
    EffectDef(6, '星点', '随机闪烁'),
    EffectDef(7, '波浪', '正弦波纹'),
    EffectDef(8, '水波', '中心扩散'),
    EffectDef(9, '扫描', '来回扫描线'),
    EffectDef(10, '旋转', '旋转色轮'),
    EffectDef(11, '雨滴', '下落光点'),
  ];

  /// 渲染一帧。与固件端算法保持一致。
  /// [t] 已运行毫秒,[speed] 0..255,[intensity] 0..255
  static void render(
    Frame frame,
    int id,
    int t,
    int speed,
    int intensity,
    int color,
    int palette,
  ) {
    final w = frame.width;
    final h = frame.height;
    final spd = 0.2 + speed / 255.0 * 3.0;
    final phase = t * 0.05 * spd;
    final inten = intensity / 255.0;

    switch (id) {
      case 0:
        for (var i = 0; i < frame.pixels.length; i++) {
          frame.pixels[i] = color;
        }
        break;

      case 1:
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final pos = ((x + y) * 255 ~/ (w + h - 1) + phase.toInt()) & 0xFF;
            frame.set(x, y, Palettes.color(palette == 0 ? 1 : palette, color, pos));
          }
        }
        break;

      case 2:
        final b = (math.sin(phase * 0.08) * 0.5 + 0.5) * 0.85 + 0.15;
        final c = scaleColor(
          palette == 0
              ? color
              : Palettes.color(palette, color, (phase * 0.5).toInt()),
          b,
        );
        for (var i = 0; i < frame.pixels.length; i++) {
          frame.pixels[i] = c;
        }
        break;

      case 3: // 流星
        final total = w * h;
        final head = (phase * 2).toInt() % total;
        final tail = (6 + inten * 24).toInt();
        for (var i = 0; i < total; i++) {
          final d = ((head - i) + total) % total;
          final f = d < tail ? 1.0 - d / tail : 0.0;
          final c = palette == 0
              ? color
              : Palettes.color(palette, color, i * 255 ~/ total);
          frame.pixels[i] = scaleColor(c, f * f);
        }
        break;

      case 4: // 火焰
        for (var x = 0; x < w; x++) {
          for (var y = 0; y < h; y++) {
            final up = (h - 1 - y) / h;
            final n = _noise(x * 0.6, y * 0.35 - phase * 0.25);
            var heat = (up * 1.4 + n * 0.8 * inten - 0.35).clamp(0.0, 1.0);
            heat *= heat;
            frame.set(x, y, Palettes.color(2, color, (heat * 255).toInt()));
          }
        }
        break;

      case 5: // 等离子
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final v = math.sin(x * 0.5 + phase * 0.1) +
                math.sin(y * 0.4 - phase * 0.08) +
                math.sin((x + y) * 0.3 + phase * 0.06);
            final pos = (((v + 3) / 6) * 255).toInt();
            frame.set(x, y, Palettes.color(palette == 0 ? 1 : palette, color, pos));
          }
        }
        break;

      case 6: // 星点
        for (var i = 0; i < frame.pixels.length; i++) {
          frame.pixels[i] = 0xFF000000;
        }
        final n = (w * h * (0.05 + inten * 0.25)).toInt().clamp(1, w * h);
        final seed = (phase / 3).toInt();
        final rnd = math.Random(seed);
        for (var k = 0; k < n; k++) {
          final i = rnd.nextInt(w * h);
          final c = palette == 0
              ? color
              : Palettes.color(palette, color, rnd.nextInt(256));
          frame.pixels[i] = scaleColor(c, 0.4 + rnd.nextDouble() * 0.6);
        }
        break;

      case 7: // 波浪
        for (var x = 0; x < w; x++) {
          final waveY =
              (h / 2) + math.sin(x * 0.4 + phase * 0.1) * (h / 3) * (0.3 + inten);
          for (var y = 0; y < h; y++) {
            final d = (y - waveY).abs();
            final f = (1.0 - d / 2.5).clamp(0.0, 1.0);
            final c = palette == 0
                ? color
                : Palettes.color(palette, color, x * 255 ~/ w);
            frame.set(x, y, scaleColor(c, f));
          }
        }
        break;

      case 8: // 水波
        final cx = (w - 1) / 2.0;
        final cy = (h - 1) / 2.0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final d = _hypot(x - cx, y - cy);
            final v = math.sin(d * 1.2 - phase * 0.15);
            final vv = (v + 1) / 2;
            final f = vv * vv * (0.4 + inten * 0.6);
            final c = palette == 0
                ? color
                : Palettes.color(palette, color, (d * 20).toInt());
            frame.set(x, y, scaleColor(c, f));
          }
        }
        break;

      case 9: // 扫描(Knight Rider)
        final period = w * 2 - 2;
        final p = (phase * 0.6).toInt() % period;
        final sx = p < w ? p : period - p;
        final tail = 1 + inten * 3.0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final f = (1.0 - (x - sx).abs() / tail).clamp(0.0, 1.0);
            final c = palette == 0
                ? color
                : Palettes.color(palette, color, y * 255 ~/ h);
            frame.set(x, y, scaleColor(c, f));
          }
        }
        break;

      case 10: // 旋转色轮
        final cx = (w - 1) / 2.0;
        final cy = (h - 1) / 2.0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final ang = math.atan2(y - cy, x - cx);
            final pos = ((ang / math.pi * 128).toInt() + phase.toInt()) & 0xFF;
            frame.set(x, y, Palettes.color(palette == 0 ? 1 : palette, color, pos));
          }
        }
        break;

      case 11: // 雨滴
        for (var i = 0; i < frame.pixels.length; i++) {
          frame.pixels[i] = 0xFF000000;
        }
        final drops = (w * (0.3 + inten * 0.7)).toInt().clamp(1, w);
        for (var k = 0; k < drops; k++) {
          final rnd = math.Random(k * 7919);
          final col = rnd.nextInt(w);
          final off = rnd.nextDouble() * h;
          final yPos = ((phase * 0.3 + off) % (h + 4)) - 2;
          for (var tl = 0; tl <= 3; tl++) {
            final yy = (yPos - tl).toInt();
            if (yy >= 0 && yy < h) {
              final c = palette == 0
                  ? color
                  : Palettes.color(palette, color, col * 255 ~/ w);
              frame.set(col, yy, scaleColor(c, 1.0 - tl * 0.28));
            }
          }
        }
        break;

      default:
        for (var i = 0; i < frame.pixels.length; i++) {
          frame.pixels[i] = color;
        }
    }
  }

  static double _hypot(double a, double b) => math.sqrt(a * a + b * b);

  /// 轻量值噪声,固件端可用同一套
  static double _noise(double x, double y) {
    final xi = x.floorToDouble();
    final yi = y.floorToDouble();
    final xf = x - xi;
    final yf = y - yi;
    double hsh(double a, double b) {
      final n = math.sin(a * 12.9898 + b * 78.233) * 43758.545;
      return n - n.floorToDouble();
    }

    final u = xf * xf * (3 - 2 * xf);
    final v = yf * yf * (3 - 2 * yf);
    final a = hsh(xi, yi);
    final b = hsh(xi + 1, yi);
    final c = hsh(xi, yi + 1);
    final d = hsh(xi + 1, yi + 1);
    return (a + (b - a) * u) + ((c - a) * v * (1 - u)) + ((d - b) * u * v);
  }
}
