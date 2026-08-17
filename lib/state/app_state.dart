import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/ble_manager.dart';
import '../ble/link.dart';
import '../ble/protocol.dart';
import '../ble/wifi_manager.dart';
import '../models/effects.dart';
import '../models/led_matrix.dart';
import '../models/patterns.dart';
import '../models/preset.dart';
import '../models/taillight.dart';

enum ConnState { disconnected, connecting, connected }

/// 当前灯板在显示什么
sealed class Mode {
  const Mode();
}

class ModeIdle extends Mode {
  const ModeIdle();
}

class ModeEffect extends Mode {
  final int id;
  const ModeEffect(this.id);
}

class ModeTail extends Mode {
  final int mode;
  const ModeTail(this.mode);
}

class ModePicture extends Mode {
  const ModePicture();
}

class ModeAnimation extends Mode {
  const ModeAnimation();
}

class ModeScroll extends Mode {
  const ModeScroll();
}

class ModeMusic extends Mode {
  final int style;
  const ModeMusic(this.style);
}

/// 大数据传输时,询问是否改用 WiFi 的回调。
/// 返回 true = 用户同意走 WiFi;false = 继续用蓝牙。
typedef AskUseWifi = Future<bool> Function(int bytes);

class AppState extends ChangeNotifier {
  final SharedPreferences prefs;
  late final PresetStore store;

  AppState(this.prefs) {
    store = PresetStore(prefs);
  }

  // ---- 设备配置(可自定义尺寸,持久化) ----
  DeviceConfig _config = const DeviceConfig();
  DeviceConfig get config => _config;

  void updateConfig(DeviceConfig c) {
    _config = c;
    currentFrame = Frame(c.width, c.height);
    _saveConfig(c);
    sendConfig();
    notifyListeners();
  }

  double brightness = 0.6;
  bool powerOn = true;
  ConnState conn = ConnState.disconnected;
  String statusLog = '';
  Frame currentFrame = Frame(16, 16);
  Mode mode = const ModeIdle();

  // ---- 特效参数 ----
  int effectId = 1;
  int effectSpeed = 128;
  int effectIntensity = 160;
  int effectColor = 0xFFFF003C;
  int effectPalette = 1;

  // ---- 尾灯参数 ----
  int tailMode = Taillight.modePosition;
  int tailStyle = Taillight.styleSequential;
  int tailSpeed = 140;

  // ---- 音乐律动 ----
  int musicStyle = 0;
  bool musicOn = false;

  // ---- 素材库 / 播放列表 ----
  List<Preset> presets = [];
  List<MapEntry<String, int>> playlist = [];
  bool playlistRunning = false;
  int playlistIndex = 0;

  // ---- 传输通道 ----
  BleManager? ble;
  WifiManager? wifi;

  /// 是否已经走过首次引导
  bool onboarded = false;

  void markOnboarded() {
    onboarded = true;
    prefs.setBool('onboarded', true);
    notifyListeners();
  }

  /// 上次连接的灯板 ID,下次打开自动连回去
  String? lastDeviceId;

  void rememberDevice(String id) {
    lastDeviceId = id;
    prefs.setString('last_device', id);
  }

  /// WiFi 设置(持久化)。默认关闭:小数据量场景蓝牙完全够用,
  /// 关掉就不会在传图片/动画时弹"是否改用 WiFi"打扰用户。
  bool wifiEnabled = false;
  String wifiHost = '192.168.4.1';
  int wifiPort = 8266;

  /// 大数据阈值:超过这个字节数就询问是否改用 WiFi
  static const highSpeedThresholdBytes = 4096;

  /// 由 UI 注入:询问用户是否改用 WiFi 传大数据
  AskUseWifi? askUseWifi;

  // ============================================================
  // 初始化
  // ============================================================
  static Future<AppState> create() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppState(prefs);
    s._config = s._loadConfig();
    s.brightness = prefs.getDouble('bright') ?? 0.6;
    s.onboarded = prefs.getBool('onboarded') ?? false;
    s.lastDeviceId = prefs.getString('last_device');
    s.wifiEnabled = prefs.getBool('wifi_enabled') ?? false;
    s.wifiHost = prefs.getString('wifi_host') ?? '192.168.4.1';
    s.wifiPort = prefs.getInt('wifi_port') ?? 8266;
    s.currentFrame = Frame(s._config.width, s._config.height);
    s.reloadPresets();
    // 首页默认跑彩虹,一进来就是活的,不是黑屏
    s.mode = ModeEffect(s.effectId);
    return s;
  }

  void reloadPresets() {
    presets = store.load();
    playlist = store.loadPlaylist();
    notifyListeners();
  }

  void addPreset(Preset p) {
    presets = [...presets, p];
    store.save(presets);
    notifyListeners();
  }

  void deletePreset(Preset p) {
    if (p.builtIn) return;
    presets = presets.where((e) => e.id != p.id).toList();
    playlist = playlist.where((e) => e.key != p.id).toList();
    store.save(presets);
    store.savePlaylist(playlist);
    notifyListeners();
  }

  void updatePlaylist(List<MapEntry<String, int>> items) {
    playlist = items;
    store.savePlaylist(items);
    notifyListeners();
  }

  /// 应用一个场景(预览 + 下发)
  void applyPreset(Preset p) {
    switch (p.type) {
      case typeEffect:
        effectId = p.effectId;
        effectSpeed = p.speed;
        effectIntensity = p.intensity;
        effectColor = p.color;
        effectPalette = p.palette;
        pushEffect();
        break;
      case typeTail:
        tailMode = p.tailMode;
        tailStyle = p.tailStyle;
        pushTaillight();
        break;
      default:
        // 场景可能是在别的灯板尺寸下存的,缩放到当前尺寸再下发,
        // 否则只会填在左上角一小块
        final f = p.toFrame();
        if (f != null) pushFrame(f.scaleTo(config.width, config.height));
    }
  }

  /// 把当前状态存成场景
  Preset captureCurrent(String name) {
    final id = 'u_${DateTime.now().millisecondsSinceEpoch}';
    final m = mode;
    if (m is ModeEffect) {
      return Preset(
        id: id, name: name, type: typeEffect,
        effectId: m.id, speed: effectSpeed, intensity: effectIntensity,
        color: effectColor, palette: effectPalette,
      );
    } else if (m is ModeTail) {
      return Preset(
        id: id, name: name, type: typeTail,
        tailMode: m.mode, tailStyle: tailStyle,
      );
    }
    return Preset(
      id: id, name: name, type: typeFrame,
      w: config.width, h: config.height,
      pixels: List<int>.from(currentFrame.pixels),
    );
  }

  // ============================================================
  // 预览渲染:按当前模式生成一帧(供预览循环调用)
  // ============================================================
  void renderPreview(int t) {
    final m = mode;
    if (m is ModeEffect) {
      final f = Frame(config.width, config.height);
      Effects.render(f, m.id, t, effectSpeed, effectIntensity, effectColor, effectPalette);
      currentFrame = f;
      notifyListeners();
    } else if (m is ModeTail) {
      final f = Frame(config.width, config.height);
      Taillight.render(f, m.mode, tailStyle, t, tailSpeed);
      currentFrame = f;
      notifyListeners();
    }
    // 图片/动画/静止由各自界面设置
  }

  /// 关灯时停止预览动画,让界面和灯板的真实状态一致
  bool get isAnimating =>
      powerOn && (mode is ModeEffect || mode is ModeTail);

  // ============================================================
  // 发送:小指令恒走蓝牙;大数据可询问后改走 WiFi
  // ============================================================

  /// 小指令通道:优先蓝牙,蓝牙没连时若 WiFi 连着就走 WiFi
  LinkTransport? get _cmdLink {
    if (ble?.isConnected == true) return ble;
    if (wifi?.isConnected == true) return wifi;
    return null;
  }

  void _sendCmd(Uint8List msg) {
    _cmdLink?.sendPacket(msg);
  }

  // 双屏时第二块屏的显示方式。这是灯板上的一个持久状态,
  // 发完"复制"的内容后如果不改回来,后面的特效、转向灯都会跟着用复制,
  // 流水转向就会变成两边同向而不是对称往外流。所以每类内容发送前都要显式设定。
  int _lastPanelMode = -1;

  void _setPanelMode(int mode) {
    if (config.panels < 2) return;
    if (mode == _lastPanelMode) return; // 没变就不必重复发
    _lastPanelMode = mode;
    _sendCmd(Protocol.panelMode(mode));
  }

  /// 左右对称的内容(特效、尾灯、图片)跟随全局设置;
  /// 文字这类有左右之分的必须复制,否则右屏是反的。
  void _panelModeFor({required bool symmetric}) => _setPanelMode(
      symmetric ? Protocol.panelFollowConfig : Protocol.panelCopy);

  /// 大数据通道:仅在用户开启 WiFi 传输后,才在超过阈值时询问是否改用 WiFi。
  /// 未开启就安静地走蓝牙。
  Future<void> _sendBulk(Uint8List msg) async {
    final bytes = msg.length;
    if (wifiEnabled && bytes >= highSpeedThresholdBytes) {
      final w = wifi;
      if (w != null && !w.isConnected && askUseWifi != null) {
        final useWifi = await askUseWifi!(bytes);
        if (useWifi) {
          final ok = await w.connect(wifiHost, wifiPort);
          if (ok) {
            await w.sendPacket(msg);
            return;
          }
        }
      } else if (w != null && w.isConnected) {
        // WiFi 已连,大数据直接走它
        await w.sendPacket(msg);
        return;
      }
    }
    _cmdLink?.sendPacket(msg);
  }

  void pushBrightness() {
    _brightTimer?.cancel();
    _brightTimer = null;
    prefs.setDouble('bright', brightness);
    _sendCmd(Protocol.brightness((brightness * 255).round()));
  }

  // 亮度节流:拖动滑条时按固定间隔下发,让灯板跟手,
  // 又不会把每一个像素级的变化都塞进蓝牙队列。
  Timer? _brightTimer;
  DateTime _lastBrightSend = DateTime.fromMillisecondsSinceEpoch(0);
  static const _brightIntervalMs = 90;

  /// 拖动过程中调用:最多每 90ms 发一次,末尾那次一定会补发
  void pushBrightnessLive() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastBrightSend).inMilliseconds;
    if (elapsed >= _brightIntervalMs) {
      _lastBrightSend = now;
      _sendCmd(Protocol.brightness((brightness * 255).round()));
    } else {
      // 还没到间隔,安排一次补发,保证停手时的值不会丢
      _brightTimer?.cancel();
      _brightTimer = Timer(
        Duration(milliseconds: _brightIntervalMs - elapsed),
        () {
          _lastBrightSend = DateTime.now();
          _sendCmd(Protocol.brightness((brightness * 255).round()));
        },
      );
    }
  }

  void pushPower() {
    _sendCmd(Protocol.power(powerOn));
    // 关灯时把预览也熄掉,开灯时下一帧渲染会自动恢复
    if (!powerOn) {
      final f = Frame(config.width, config.height);
      currentFrame = f;
    }
    notifyListeners();
  }

  void sendConfig() {
    // 灯板可能刚重启,它那边的 panelMode 已回到默认值。
    // 清掉本地记录,下次发内容时会重新下发一次,避免两边不同步。
    _lastPanelMode = -1;
    _sendConfigPacket();
  }

  void _sendConfigPacket() => _sendCmd(Protocol.config(
        config.width,
        config.height,
        config.serpentine,
        config.flipX,
        config.flipY,
        panels: config.panels,
        mirrorSecond: config.mirrorSecond,
      ));

  /// 整帧像素:数据量大,走大数据通道
  Future<void> pushFrame(Frame frame) async {
    _panelModeFor(symmetric: true);
    mode = const ModePicture();
    currentFrame = frame;
    notifyListeners();
    await _sendBulk(Protocol.frame(Protocol.opFrame, frame.toRgbBytes(config)));
  }

  /// 发送图案。静态图当整帧发,动图走动画上传通道。
  ///
  /// 关键:文字、箭头这类左右不对称的内容必须让第二块屏【复制】而不是镜像,
  /// 否则右屏会翻转成反的、字都读不了。
  Future<void> pushPattern(PatternDef def) async {
    _panelModeFor(symmetric: def.symmetric);

    if (!def.animated) {
      final f = await Patterns.render(def, config, 0, effectColor);
      await pushFrame(f);
      return;
    }

    // 灯板最多存 32 帧。高级/温馨这类动画为了顺滑做到了 40~90 帧,
    // 超了会被固件直接拒收,所以均匀抽帧并把帧间隔按比例拉长,
    // 播放总时长和节奏保持不变,只是稍微没那么顺滑。
    const maxDeviceFrames = 32;
    final step = (def.frames / maxDeviceFrames).ceil();
    final delay = def.frameDelayMs * step;

    final frames = <Uint8List>[];
    for (var i = 0; i < def.frames; i += step) {
      final f = await Patterns.render(def, config, i, effectColor);
      frames.add(f.toRgbBytes(config));
    }
    await pushAnimation(frames, delay);
  }

  /// 音乐律动:只发 16 个频段能量 + 音量(20 字节),灯板自己渲染。
  /// 比推整帧(768 字节)省 97% 带宽,所以能跑到 30fps 以上。
  void sendSpectrum(List<double> bands, double volume) {
    _sendCmd(Protocol.spectrum(
      musicStyle,
      effectPalette,
      effectColor,
      (volume.clamp(0.0, 1.0) * 255).round(),
      [for (final b in bands) (b.clamp(0.0, 1.0) * 255).round()],
    ));
  }

  // ---- 灯板上报的真实状态(通过 Notify 收到) ----
  DateTime? deviceLastSeen;
  int? deviceMode;
  bool get deviceOnline =>
      deviceLastSeen != null &&
      DateTime.now().difference(deviceLastSeen!).inSeconds < 8;

  /// 处理灯板主动上报。目前只有状态包,兼作心跳。
  void onDeviceMessage(int op, List<int> p) {
    if (op == Protocol.opStatus && p.length >= 7) {
      deviceLastSeen = DateTime.now();
      deviceMode = p[0];
      notifyListeners();
    }
  }

  /// 效果在设备端跑,只发参数
  void pushEffect() {
    _panelModeFor(symmetric: true);
    mode = ModeEffect(effectId);
    _sendCmd(Protocol.effect(
        effectId, effectSpeed, effectIntensity, effectColor, effectPalette));
    notifyListeners();
  }

  /// 尾灯模式常驻设备端运行
  void pushTaillight() {
    _panelModeFor(symmetric: true);
    mode = ModeTail(tailMode);
    _sendCmd(Protocol.taillight(tailMode, tailStyle, effectColor, tailSpeed));
    notifyListeners();
  }

  /// 滚动文字位图:数据量较大
  Future<void> pushScrollText(
      int bitmapWidth, int height, int color, int speed, List<int> bits) async {
    _panelModeFor(symmetric: false); // 文字镜像后是反的,必须复制
    mode = const ModeScroll();
    notifyListeners();
    await _sendBulk(Protocol.scroll(bitmapWidth, height, color, speed, bits));
  }

  // ---- 传输进度(0..1,null 表示空闲),供界面显示进度条 ----
  double? sendProgress;
  String sendLabel = '';

  void _setProgress(double? v, [String label = '']) {
    sendProgress = v;
    sendLabel = label;
    notifyListeners();
  }

  /// 上传动画:开始 -> 逐帧 -> 结束播放。整体数据量大。
  Future<void> pushAnimation(List<Uint8List> frames, int delayMs) async {
    mode = const ModeAnimation();
    notifyListeners();
    final totalBytes = frames.fold<int>(0, (a, f) => a + f.length);

    // 先决定通道(按总量询问一次,避免逐帧弹窗)
    LinkTransport? link = _cmdLink;
    if (wifiEnabled && totalBytes >= highSpeedThresholdBytes) {
      final w = wifi;
      if (w != null && w.isConnected) {
        link = w;
      } else if (w != null && askUseWifi != null) {
        if (await askUseWifi!(totalBytes)) {
          if (await w.connect(wifiHost, wifiPort)) link = w;
        }
      }
    }
    if (link == null) return;

    try {
      _setProgress(0, '正在上传动画…');
      await link.sendPacket(Protocol.animBegin(frames.length, delayMs));
      for (var i = 0; i < frames.length; i++) {
        await link.sendPacket(Protocol.animFrame(i, frames[i]));
        _setProgress((i + 1) / frames.length, '正在上传动画 ${i + 1}/${frames.length}');
      }
      await link.sendPacket(Protocol.animEnd());
    } finally {
      _setProgress(null);
    }
  }

  // ============================================================
  // 持久化
  // ============================================================
  DeviceConfig _loadConfig() => DeviceConfig(
        width: prefs.getInt('w') ?? 20,
        height: prefs.getInt('h') ?? 40,
        serpentine: prefs.getBool('serp') ?? true,
        flipX: prefs.getBool('fx') ?? true,
        flipY: prefs.getBool('fy') ?? false,
        panels: prefs.getInt('panels') ?? 2,
        mirrorSecond: prefs.getBool('mirror2') ?? true,
      );

  void _saveConfig(DeviceConfig c) {
    prefs.setInt('w', c.width);
    prefs.setInt('h', c.height);
    prefs.setBool('serp', c.serpentine);
    prefs.setBool('fx', c.flipX);
    prefs.setBool('fy', c.flipY);
    prefs.setInt('panels', c.panels);
    prefs.setBool('mirror2', c.mirrorSecond);
  }

  void saveWifiSettings(bool enabled, String host, int port) {
    wifiEnabled = enabled;
    wifiHost = host;
    wifiPort = port;
    prefs.setBool('wifi_enabled', enabled);
    prefs.setString('wifi_host', host);
    prefs.setInt('wifi_port', port);
    notifyListeners();
  }

  void touch() => notifyListeners();
}
