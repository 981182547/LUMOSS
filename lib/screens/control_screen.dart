import 'package:flutter/material.dart';

import '../models/effects.dart';
import '../models/preset.dart';
import '../models/taillight.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';
import '../widgets/main_scaffold.dart';

class ControlScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleConnect;

  const ControlScreen({
    super.key,
    required this.state,
    required this.onOpenSettings,
    required this.onToggleConnect,
  });

  String _modeLabel() {
    final m = state.mode;
    if (m is ModeEffect) {
      final e = Effects.all.where((e) => e.id == m.id);
      return '正在播放 · ${e.isNotEmpty ? e.first.label : "特效"}';
    }
    if (m is ModeTail) {
      final t = Taillight.modes.where((e) => e.key == m.mode);
      return '车灯模式 · ${t.isNotEmpty ? t.first.value : ""}';
    }
    if (m is ModeMusic) return '音乐律动';
    if (m is ModePicture) return '静态画面';
    if (m is ModeAnimation) return '动画播放中';
    if (m is ModeScroll) return '滚动文字';
    return '待机';
  }

  @override
  Widget build(BuildContext context) {
    final quick = state.presets.where((p) => p.builtIn).take(6).toList();
    final rows = <List<Preset>>[];
    for (var i = 0; i < quick.length; i += 3) {
      rows.add(quick.sublist(i, (i + 3 > quick.length) ? quick.length : i + 3));
    }

    return SingleChildScrollView(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LUMOSYNC',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: textPrimary)),
                        Text(
                          '${state.config.width} × ${state.config.height} · ${state.config.count} 灯珠',
                          style: const TextStyle(
                              fontSize: 13, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onOpenSettings,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                          color: accentContainer, shape: BoxShape.circle),
                      child: const Icon(Icons.settings_rounded,
                          size: 19, color: onAccentContainer),
                    ),
                  ),
                ],
              ),

              // 连接状态条
              const SizedBox(height: 14),
              _ConnectionBar(state: state, onToggle: onToggleConnect),

              // 预览:限高显示,点击可全屏放大
              const SizedBox(height: 16),
              Glass(
                radius: 22,
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: () => showPanelFullscreen(
                    context,
                    state.currentFrame,
                    listenable: state,
                    liveFrame: () => state.currentFrame,
                  ),
                  child: Stack(
                    children: [
                      LedPanelPreview(
                        frame: state.currentFrame,
                        maxHeight: 210,
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0x66000000),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.open_in_full_rounded,
                              size: 13, color: Color(0xCCFFFFFF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 当前模式
              const SizedBox(height: 12),
              Text(_modeLabel(),
                  style: const TextStyle(fontSize: 13, color: textSecondary)),

              // 电源 + 亮度
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 10, child: _PowerCard(state: state)),
                    const SizedBox(width: 12),
                    Expanded(flex: 16, child: _BrightCard(state: state)),
                  ],
                ),
              ),

              // 快捷场景
              const SizedBox(height: 20),
              const Text('快捷场景',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textPrimary)),
              const SizedBox(height: 10),
              ...rows.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: i < row.length
                                ? _QuickScene(
                                    preset: row[i],
                                    onTap: () => state.applyPreset(row[i]),
                                  )
                                : const SizedBox(),
                          ),
                        ],
                      ],
                    ),
                  )),

              const SizedBox(height: bottomBarSpace),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionBar extends StatelessWidget {
  final AppState state;
  final VoidCallback onToggle;

  const _ConnectionBar({required this.state, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    late Color dot;
    late String label;
    late String hint;
    switch (state.conn) {
      case ConnState.connected:
        dot = okGreen;
        label = '已连接';
        hint = state.statusLog.isEmpty ? '灯板在线' : state.statusLog;
        break;
      case ConnState.connecting:
        dot = accent;
        label = '连接中';
        hint = state.statusLog.isEmpty ? '正在搜索灯板…' : state.statusLog;
        break;
      case ConnState.disconnected:
        dot = textSecondary;
        label = '未连接';
        hint = state.statusLog.isEmpty ? '点击连接灯板' : state.statusLog;
    }

    return Glass(
      radius: 16,
      onTap: onToggle,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
                color: accentContainer, shape: BoxShape.circle),
            child: Icon(Icons.bluetooth_rounded, size: 17, color: dot),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        color: textPrimary,
                        fontWeight: FontWeight.w500)),
                Text(hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: textSecondary)),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

class _PowerCard extends StatelessWidget {
  final AppState state;
  const _PowerCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final on = state.powerOn;
    return Glass(
      radius: 18,
      padding: const EdgeInsets.all(16),
      onTap: () {
        state.powerOn = !state.powerOn;
        state.pushPower();
        state.touch();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: on ? brandGradient : null,
              color: on ? null : accentContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.power_settings_new_rounded,
                size: 22, color: on ? Colors.white : textSecondary),
          ),
          const SizedBox(height: 10),
          Text(on ? '已开启' : '已关闭',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textPrimary)),
          const Text('电源',
              style: TextStyle(fontSize: 11, color: textSecondary)),
        ],
      ),
    );
  }
}

class _BrightCard extends StatelessWidget {
  final AppState state;
  const _BrightCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.light_mode_rounded, size: 18, color: accent),
              const SizedBox(width: 6),
              const Text('亮度',
                  style: TextStyle(fontSize: 13, color: textSecondary)),
              const Spacer(),
              Text('${(state.brightness * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 15,
                      color: onAccentContainer,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbColor: accent,
              activeTrackColor: accent,
              inactiveTrackColor: accentContainer,
            ),
            child: Slider(
              value: state.brightness,
              onChanged: (v) {
                state.brightness = v;
                state.touch();
              },
              onChangeEnd: (_) => state.pushBrightness(),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickScene extends StatelessWidget {
  final Preset preset;
  final VoidCallback onTap;

  const _QuickScene({required this.preset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 14,
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PresetThumb(preset: preset, animated: true),
          const SizedBox(height: 6),
          Text(preset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: textPrimary)),
        ],
      ),
    );
  }
}
