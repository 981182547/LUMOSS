import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'led_matrix.dart';

/// 渲染好的文字点阵:按行优先存亮度(0..255)
class TextBitmap {
  final int width;
  final int height;
  final Uint8List lum; // 长度 = width * height

  TextBitmap(this.width, this.height, this.lum);

  int lumAt(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return 0;
    return lum[y * width + x];
  }
}

/// 文字 -> 点阵位图。用 Flutter 自带文字渲染,因此【中文、emoji、任意字体都支持】,
/// 不需要在固件里塞字库。
class TextRender {
  /// 把文字渲染成 height 高的单色位图(宽度自适应)
  static Future<TextBitmap?> renderText(String text, int height,
      {bool bold = true}) async {
    if (text.trim().isEmpty) return null;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          // 字号略小于板高,留出上下边距
          fontSize: height * 0.92,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: const Color(0xFFFFFFFF),
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();

    final w = painter.width.ceil().clamp(1, 4096);
    final h = height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    // 黑底
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = const Color(0xFF000000),
    );
    // 垂直居中
    final dy = (h - painter.height) / 2;
    painter.paint(canvas, Offset(0, dy));

    final picture = recorder.endRecording();
    final img = await picture.toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    img.dispose();
    if (data == null) return null;

    // 取每个像素的红通道当亮度(白字黑底,三通道一致)
    final bytes = data.buffer.asUint8List();
    final lum = Uint8List(w * h);
    for (var i = 0; i < w * h; i++) {
      lum[i] = bytes[i * 4];
    }
    return TextBitmap(w, h, lum);
  }

  /// 生成滚动帧:文字从右侧进入、向左移出。[offset] 已滚动的像素数
  static Frame scrollFrame(
      TextBitmap bmp, DeviceConfig config, int offset, int color) {
    final f = Frame(config.width, config.height);
    final total = bmp.width + config.width;
    final off = ((offset % total) + total) % total;
    for (var y = 0; y < config.height; y++) {
      for (var x = 0; x < config.width; x++) {
        final sx = x + off - config.width;
        if (sx >= 0 && sx < bmp.width && y < bmp.height) {
          if (bmp.lumAt(sx, y) > 100) f.set(x, y, color);
        }
      }
    }
    return f;
  }

  /// 打包成 1bit 位图上传给设备(设备端自己滚动,省带宽)
  static Uint8List toBits(TextBitmap bmp) {
    final w = bmp.width;
    final h = bmp.height;
    final bytesPerCol = (h + 7) ~/ 8;
    final out = Uint8List(w * bytesPerCol);
    for (var x = 0; x < w; x++) {
      for (var y = 0; y < h; y++) {
        if (bmp.lumAt(x, y) > 100) {
          final idx = x * bytesPerCol + y ~/ 8;
          out[idx] = out[idx] | (1 << (y % 8));
        }
      }
    }
    return out;
  }
}
