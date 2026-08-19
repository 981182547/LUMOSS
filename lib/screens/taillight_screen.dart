import 'package:flutter/material.dart';

import '../models/taillight.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';
import '../widgets/main_scaffold.dart';
import '../widgets/toast.dart';

/// 车灯 Tab。onBack 为 null 时作为 Tab 页显示(无返回箭头、底部留出底栏空间)
class TaillightScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback? onBack;

  const TaillightScreen({super.key, required this.state, this.onBack});

  @override
  State<TaillightScreen> createState() => _TaillightScreenState();
}

class _TaillightScreenState extends State<TaillightScreen> {
  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    // 进入本页即切到尾灯预览
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.mode = ModeTail(state.tailMode);
      state.touch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTurn = state.tailMode == Taillight.modeTurnL ||
        state.tailMode == Taillight.modeTurnR;

    final modeRows = <List<MapEntry<int, String>>>[];
    for (var i = 0; i < Taillight.modes.length; i += 3) {
      modeRows.add(Taillight.modes.sublist(
          i,
          (i + 3 > Taillight.modes.length)
              ? Taillight.modes.length
              : i + 3));
    }

    return Container(
      color: appBackground,
      child: SingleChildScrollView(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                if (widget.onBack != null)
                  TopBar(title: '车灯模式', onBack: widget.onBack!)
                else ...[
                  const Text('车灯模式',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: textPrimary)),
                  const Text('刹车 · 转向 · 位置灯 · 迎宾',
                      style: TextStyle(fontSize: 13, color: textSecondary)),
                ],

                const SizedBox(height: 16),
                Glass(
                  radius: 20,
                  padding: const EdgeInsets.all(10),
                  child: LedPanelPreview(
                    frame: state.currentFrame,
                    maxHeight: 240,
                    // 转向灯只亮一侧,必须按双屏真实样子预览才看得出来
                    dualMirror: state.config.panels == 2,
                    rightFrame: state.currentFrameRight,
                  ),
                ),

                const SizedBox(height: 16),
                const Text('灯光功能',
                    style: TextStyle(fontSize: 13, color: textSecondary)),
                const SizedBox(height: 8),
                ...modeRows.map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: i < row.length
                                  ? SizedBox(
                                      child: ChipTag(
                                        text: row[i].value,
                                        selected: state.tailMode == row[i].key,
                                        onTap: () {
                                          setState(() {
                                            state.tailMode = row[i].key;
                                          });
                                          state.mode = ModeTail(row[i].key);
                                          state.pushTaillight();
                                        },
                                      ),
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ],
                      ),
                    )),

                // 转向才需要选样式
                if (isTurn) ...[
                  const SizedBox(height: 8),
                  Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('转向样式',
                            style:
                                TextStyle(fontSize: 13, color: textSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (var i = 0;
                                i < Taillight.styles.length;
                                i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: ChipTag(
                                  text: Taillight.styles[i],
                                  selected: state.tailStyle == i,
                                  onTap: () {
                                    setState(() => state.tailStyle = i);
                                    state.pushTaillight();
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        LabeledSlider(
                          label: '速度',
                          value: state.tailSpeed,
                          min: 40,
                          max: 255,
                          onChange: (v) => setState(() => state.tailSpeed = v),
                          onDone: state.pushTaillight,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                PrimaryButton(
                  text: state.conn == ConnState.connected
                      ? '应用到灯板'
                      : '未连接 · 仅预览',
                  enabled: state.conn == ConnState.connected,
                  onTap: () {
                    state.pushTaillight();
                    Toast.success(context, '已应用车灯模式');
                  },
                ),

                const SizedBox(height: 14),
                // 安全提示
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: warnAmber.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('安全提示',
                          style: TextStyle(fontSize: 13, color: warnAmber)),
                      SizedBox(height: 4),
                      Text(
                        '刹车灯与转向灯属安全件,颜色、亮度、闪烁频率均有法规要求。'
                        '建议保留原厂灯具,本灯板作为改装展示或非行驶状态显示使用。',
                        style: TextStyle(
                            fontSize: 11, color: textSecondary, height: 1.45),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                const Text(
                  '尾灯模式常驻灯板运行,手机断开后照常工作。接入车辆 12V 信号后可自动切换。',
                  style: TextStyle(
                      fontSize: 11, color: textSecondary, height: 1.4),
                ),
                SizedBox(
                    height: widget.onBack != null ? 20 : bottomBarSpace),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
