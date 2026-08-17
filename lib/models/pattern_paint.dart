import 'dart:math' as math;

import 'led_matrix.dart';

/// 图案绘制工具。
///
/// 坐标一律用 0..1 的归一化值,再映射到实际像素 —— 这样同一个图案
/// 在 16×16、20×40、32×8 上都能自动适配,不用为每种屏画一套。
class Painter {
  final Frame f;
  Painter(this.f);

  int get w => f.width;
  int get h => f.height;

  void clear([int c = 0xFF000000]) {
    for (var i = 0; i < f.pixels.length; i++) {
      f.pixels[i] = c;
    }
  }

  /// 归一化 -> 像素
  int _px(double nx) => (nx * (w - 1)).round();
  int _py(double ny) => (ny * (h - 1)).round();

  void dot(double nx, double ny, int c) => f.set(_px(nx), _py(ny), c);

  void pixel(int x, int y, int c) => f.set(x, y, c);

  /// 实心矩形(归一化坐标,左上 + 宽高)
  void rect(double nx, double ny, double nw, double nh, int c,
      {bool fill = true}) {
    final x0 = _px(nx), y0 = _py(ny);
    final x1 = _px(nx + nw), y1 = _py(ny + nh);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final edge = x == x0 || x == x1 || y == y0 || y == y1;
        if (fill || edge) f.set(x, y, c);
      }
    }
  }

  /// 圆 / 椭圆。[nr] 是相对短边的半径
  void circle(double ncx, double ncy, double nr, int c, {bool fill = true}) {
    final short = math.min(w, h);
    final r = nr * short;
    final cx = _px(ncx).toDouble(), cy = _py(ncy).toDouble();
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final d = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        if (fill ? d <= r : (d <= r && d >= r - 1.2)) f.set(x, y, c);
      }
    }
  }

  void line(double nx0, double ny0, double nx1, double ny1, int c,
      {double thick = 1}) {
    final x0 = _px(nx0).toDouble(), y0 = _py(ny0).toDouble();
    final x1 = _px(nx1).toDouble(), y1 = _py(ny1).toDouble();
    final steps = math.max((x1 - x0).abs(), (y1 - y0).abs()).ceil() * 2 + 1;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = x0 + (x1 - x0) * t;
      final y = y0 + (y1 - y0) * t;
      _stamp(x, y, thick, c);
    }
  }

  void _stamp(double x, double y, double thick, int c) {
    final r = (thick - 1) / 2;
    for (var dy = -r.ceil(); dy <= r.ceil(); dy++) {
      for (var dx = -r.ceil(); dx <= r.ceil(); dx++) {
        if (dx * dx + dy * dy <= (r + 0.4) * (r + 0.4)) {
          f.set((x + dx).round(), (y + dy).round(), c);
        }
      }
    }
  }

  /// 多边形填充(归一化顶点),用扫描线
  void polygon(List<List<double>> pts, int c) {
    if (pts.length < 3) return;
    final xs = [for (final p in pts) _px(p[0]).toDouble()];
    final ys = [for (final p in pts) _py(p[1]).toDouble()];
    final minY = ys.reduce(math.min).floor().clamp(0, h - 1);
    final maxY = ys.reduce(math.max).ceil().clamp(0, h - 1);

    for (var y = minY; y <= maxY; y++) {
      final cross = <double>[];
      for (var i = 0; i < pts.length; i++) {
        final j = (i + 1) % pts.length;
        final y0 = ys[i], y1 = ys[j];
        if ((y0 <= y && y1 > y) || (y1 <= y && y0 > y)) {
          final t = (y - y0) / (y1 - y0);
          cross.add(xs[i] + (xs[j] - xs[i]) * t);
        }
      }
      cross.sort();
      for (var k = 0; k + 1 < cross.length; k += 2) {
        for (var x = cross[k].round(); x <= cross[k + 1].round(); x++) {
          f.set(x, y, c);
        }
      }
    }
  }

  /// 心形(经典参数方程,填充)
  void heart(double ncx, double ncy, double scale, int c) {
    final short = math.min(w, h) * scale;
    final cx = _px(ncx).toDouble(), cy = _py(ncy).toDouble();
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final nx = (x - cx) / short * 2.2;
        final ny = -(y - cy) / short * 2.2;
        final a = nx * nx + ny * ny - 1;
        if (a * a * a - nx * nx * ny * ny * ny <= 0) f.set(x, y, c);
      }
    }
  }

  /// 五角星
  void star(double ncx, double ncy, double nr, int c) {
    final pts = <List<double>>[];
    final short = math.min(w, h);
    final rOuter = nr * short;
    final rInner = rOuter * 0.42;
    for (var i = 0; i < 10; i++) {
      final ang = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? rOuter : rInner;
      pts.add([
        (_px(ncx) + math.cos(ang) * r) / (w - 1),
        (_py(ncy) + math.sin(ang) * r) / (h - 1),
      ]);
    }
    polygon(pts, c);
  }

  /// 箭头。[dir] 0=上 1=下 2=左 3=右
  void arrow(double ncx, double ncy, double size, int dir, int c) {
    final s = size;
    List<List<double>> pts;
    switch (dir) {
      case 0: // 上
        pts = [
          [ncx, ncy - s],
          [ncx + s * 0.8, ncy],
          [ncx + s * 0.35, ncy],
          [ncx + s * 0.35, ncy + s],
          [ncx - s * 0.35, ncy + s],
          [ncx - s * 0.35, ncy],
          [ncx - s * 0.8, ncy],
        ];
        break;
      case 1: // 下
        pts = [
          [ncx, ncy + s],
          [ncx + s * 0.8, ncy],
          [ncx + s * 0.35, ncy],
          [ncx + s * 0.35, ncy - s],
          [ncx - s * 0.35, ncy - s],
          [ncx - s * 0.35, ncy],
          [ncx - s * 0.8, ncy],
        ];
        break;
      case 2: // 左
        pts = [
          [ncx - s, ncy],
          [ncx, ncy - s * 0.8],
          [ncx, ncy - s * 0.35],
          [ncx + s, ncy - s * 0.35],
          [ncx + s, ncy + s * 0.35],
          [ncx, ncy + s * 0.35],
          [ncx, ncy + s * 0.8],
        ];
        break;
      default: // 右
        pts = [
          [ncx + s, ncy],
          [ncx, ncy - s * 0.8],
          [ncx, ncy - s * 0.35],
          [ncx - s, ncy - s * 0.35],
          [ncx - s, ncy + s * 0.35],
          [ncx, ncy + s * 0.35],
          [ncx, ncy + s * 0.8],
        ];
    }
    polygon(pts, c);
  }

  /// 三角警示牌(空心)
  void warningTriangle(double ncx, double ncy, double size, int c) {
    polygon([
      [ncx, ncy - size],
      [ncx + size * 0.95, ncy + size * 0.75],
      [ncx - size * 0.95, ncy + size * 0.75],
    ], c);
    // 挖空中间,留出边框和感叹号
    polygon([
      [ncx, ncy - size * 0.6],
      [ncx + size * 0.62, ncy + size * 0.52],
      [ncx - size * 0.62, ncy + size * 0.52],
    ], 0xFF000000);
    rect(ncx - 0.03, ncy - size * 0.35, 0.06, size * 0.6, c);
    rect(ncx - 0.03, ncy + size * 0.32, 0.06, 0.05, c);
  }
}
