import 'dart:convert';
import 'dart:typed_data';

/// 通信协议(与 ESP32 固件一致)。BLE 和 WiFi 共用同一套封包。
///
/// 架构要点:效果在【设备端】渲染,App 只下发"效果编号 + 参数"。
/// 只有"图片/动画"这类无法用公式生成的内容才上传像素数据。
///
/// 封包: [0xA5][OP][LEN_hi][LEN_lo][payload...]
class Protocol {
  static const serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const rxUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // App 写入
  static const txUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // 设备通知
  static const cccdUuid = '00002902-0000-1000-8000-00805f9b34fb';

  static const deviceName = 'WeiDeng-LED';
  static const magic = 0xA5;

  // ---- 操作码 ----
  static const opText = 0x01; // ASCII 调试命令
  static const opFrame = 0x02; // 单帧像素(物理顺序 RGB)
  static const opBright = 0x03; // 1 字节 全局亮度
  static const opConfig = 0x04; // 灯板配置: w, h, flags
  static const opEffect = 0x05; // 效果: id, speed, intensity, R,G,B, palette
  static const opTaillight = 0x06; // 尾灯模式: mode, 参数
  static const opAnimBegin = 0x07; // 动画开始: 帧数, 帧延时ms
  static const opAnimFrame = 0x08; // 动画一帧: 序号 + 像素
  static const opAnimEnd = 0x09; // 动画结束并播放
  static const opScroll = 0x0A; // 滚动文字位图: 宽, 颜色, 速度 + 位图
  static const opPower = 0x0B; // 1 字节 开/关
  // 音乐律动:只发频谱,由灯板自己渲染。
  // 20 字节 vs 整帧 768 字节,省 97% 带宽,帧率不再受蓝牙限制。
  static const opSpectrum = 0x0C;
  // 临时指定第二块屏怎么显示:0=复制 1=镜像 2=跟随全局设置。
  // 文字类内容必须用"复制",否则右屏会左右翻转成反的。
  static const opPanelMode = 0x0E;
  static const panelCopy = 0;
  static const panelMirror = 1;
  static const panelFollowConfig = 2;

  // ---- 灯板 -> App 的上报(Notify) ----
  static const opStatus = 0x20; // mode, fxId, bright, power, w, h, tailMode

  static Uint8List frame(int op, List<int> payload) {
    final len = payload.length;
    final out = Uint8List(4 + len);
    out[0] = magic;
    out[1] = op;
    out[2] = (len >> 8) & 0xFF;
    out[3] = len & 0xFF;
    out.setRange(4, 4 + len, payload);
    return out;
  }

  static Uint8List text(String cmd) =>
      frame(opText, ascii.encode(cmd));

  static Uint8List brightness(int b) =>
      frame(opBright, [b.clamp(0, 255)]);

  static Uint8List power(bool on) => frame(opPower, [on ? 1 : 0]);

  /// 指定第二块屏的显示方式。发内容之前调用。
  static Uint8List panelMode(int mode) => frame(opPanelMode, [mode & 0xFF]);

  /// 灯板配置。[panels] 为屏数,[mirrorSecond] 表示第二块左右镜像。
  /// 旧固件只读前 3 个字节,多出来的会被忽略,兼容没问题。
  static Uint8List config(
    int w,
    int h,
    bool serpentine,
    bool flipX,
    bool flipY, {
    int panels = 1,
    bool mirrorSecond = true,
  }) {
    var flags = 0;
    if (serpentine) flags |= 0x01;
    if (flipX) flags |= 0x02;
    if (flipY) flags |= 0x04;
    if (mirrorSecond) flags |= 0x08;
    return frame(opConfig, [
      w & 0xFF,
      h & 0xFF,
      flags & 0xFF,
      panels & 0xFF,
    ]);
  }

  /// 效果在设备端渲染,只发参数
  static Uint8List effect(
          int id, int speed, int intensity, int color, int palette) =>
      frame(opEffect, [
        id & 0xFF,
        speed.clamp(0, 255),
        intensity.clamp(0, 255),
        (color >> 16) & 0xFF,
        (color >> 8) & 0xFF,
        color & 0xFF,
        palette & 0xFF,
      ]);

  /// 尾灯模式在设备端常驻运行
  static Uint8List taillight(int mode, int style, int color, int speed) =>
      frame(opTaillight, [
        mode & 0xFF,
        style & 0xFF,
        (color >> 16) & 0xFF,
        (color >> 8) & 0xFF,
        color & 0xFF,
        speed.clamp(0, 255),
      ]);

  static Uint8List animBegin(int frameCount, int delayMs) => frame(opAnimBegin, [
        frameCount & 0xFF,
        (delayMs >> 8) & 0xFF,
        delayMs & 0xFF,
      ]);

  static Uint8List animFrame(int index, List<int> rgbBytes) {
    final p = Uint8List(1 + rgbBytes.length);
    p[0] = index & 0xFF;
    p.setRange(1, 1 + rgbBytes.length, rgbBytes);
    return frame(opAnimFrame, p);
  }

  static Uint8List animEnd() => frame(opAnimEnd, const []);

  /// 音乐频谱:16 个频段能量 + 总音量,灯板据此自己渲染
  static Uint8List spectrum(
      int style, int palette, int color, int volume, List<int> bands) {
    final p = Uint8List(6 + 16);
    p[0] = style & 0xFF;
    p[1] = palette & 0xFF;
    p[2] = (color >> 16) & 0xFF;
    p[3] = (color >> 8) & 0xFF;
    p[4] = color & 0xFF;
    p[5] = volume.clamp(0, 255);
    for (var i = 0; i < 16; i++) {
      p[6 + i] = i < bands.length ? bands[i].clamp(0, 255) : 0;
    }
    return frame(opSpectrum, p);
  }

  /// 滚动文字:App 端把文字(含中文)渲染成 1bit 位图上传,设备端负责滚动
  static Uint8List scroll(
      int bitmapWidth, int height, int color, int speed, List<int> bits) {
    final p = Uint8List(7 + bits.length);
    p[0] = (bitmapWidth >> 8) & 0xFF;
    p[1] = bitmapWidth & 0xFF;
    p[2] = height & 0xFF;
    p[3] = (color >> 16) & 0xFF;
    p[4] = (color >> 8) & 0xFF;
    p[5] = color & 0xFF;
    p[6] = speed.clamp(0, 255);
    p.setRange(7, 7 + bits.length, bits);
    return frame(opScroll, p);
  }
}
