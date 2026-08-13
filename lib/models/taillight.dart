import 'led_matrix.dart';

/// 汽车尾灯模式。这些效果必须常驻在【设备端】运行 —— 车在路上跑时手机不在旁边。
/// App 这边只负责配置样式和预览。
class Taillight {
  static const modeOff = 0;
  static const modePosition = 1; // 位置灯/示宽 暗红常亮
  static const modeBrake = 2; // 刹车 高亮红
  static const modeTurnL = 3; // 左转 琥珀
  static const modeTurnR = 4; // 右转 琥珀
  static const modeReverse = 5; // 倒车 白
  static const modeHazard = 6; // 双闪
  static const modeWelcome = 7; // 迎宾动画

  static const modes = <MapEntry<int, String>>[
    MapEntry(modePosition, '位置灯'),
    MapEntry(modeBrake, '刹车'),
    MapEntry(modeTurnL, '左转'),
    MapEntry(modeTurnR, '右转'),
    MapEntry(modeReverse, '倒车'),
    MapEntry(modeHazard, '双闪'),
    MapEntry(modeWelcome, '迎宾'),
  ];

  // 转向样式
  static const styleSequential = 0; // 流水
  static const styleBlink = 1; // 整片闪
  static const styleSweep = 2; // 扫描填充
  static const styles = ['流水', '整片闪', '扫描填充'];

  static final redDim = rgb(90, 0, 0);
  static final redBright = rgb(255, 0, 0);
  static final amber = rgb(255, 110, 0);
  static final white = rgb(255, 255, 255);

  /// 渲染尾灯一帧。与固件端同算法。[t] 毫秒
  static void render(Frame frame, int mode, int style, int t, [int speed = 128]) {
    final w = frame.width;
    final h = frame.height;
    final spd = 0.5 + speed / 255.0 * 1.5;
    _clear(frame);

    switch (mode) {
      case modePosition:
        _fill(frame, redDim);
        break;
      case modeBrake:
        _fill(frame, redBright);
        break;
      case modeTurnL:
        _turn(frame, style, t, spd, true);
        break;
      case modeTurnR:
        _turn(frame, style, t, spd, false);
        break;
      case modeReverse:
        _fill(frame, white);
        break;
      case modeHazard:
        // 法规参考频率约 1.5Hz -> 周期约 667ms
        final on = ((t * spd).toInt() ~/ 333) % 2 == 0;
        if (on) _fill(frame, amber);
        break;
      case modeWelcome: // 迎宾:红光从中间向两侧展开
        final cx = (w - 1) / 2.0;
        final prog = ((t * spd) % 2400) / 2400.0;
        final reach = prog * (w / 2.0 + 2);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final d = (x - cx).abs();
            final f =
                (1.0 - (d - reach + 2.0).clamp(0.0, double.infinity) / 2.0)
                    .clamp(0.0, 1.0);
            if (f > 0) frame.set(x, y, scaleColor(redBright, f));
          }
        }
        break;
    }
  }

  static void _turn(Frame frame, int style, int t, double spd, bool leftward) {
    final w = frame.width;
    final h = frame.height;
    switch (style) {
      case styleBlink:
        final on = ((t * spd).toInt() ~/ 333) % 2 == 0;
        if (on) _fill(frame, amber);
        break;
      case styleSweep:
        final cycle = 1200.0 / spd;
        final p = (t % cycle.toInt()) / cycle;
        final filled = (p * w * 1.35).toInt();
        for (var x = 0; x < w; x++) {
          final xx = leftward ? w - 1 - x : x;
          if (x < filled) {
            for (var y = 0; y < h; y++) {
              frame.set(xx, y, amber);
            }
          }
        }
        break;
      default: // 流水:一段亮块扫过,带拖尾
        final cycle = 1000.0 / spd;
        final p = (t % cycle.toInt()) / cycle;
        final head = p * (w + 6) - 3;
        const tail = 4.0;
        for (var x = 0; x < w; x++) {
          final xx = leftward ? w - 1 - x : x;
          final f = (1.0 - (head - x) / tail).clamp(0.0, 1.0) *
              (x <= head ? 1.0 : 0.0);
          if (f > 0) {
            for (var y = 0; y < h; y++) {
              frame.set(xx, y, scaleColor(amber, f));
            }
          }
        }
    }
  }

  static void _clear(Frame f) {
    for (var i = 0; i < f.pixels.length; i++) {
      f.pixels[i] = 0xFF000000;
    }
  }

  static void _fill(Frame f, int c) {
    for (var i = 0; i < f.pixels.length; i++) {
      f.pixels[i] = c;
    }
  }
}
