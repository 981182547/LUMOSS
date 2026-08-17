import 'dart:typed_data';

// ============================================================
// 颜色工具(ARGB 用 int 表示,与原 Kotlin 版一致)
// ============================================================

/// HSV -> ARGB,h 0..255 环绕
int hsv(int h, [int s = 255, int v = 255]) {
  final hh = ((h % 256) + 256) % 256;
  final region = hh ~/ 43;
  final rem = (hh - region * 43) * 6;
  final p = v * (255 - s) ~/ 255;
  final q = v * (255 - (s * rem) ~/ 255) ~/ 255;
  final t = v * (255 - (s * (255 - rem)) ~/ 255) ~/ 255;
  int r, g, b;
  switch (region) {
    case 0:
      r = v; g = t; b = p; break;
    case 1:
      r = q; g = v; b = p; break;
    case 2:
      r = p; g = v; b = t; break;
    case 3:
      r = p; g = q; b = v; break;
    case 4:
      r = t; g = p; b = v; break;
    default:
      r = v; g = p; b = q;
  }
  return (0xFF << 24) | (r << 16) | (g << 8) | b;
}

int rgb(int r, int g, int b) =>
    (0xFF << 24) |
    (r.clamp(0, 255) << 16) |
    (g.clamp(0, 255) << 8) |
    b.clamp(0, 255);

int scaleColor(int c, double f) {
  final r = (((c >> 16) & 0xFF) * f).toInt();
  final g = (((c >> 8) & 0xFF) * f).toInt();
  final b = ((c & 0xFF) * f).toInt();
  return rgb(r, g, b);
}

// ============================================================
// 灯板配置。与 ESP32 固件里的映射保持一致:
// 左上角为逻辑坐标 (0,0),x 向右、y 向下。
// ============================================================
class DeviceConfig {
  final int width;
  final int height;
  final bool serpentine; // 蛇形走线
  final bool flipX; // 信号从右上进,默认翻转 X
  final bool flipY;

  /// 屏数。车尾灯左右各一块时填 2,两块串在同一条数据线上:
  /// 第一块占 0..count-1,第二块占 count..2*count-1。
  final int panels;

  /// 第二块屏是否左右镜像。车尾左右对称时开启,
  /// App 只需下发一块屏的画面,另一块由灯板镜像生成,省一半带宽。
  final bool mirrorSecond;

  const DeviceConfig({
    this.width = 16,
    this.height = 16,
    this.serpentine = true,
    this.flipX = true,
    this.flipY = false,
    this.panels = 1,
    this.mirrorSecond = true,
  });

  /// 单块屏的灯珠数(也是 App 需要下发的像素数)
  int get count => width * height;

  /// 实际接在灯带上的总灯珠数
  int get totalLeds => count * panels;

  /// 逻辑坐标 (x,y) -> 灯带物理序号
  int indexOf(int x, int y) {
    var px = x.clamp(0, width - 1);
    var py = y.clamp(0, height - 1);
    if (flipX) px = width - 1 - px;
    if (flipY) py = height - 1 - py;
    if (serpentine && (py & 1) == 1) {
      return py * width + (width - 1 - px);
    } else {
      return py * width + px;
    }
  }

  DeviceConfig copyWith({
    int? width,
    int? height,
    bool? serpentine,
    bool? flipX,
    bool? flipY,
    int? panels,
    bool? mirrorSecond,
  }) =>
      DeviceConfig(
        width: width ?? this.width,
        height: height ?? this.height,
        serpentine: serpentine ?? this.serpentine,
        flipX: flipX ?? this.flipX,
        flipY: flipY ?? this.flipY,
        panels: panels ?? this.panels,
        mirrorSecond: mirrorSecond ?? this.mirrorSecond,
      );
}

// ============================================================
// 一帧画面。pixels 按"逻辑坐标"存储(index = y*width + x),每个元素 ARGB。
// 下发时再用 DeviceConfig.indexOf 重排成灯带物理顺序。
// ============================================================
class Frame {
  final int width;
  final int height;
  final List<int> pixels;

  Frame(this.width, this.height)
      : pixels = List<int>.filled(width * height, 0xFF000000);

  void set(int x, int y, int argb) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      pixels[y * width + x] = argb;
    }
  }

  int get(int x, int y) => pixels[y * width + x];

  Frame copy() {
    final f = Frame(width, height);
    f.pixels.setRange(0, pixels.length, pixels);
    return f;
  }

  /// 缩放到指定尺寸(最近邻)。
  ///
  /// 点阵画面本来就是一格一色,用最近邻能保持色块干脆,
  /// 双线性反而会糊掉边缘。尺寸一致时直接返回自身,不做无谓拷贝。
  Frame scaleTo(int newW, int newH) {
    if (newW == width && newH == height) return this;
    final out = Frame(newW, newH);
    for (var y = 0; y < newH; y++) {
      final sy = (y * height / newH).floor().clamp(0, height - 1);
      for (var x = 0; x < newW; x++) {
        final sx = (x * width / newW).floor().clamp(0, width - 1);
        out.set(x, y, get(sx, sy));
      }
    }
    return out;
  }

  /// 按灯带物理顺序生成 RGB 字节流(每颗 3 字节 R,G,B),要发给 ESP32 的数据。
  Uint8List toRgbBytes(DeviceConfig config) {
    final out = Uint8List(config.count * 3);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final argb = get(x, y);
        final idx = config.indexOf(x, y);
        final o = idx * 3;
        out[o] = (argb >> 16) & 0xFF; // R
        out[o + 1] = (argb >> 8) & 0xFF; // G
        out[o + 2] = argb & 0xFF; // B
      }
    }
    return out;
  }
}
