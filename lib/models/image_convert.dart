import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'led_matrix.dart';

/// 图像 -> 灯板帧。
/// 把位图缩放到灯板分辨率(双线性,自动做像素平均),再按每格取色。
///
/// [brightness] 0..1 全局亮度系数,[saturation] 0..2 饱和度(1 = 原样)
Frame imageToFrame(
  img.Image src,
  DeviceConfig config, {
  double brightness = 1.0,
  double saturation = 1.0,
}) {
  final small = img.copyResize(
    src,
    width: config.width,
    height: config.height,
    interpolation: img.Interpolation.average,
  );
  final frame = Frame(config.width, config.height);
  for (var y = 0; y < config.height; y++) {
    for (var x = 0; x < config.width; x++) {
      final p = small.getPixel(x, y);
      frame.set(
        x,
        y,
        _adjust(p.r.toDouble(), p.g.toDouble(), p.b.toDouble(), brightness,
            saturation),
      );
    }
  }
  return frame;
}

int _adjust(double r, double g, double b, double brightness, double saturation) {
  if (saturation != 1.0) {
    final gray = 0.299 * r + 0.587 * g + 0.114 * b;
    r = gray + (r - gray) * saturation;
    g = gray + (g - gray) * saturation;
    b = gray + (b - gray) * saturation;
  }
  r *= brightness;
  g *= brightness;
  b *= brightness;
  return rgb(r.round(), g.round(), b.round());
}

/// 解码图片文件(png/jpg/gif 首帧等)
img.Image? decodeImageBytes(Uint8List bytes) => img.decodeImage(bytes);

/// GIF -> 帧序列
class GifAnim {
  final List<Frame> frames;
  final int delayMs;
  const GifAnim(this.frames, this.delayMs);
}

/// 载入 GIF 并转成灯板帧序列。最多取 [maxFrames] 帧(设备内存有限)。
GifAnim? loadGif(Uint8List bytes, DeviceConfig config, {int maxFrames = 32}) {
  final anim = img.decodeGif(bytes);
  if (anim == null) return null;

  final total = anim.numFrames;
  if (total == 0) return null;

  // 帧数过多时均匀抽样
  final take = total < maxFrames ? total : maxFrames;
  final step = total / take;

  final frames = <Frame>[];
  var delaySum = 0;
  for (var i = 0; i < take; i++) {
    final idx = (i * step).floor().clamp(0, total - 1);
    final f = anim.frames[idx];
    delaySum += f.frameDuration;
    frames.add(imageToFrame(f, config, saturation: 1.2));
  }
  if (frames.isEmpty) return null;

  // 平均帧延时(GIF 单位是 10ms;image 包已按毫秒给出)
  var delay = take > 0 ? (delaySum / take).round() : 66;
  if (delay < 33) delay = 33;
  return GifAnim(frames, delay);
}
