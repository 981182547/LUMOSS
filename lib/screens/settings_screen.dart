import 'package:flutter/material.dart';

import '../models/led_matrix.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';

class SettingsScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onBack;

  const SettingsScreen({super.key, required this.state, required this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppState get state => widget.state;

  late int w;
  late int h;
  late bool serp;
  late bool fx;
  late bool fy;
  late bool wifiOn;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;

  @override
  void initState() {
    super.initState();
    w = state.config.width;
    h = state.config.height;
    serp = state.config.serpentine;
    fx = state.config.flipX;
    fy = state.config.flipY;
    wifiOn = state.wifiEnabled;
    _hostCtrl = TextEditingController(text: state.wifiHost);
    _portCtrl = TextEditingController(text: '${state.wifiPort}');
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  /// 用当前设置渲染一个方向标识图,便于核对方向
  Frame _buildProbe() {
    final f = Frame(w, h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        f.set(x, y, rgb(20, 20, 30));
      }
    }
    // 左上角标红,顶行标绿,左列标蓝 —— 点亮后可核对方向
    for (var x = 0; x < w; x++) {
      f.set(x, 0, rgb(0, 180, 0));
    }
    for (var y = 0; y < h; y++) {
      f.set(0, y, rgb(0, 60, 255));
    }
    f.set(0, 0, rgb(255, 0, 0));
    return f;
  }

  @override
  Widget build(BuildContext context) {
    final probe = _buildProbe();
    final amps = (w * h * 0.06).toStringAsFixed(1);
    const presetSizes = [
      [8, 8], [16, 16], [32, 8], [32, 16],
      [32, 32], [8, 32], [64, 8], [64, 16],
    ];

    return Container(
      color: appBackground,
      child: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                TopBar(title: '灯板设置', onBack: widget.onBack),

                const SizedBox(height: 16),
                Glass(
                  radius: 20,
                  padding: const EdgeInsets.all(10),
                  child: LedPanelPreview(frame: probe),
                ),
                const SizedBox(height: 8),
                const Text(
                  '方向校验图:红点=左上角,绿线=第一行,蓝线=第一列。发送到灯板后若方向不符,调整下面开关。',
                  style: TextStyle(
                      fontSize: 11, color: textSecondary, height: 1.4),
                ),

                // ---- 尺寸 ----
                const SizedBox(height: 16),
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('尺寸',
                          style: TextStyle(
                              fontSize: 14,
                              color: textPrimary,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      NumberStepper(
                        label: '宽度 (列)',
                        value: w,
                        max: 64,
                        onChanged: (v) => setState(() => w = v),
                      ),
                      NumberStepper(
                        label: '高度 (行)',
                        value: h,
                        max: 64,
                        onChanged: (v) => setState(() => h = v),
                      ),
                      const SizedBox(height: 4),
                      Text('共 ${w * h} 颗灯珠 · 满白约 $amps A',
                          style: const TextStyle(
                              fontSize: 11, color: textSecondary)),
                      if (w * h > 1024)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '超过 1024 颗,固件默认的 MAX_LEDS 装不下,需要同步调大',
                            style: TextStyle(fontSize: 11, color: warnAmber),
                          ),
                        ),

                      const SizedBox(height: 12),
                      const Text('常用尺寸',
                          style:
                              TextStyle(fontSize: 12, color: textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in presetSizes)
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

                // ---- 走线方向 ----
                const SizedBox(height: 12),
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('走线方向',
                          style: TextStyle(
                              fontSize: 14,
                              color: textPrimary,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      _SwitchRow(
                        title: '蛇形走线 (S 形)',
                        desc: '逐行反向,大多数灯板都是',
                        value: serp,
                        onChanged: (v) => setState(() => serp = v),
                      ),
                      _SwitchRow(
                        title: '水平翻转',
                        desc: '信号从右侧进入时开启',
                        value: fx,
                        onChanged: (v) => setState(() => fx = v),
                      ),
                      _SwitchRow(
                        title: '垂直翻转',
                        desc: '信号从下方进入时开启',
                        value: fy,
                        onChanged: (v) => setState(() => fy = v),
                      ),
                    ],
                  ),
                ),

                // ---- WiFi 传输设置 ----
                const SizedBox(height: 12),
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SwitchRow(
                        title: 'WiFi 传输',
                        desc: '关闭时全部走蓝牙。日常够用,不会弹窗打扰',
                        value: wifiOn,
                        onChanged: (v) => setState(() => wifiOn = v),
                      ),
                      if (wifiOn) ...[
                        const Text(
                          '传图片、GIF 等大数据时会询问是否改用 WiFi,速度远快于蓝牙。'
                          '需要手机与灯板处于同一网络(或连灯板热点)。',
                          style: TextStyle(
                              fontSize: 11, color: textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _Field(
                                controller: _hostCtrl,
                                label: '灯板 IP',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Field(
                                controller: _portCtrl,
                                label: '端口',
                                number: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                PrimaryButton(
                  text: '保存并应用',
                  onTap: () {
                    state.updateConfig(DeviceConfig(
                      width: w,
                      height: h,
                      serpentine: serp,
                      flipX: fx,
                      flipY: fy,
                    ));
                    state.saveWifiSettings(
                      wifiOn,
                      _hostCtrl.text.trim().isEmpty
                          ? state.wifiHost
                          : _hostCtrl.text.trim(),
                      int.tryParse(_portCtrl.text.trim()) ?? state.wifiPort,
                    );
                    if (state.conn == ConnState.connected) {
                      state.pushFrame(probe);
                    }
                    widget.onBack();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.desc,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                s.contains(WidgetState.selected) ? Colors.white : textSecondary),
            trackColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? accent : accentContainer),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool number;

  const _Field({
    required this.controller,
    required this.label,
    this.number = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : null,
      style: const TextStyle(color: textPrimary, fontSize: 14),
      cursorColor: accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: textSecondary),
        isDense: true,
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: glassBorder)),
        focusedBorder:
            const OutlineInputBorder(borderSide: BorderSide(color: accent)),
      ),
    );
  }
}
