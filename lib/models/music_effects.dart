import 'dart:math' as math;

import 'effects.dart';
import 'led_matrix.dart';

/// 音乐律动可视化样式
class MusicEffects {
  static const styles = ['频谱', '音量条', '脉冲', '律动彩虹'];

  static void render(
    Frame frame,
    int style,
    List<double> bands,
    double volume,
    int color,
    int palette,
    int t,
  ) {
    final w = frame.width;
    final h = frame.height;
    for (var i = 0; i < frame.pixels.length; i++) {
      frame.pixels[i] = 0xFF000000;
    }

    switch (style) {
      case 0: // 频谱柱状:每列一个频段
        for (var x = 0; x < w; x++) {
          final bi = bands.isEmpty ? 0 : x * bands.length ~/ w;
          final b = (bi < bands.length) ? bands[bi] : 0.0;
          final barH = (b * h).toInt().clamp(0, h);
          for (var y = 0; y < barH; y++) {
            final yy = h - 1 - y;
            final c = palette == 0
                ? color
                : Palettes.color(palette, color, y * 255 ~/ (h < 1 ? 1 : h));
            frame.set(x, yy, c);
          }
        }
        break;

      case 1: // 音量条:整屏从下往上填充
        final lvl = (volume * 2.2).clamp(0.0, 1.0);
        final barH = (lvl * h).toInt();
        for (var y = 0; y < barH; y++) {
          final yy = h - 1 - y;
          // 低绿 中黄 高红
          final p = y / h;
          final c = p < 0.5
              ? rgb((p * 2 * 255).toInt(), 255, 0)
              : rgb(255, ((1 - p) * 2 * 255).toInt(), 0);
          for (var x = 0; x < w; x++) {
            frame.set(x, yy, c);
          }
        }
        break;

      case 2: // 脉冲:中心随节拍扩散的圆
        final lvl = (volume * 2.5).clamp(0.0, 1.0);
        final cx = (w - 1) / 2.0;
        final cy = (h - 1) / 2.0;
        final radius = lvl * ((w > h ? w : h) / 2.0 + 1);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final d = _hypot(x - cx, y - cy);
            final f = (1.0 - (d - radius).abs() / 1.6).clamp(0.0, 1.0);
            if (f > 0) {
              final c = palette == 0
                  ? color
                  : Palettes.color(palette, color, (d * 24 + t / 20).toInt());
              frame.set(x, y, scaleColor(c, f));
            }
          }
        }
        // 中心随音量常亮
        if (lvl > 0.05) {
          for (var y = 0; y < h; y++) {
            for (var x = 0; x < w; x++) {
              final d = _hypot(x - cx, y - cy);
              if (d < radius - 1) {
                final c = palette == 0
                    ? color
                    : Palettes.color(palette, color, (d * 24).toInt());
                frame.set(x, y, scaleColor(c, 0.35 * lvl));
              }
            }
          }
        }
        break;

      default: // 律动彩虹:整屏彩虹,亮度随音量
        final lvl = (0.15 + volume * 2.2).clamp(0.0, 1.0);
        final head = bands.length < 3 ? bands : bands.sublist(0, 3);
        final bass = head.isEmpty
            ? 0.0
            : head.reduce((a, b) => a + b) / head.length;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final pos = ((x + y) * 255 ~/ (w + h - 1) +
                    (t ~/ 12) +
                    (bass * 120).toInt()) &
                0xFF;
            frame.set(x, y, scaleColor(hsv(pos), lvl));
          }
        }
    }
  }

  static double _hypot(double a, double b) => math.sqrt(a * a + b * b);
}
