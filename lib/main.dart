import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ble/ble_manager.dart';
import 'ble/wifi_manager.dart';
import 'screens/animation_screen.dart';
import 'screens/control_screen.dart';
import 'screens/create_screen.dart';
import 'screens/effects_screen.dart';
import 'screens/music_screen.dart';
import 'screens/pixel_editor_screen.dart';
import 'screens/scenes_screen.dart';
import 'screens/send_image_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/text_screen.dart';
import 'screens/taillight_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/device_picker.dart';
import 'widgets/led_panel.dart';
import 'widgets/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  final state = await AppState.create();
  runApp(WeidengApp(state: state));
}

class WeidengApp extends StatelessWidget {
  final AppState state;
  const WeidengApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LUMOSYNC',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomePage(state: state),
    );
  }
}

/// 从 Tab 里推出去的二级页面
enum SubScreen { none, image, effects, animation, editor, text, music, settings }

class HomePage extends StatefulWidget {
  final AppState state;
  const HomePage({super.key, required this.state});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppTab _tab = AppTab.control;
  SubScreen _sub = SubScreen.none;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();

    // 蓝牙管理器
    state.ble = BleManager(
      onState: (c) {
        state.conn = switch (c) {
          Conn.connected => ConnState.connected,
          Conn.disconnected => ConnState.disconnected,
          _ => ConnState.connecting,
        };
        // 连上后同步亮度和灯板配置
        if (c == Conn.connected) {
          state.pushBrightness();
          state.sendConfig();
        }
        if (mounted) setState(() {});
      },
      onLog: (m) {
        state.statusLog = m;
        if (mounted) setState(() {});
      },
      // 记住连上的灯板,下次自动连回去
      onRemember: state.rememberDevice,
      // 灯板主动上报的状态(心跳 / 当前模式等)
      onDeviceMessage: state.onDeviceMessage,
    );

    // 启动时自动连回上次的灯板,省掉每次手动选设备
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.ble?.tryAutoConnect(state.lastDeviceId);
    });

    // WiFi 管理器(大数据传输时用)
    state.wifi = WifiManager(
      onState: (_) {
        if (mounted) setState(() {});
      },
      onLog: (m) {
        state.statusLog = m;
        if (mounted) setState(() {});
      },
    );

    // 大数据传输时询问是否改用 WiFi
    state.askUseWifi = _askUseWifi;

    state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  /// 大数据传输时弹窗询问
  Future<bool> _askUseWifi(int bytes) async {
    final kb = (bytes / 1024).toStringAsFixed(1);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardSurface,
        title: const Text('改用 WiFi 传输?',
            style: TextStyle(color: textPrimary, fontSize: 17)),
        content: Text(
          '本次要传 $kb KB 数据,蓝牙会比较慢。\n'
          '是否改用 WiFi 传输?(需要手机和灯板在同一网络)\n\n'
          '灯板地址:${state.wifiHost}:${state.wifiPort}',
          style: const TextStyle(color: textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续用蓝牙',
                style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('用 WiFi', style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _onToggleConnect() async {
    final ble = state.ble;
    if (ble == null) return;
    if (state.conn != ConnState.disconnected) {
      await ble.disconnect();
    } else {
      // 弹出设备列表让用户自己选,而不是盲目连第一个
      await showDevicePicker(context, ble);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 实时预览循环:特效/尾灯模式下按帧驱动渲染
    return PreviewTicker(
      active: state.isAnimating,
      onTick: (t) => state.renderPreview(t),
      child: PopScope(
        canPop: _sub == SubScreen.none && _tab == AppTab.control,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          setState(() {
            if (_sub != SubScreen.none) {
              _sub = SubScreen.none;
            } else {
              _tab = AppTab.control;
            }
          });
        },
        child: Scaffold(
          backgroundColor: appBackground,
          body: Stack(
            children: [
              _sub != SubScreen.none ? _buildSub() : _buildMain(),
              // 大数据上传时的进度浮层:之前传 GIF 要等好几秒却毫无反馈
              if (state.sendProgress != null)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xB3000000),
                    child: Center(
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: glassBorder, width: 0.8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(state.sendLabel,
                                style: const TextStyle(
                                    fontSize: 13, color: textPrimary)),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: state.sendProgress,
                                minHeight: 6,
                                backgroundColor: accentContainer,
                                valueColor: const AlwaysStoppedAnimation(accent),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('${((state.sendProgress ?? 0) * 100).round()}%',
                                style: const TextStyle(
                                    fontSize: 12, color: textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSub() {
    void back() => setState(() => _sub = SubScreen.none);
    return switch (_sub) {
      SubScreen.effects => EffectsScreen(state: state, onBack: back),
      SubScreen.settings => SettingsScreen(state: state, onBack: back),
      SubScreen.editor => PixelEditorScreen(state: state, onBack: back),
      SubScreen.text => TextScreen(state: state, onBack: back),
      SubScreen.image => SendImageScreen(state: state, onBack: back),
      SubScreen.animation => AnimationScreen(state: state, onBack: back),
      SubScreen.music => MusicScreen(state: state, onBack: back),
      SubScreen.none => const SizedBox(),
    };
  }

  Widget _buildMain() {
    return MainScaffold(
      current: _tab,
      onSelect: (t) => setState(() => _tab = t),
      child: switch (_tab) {
        AppTab.control => ControlScreen(
            state: state,
            onOpenSettings: () => setState(() => _sub = SubScreen.settings),
            onToggleConnect: _onToggleConnect,
          ),
        AppTab.scenes => ScenesScreen(
            state: state,
            onOpenMusic: () => setState(() => _sub = SubScreen.music),
            onOpenEffects: () => setState(() => _sub = SubScreen.effects),
          ),
        AppTab.create => CreateScreen(
            state: state,
            onOpenEditor: () => setState(() => _sub = SubScreen.editor),
            onOpenImage: () => setState(() => _sub = SubScreen.image),
            onOpenAnimation: () => setState(() => _sub = SubScreen.animation),
            onOpenText: () => setState(() => _sub = SubScreen.text),
          ),
        AppTab.car => TaillightScreen(state: state),
      },
    );
  }
}
