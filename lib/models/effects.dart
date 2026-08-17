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
    EffectDef(12, '极光', '绿紫色带飘动'),
    EffectDef(13, '数字雨', '绿色代码下落'),
    EffectDef(14, '岩浆灯', '暖色光团升腾'),
    EffectDef(15, '万花筒', '对称旋转花纹'),
    EffectDef(16, '星空', '闪烁星点与流星'),
    EffectDef(17, '霓虹', '青紫脉冲光环'),
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
    final total = w * h;

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

      case 12: // 极光:横向色带上下起伏,绿->青->紫
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final wave = math.sin(x * 0.30 + phase * 0.06) * 0.18 +
                math.sin(x * 0.13 - phase * 0.04) * 0.12;
            final band = (y / h) + wave;
            // 只在带内发光,上下留黑,才有"极光挂在夜空"的感觉
            final d = (band - 0.5).abs();
            var f = 1.0 - d / (0.16 + inten * 0.20);
            if (f <= 0) continue;
            f = f * f;
            final hue = (90 + band * 120 + phase * 0.15).toInt() & 0xFF;
            frame.set(x, y, scaleColor(hsv(hue, 220), f));
          }
        }
        break;

      case 13: // 数字雨:亮头 + 渐暗拖尾
        for (var i = 0; i < total; i++) {
          frame.pixels[i] = 0xFF000000;
        }
        for (var x = 0; x < w; x++) {
          final rnd = math.Random(x * 7919 + 13);
          final speed = 0.4 + rnd.nextDouble() * 1.1;
          final len = 4 + rnd.nextInt(h ~/ 2 + 2);
          final head =
              ((phase * 0.18 * speed) + rnd.nextDouble() * h) % (h + len);
          for (var k = 0; k < len; k++) {
            final y = (head - k).floor();
            if (y < 0 || y >= h) continue;
            final t = k / len;
            // 头部接近白色,往下迅速转成暗绿
            final c = k == 0
                ? rgb(200, 255, 210)
                : rgb((30 * (1 - t)).toInt(), (255 * (1 - t)).toInt(),
                    (60 * (1 - t)).toInt());
            frame.set(x, y, c);
          }
        }
        break;

      case 14: // 岩浆灯:几个暖色团缓慢升腾、互相融合
        final blobs = 3 + (inten * 3).toInt();
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            var energy = 0.0;
            for (var b = 0; b < blobs; b++) {
              final rnd = math.Random(b * 4241);
              final bx = (0.2 + rnd.nextDouble() * 0.6) * w +
                  math.sin(phase * 0.02 + b) * w * 0.12;
              final by = h -
                  ((phase * 0.035 * (0.5 + rnd.nextDouble())) + b * h / blobs) %
                      (h * 1.3);
              final r = (0.16 + rnd.nextDouble() * 0.12) * h;
              final dx = x - bx, dy = y - by;
              energy += (r * r) / (dx * dx + dy * dy + 1);
            }
            if (energy < 0.55) continue;
            final t = ((energy - 0.55) * 1.4).clamp(0.0, 1.0);
            // 深红 -> 橙 -> 亮黄
            final c = palette == 0
                ? rgb(255, (60 + 180 * t).toInt(), (10 * t).toInt())
                : Palettes.color(palette, color, (t * 255).toInt());
            frame.set(x, y, scaleColor(c, 0.35 + t * 0.65));
          }
        }
        break;

      case 15: // 万花筒:极坐标花瓣,对称旋转
        final cx = (w - 1) / 2.0, cy = (h - 1) / 2.0;
        final petals = 3 + (intensity ~/ 64);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final dx = x - cx, dy = y - cy;
            final r = math.sqrt(dx * dx + dy * dy);
            final a = math.atan2(dy, dx) + phase * 0.02;
            final petal = math.sin(a * petals + r * 0.5 - phase * 0.05);
            final f = ((petal + 1) / 2);
            if (f < 0.35) continue;
            final hue = ((a / math.pi * 128) + r * 6 + phase * 0.3).toInt() & 0xFF;
            final c = palette == 0 ? hsv(hue) : Palettes.color(palette, color, hue);
            frame.set(x, y, scaleColor(c, (f - 0.35) / 0.65));
          }
        }
        break;

      case 16: // 星空:缓慢明灭的星点,偶尔一颗流星划过
        for (var i = 0; i < total; i++) {
          frame.pixels[i] = 0xFF000000;
        }
        final starCount = (total * (0.06 + inten * 0.10)).toInt().clamp(3, total);
        for (var s = 0; s < starCount; s++) {
          final rnd = math.Random(s * 6151);
          final i = rnd.nextInt(total);
          // 每颗星有自己的明灭周期,整体看起来是"呼吸"而不是乱闪
          final ph = rnd.nextDouble() * math.pi * 2;
          final tw = (math.sin(phase * 0.03 + ph) * 0.5 + 0.5);
          final b = 0.15 + tw * tw * 0.85;
          final warm = rnd.nextDouble() < 0.25;
          frame.pixels[i] =
              scaleColor(warm ? rgb(255, 220, 170) : rgb(210, 225, 255), b);
        }
        // 流星:每隔一段时间从右上斜划到左下
        final cycle = 2600.0;
        final mt = (t % cycle.toInt()) / cycle;
        if (mt < 0.28) {
          final p2 = mt / 0.28;
          final hx = w - p2 * (w + 8);
          final hy = p2 * (h + 8) - 4;
          for (var k = 0; k < 7; k++) {
            final xx = (hx + k * 0.9).round();
            final yy = (hy - k * 0.9).round();
            if (xx < 0 || xx >= w || yy < 0 || yy >= h) continue;
            frame.set(xx, yy, scaleColor(rgb(255, 255, 255), 1.0 - k / 7));
          }
        }
        break;

      case 17: // 霓虹:一圈圈青紫脉冲从中心荡开
        final cx2 = (w - 1) / 2.0, cy2 = (h - 1) / 2.0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final d = math.sqrt((x - cx2) * (x - cx2) + (y - cy2) * (y - cy2));
            final v = math.sin(d * 0.9 - phase * 0.12);
            var f = (v + 1) / 2;
            f = math.pow(f, 3.0).toDouble() * (0.5 + inten * 0.5);
            if (f < 0.04) continue;
            // 青 <-> 品红 之间按距离过渡
            final mix = (math.sin(d * 0.35 - phase * 0.04) + 1) / 2;
            final c = rgb((60 + 195 * mix).toInt(), (230 * (1 - mix)).toInt(),
                (200 + 55 * mix).toInt());
            frame.set(x, y, scaleColor(c, f));
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
