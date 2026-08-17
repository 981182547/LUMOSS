import 'package:flutter/material.dart';

import '../models/led_matrix.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/device_picker.dart';
import '../widgets/led_panel.dart';

/// 首次使用引导:连接 → 设尺寸 → 校验方向。
///
/// 这三步不做完 App 是没法正常用的,但新用户不可能自己猜到
/// (尤其"走线方向"藏在设置页深处)。走完一次就不再出现。
class OnboardingScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onDone;

  const OnboardingScreen({
    super.key,
    required this.state,
    required this.onDone,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  AppState get state => widget.state;
  int step = 0;

  // 第二步的尺寸配置
  late int w = state.config.width;
  late int h = state.config.height;
  late int panels = state.config.panels;

  // 第三步的方向配置
  late bool serp = state.config.serpentine;
  late bool fx = state.config.flipX;
  late bool fy = state.config.flipY;

  /// 方向校验图:红点=左上角,绿线=第一行,蓝线=第一列
  Frame _probe() {
    final f = Frame(w, h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        f.set(x, y, rgb(18, 18, 26));
      }
    }
    for (var x = 0; x < w; x++) {
      f.set(x, 0, rgb(0, 180, 0));
    }
    for (var y = 0; y < h; y++) {
      f.set(0, y, rgb(0, 60, 255));
    }
    f.set(0, 0, rgb(255, 0, 0));
    return f;
  }

  void _saveConfig() {
    state.updateConfig(DeviceConfig(
      width: w,
      height: h,
      serpentine: serp,
      flipX: fx,
      flipY: fy,
      panels: panels,
      mirrorSecond: state.config.mirrorSecond,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: appBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // 进度点
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    Container(
                      width: i == step ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        gradient: i == step ? brandGradient : null,
                        color: i == step ? null : accentContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    _saveConfig();
                    widget.onDone();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('跳过',
                        style:
                            TextStyle(fontSize: 13, color: textSecondary)),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: switch (step) {
                    0 => _stepConnect(),
                    1 => _stepSize(),
                    _ => _stepDirection(),
                  },
                ),
              ),

              // 底部按钮
              Row(
                children: [
                  if (step > 0)
                    Expanded(
                      child: ChipTag(
                        text: '上一步',
                        selected: false,
                        onTap: () => setState(() => step--),
                      ),
                    ),
                  if (step > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      text: step < 2 ? '下一步' : '开始使用',
                      onTap: () {
                        if (step < 2) {
                          setState(() => step++);
                        } else {
                          _saveConfig();
                          widget.onDone();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 第一步:连接 ----------------
  Widget _stepConnect() {
    final connected = state.conn == ConnState.connected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('LUMOSYNC',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: textPrimary)),
        const SizedBox(height: 6),
        const Text('先把灯板连上',
            style: TextStyle(fontSize: 15, color: textSecondary)),
        const SizedBox(height: 20),
        const Text(
          '给灯板上电,打开手机蓝牙,然后点下面的按钮搜索。\n'
          '搜到的设备里,灯板会带「灯板」标签排在最前面。',
          style: TextStyle(fontSize: 13, color: textSecondary, height: 1.6),
        ),
        const SizedBox(height: 24),
        Glass(
          radius: 16,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                connected
                    ? Icons.check_circle_rounded
                    : Icons.bluetooth_searching_rounded,
                size: 22,
                color: connected ? okGreen : accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  connected ? '灯板已连接' : (state.statusLog.isEmpty
                      ? '还没有连接'
                      : state.statusLog),
                  style: const TextStyle(fontSize: 13, color: textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!connected)
          PrimaryButton(
            text: '搜索灯板',
            onTap: () {
              final ble = state.ble;
              if (ble != null) showDevicePicker(context, ble);
            },
          ),
        const SizedBox(height: 14),
        const Text(
          '也可以先跳过。没连灯板时 App 里所有效果都能正常预览,\n只是不会真的点亮。',
          style: TextStyle(fontSize: 12, color: textSecondary, height: 1.5),
        ),
      ],
    );
  }

  // ---------------- 第二步:尺寸 ----------------
  Widget _stepSize() {
    const presets = [
      [8, 8], [16, 16], [20, 40], [32, 8], [32, 16], [32, 32],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('灯板多大?',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: textPrimary)),
        const SizedBox(height: 6),
        const Text('数一下灯珠的行数和列数,填错了图案会变形',
            style: TextStyle(fontSize: 13, color: textSecondary)),
        const SizedBox(height: 20),
        Glass(
          radius: 16,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NumberStepper(
                label: '宽度(列)',
                value: w,
                max: 64,
                onChanged: (v) => setState(() => w = v),
              ),
              NumberStepper(
                label: '高度(行)',
                value: h,
                max: 64,
                onChanged: (v) => setState(() => h = v),
              ),
              const SizedBox(height: 10),
              const Text('常用尺寸',
                  style: TextStyle(fontSize: 12, color: textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in presets)
                    ChipTag(
                      text: '${s[0]}×${s[1]}',
                      selected: w == s[0] && h == s[1],
                      onTap: () => setState(() {
                        w = s[0];
                        h = s[1];
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Glass(
          radius: 16,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('装了几块屏?',
                  style: TextStyle(fontSize: 13, color: textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChipTag(
                      text: '一块',
                      selected: panels == 1,
                      onTap: () => setState(() => panels = 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChipTag(
                      text: '两块(左右尾灯)',
                      selected: panels == 2,
                      onTap: () => setState(() => panels = 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                panels == 2
                    ? '两块屏串在同一条数据线上,共 ${w * h * 2} 颗灯珠。'
                        '上面填的是【单块】的尺寸。'
                    : '共 ${w * h} 颗灯珠',
                style: const TextStyle(
                    fontSize: 11, color: textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- 第三步:方向校验 ----------------
  Widget _stepDirection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('方向对不对?',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: textPrimary)),
        const SizedBox(height: 6),
        const Text('灯板的走线方式各家不同,不校一下图案可能是反的',
            style: TextStyle(fontSize: 13, color: textSecondary)),
        const SizedBox(height: 16),
        Glass(
          radius: 18,
          padding: const EdgeInsets.all(10),
          child: LedPanelPreview(
            frame: _probe(),
            maxHeight: 200,
            dualMirror: panels == 2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '把这张图发到灯板上,对照看:\n'
          '  · 红点应该在左上角\n'
          '  · 绿线应该是第一行\n'
          '  · 蓝线应该是第一列\n'
          '不对就调下面的开关,直到对上。',
          style: TextStyle(fontSize: 12, color: textSecondary, height: 1.6),
        ),
        const SizedBox(height: 14),
        Glass(
          radius: 16,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _toggle('蛇形走线', '逐行反向,大多数灯板都是', serp,
                  (v) => setState(() => serp = v)),
              _toggle('水平翻转', '信号从右侧进入时开启', fx,
                  (v) => setState(() => fx = v)),
              _toggle('垂直翻转', '信号从下方进入时开启', fy,
                  (v) => setState(() => fy = v)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (state.conn == ConnState.connected)
          PrimaryButton(
            text: '发送校验图到灯板',
            onTap: () {
              _saveConfig();
              state.pushFrame(_probe());
            },
          )
        else
          const Text('连上灯板后可以把校验图发过去实际对照。现在可以先跳过,'
              '以后在「设置」里随时能调。',
              style: TextStyle(
                  fontSize: 12, color: textSecondary, height: 1.5)),
      ],
    );
  }

  Widget _toggle(String title, String desc, bool value,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        const TextStyle(fontSize: 13, color: textPrimary)),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 11, color: textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? Colors.white
                    : textSecondary),
            trackColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? accent : accentContainer),
          ),
        ],
      ),
    );
  }
}
