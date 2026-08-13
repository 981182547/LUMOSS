import 'package:flutter/material.dart';

import '../models/effects.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';

class EffectsScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onBack;

  const EffectsScreen({super.key, required this.state, required this.onBack});

  @override
  State<EffectsScreen> createState() => _EffectsScreenState();
}

class _EffectsScreenState extends State<EffectsScreen> {
  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    // 进入即进入特效模式并开始预览
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.mode = ModeEffect(state.effectId);
      state.touch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = <List<EffectDef>>[];
    for (var i = 0; i < Effects.all.length; i += 3) {
      rows.add(Effects.all.sublist(
          i, (i + 3 > Effects.all.length) ? Effects.all.length : i + 3));
    }

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
                TopBar(title: '特效', onBack: widget.onBack),

                const SizedBox(height: 16),
                Glass(
                  radius: 20,
                  padding: const EdgeInsets.all(10),
                  child: LedPanelPreview(frame: state.currentFrame),
                ),

                const SizedBox(height: 16),
                const Text('效果',
                    style: TextStyle(fontSize: 13, color: textSecondary)),
                const SizedBox(height: 8),
                ...rows.map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: i < row.length
                                    ? _EffectCell(
                                        def: row[i],
                                        selected: state.effectId == row[i].id,
                                        onTap: () {
                                          setState(() {
                                            state.effectId = row[i].id;
                                          });
                                          state.mode = ModeEffect(row[i].id);
                                          state.pushEffect();
                                        },
                                      )
                                    : const SizedBox(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )),

                const SizedBox(height: 8),
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LabeledSlider(
                        label: '速度',
                        value: state.effectSpeed,
                        onChange: (v) => setState(() => state.effectSpeed = v),
                        onDone: state.pushEffect,
                      ),
                      LabeledSlider(
                        label: '强度',
                        value: state.effectIntensity,
                        onChange: (v) =>
                            setState(() => state.effectIntensity = v),
                        onDone: state.pushEffect,
                      ),

                      const SizedBox(height: 8),
                      const Text('配色',
                          style:
                              TextStyle(fontSize: 13, color: textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < Palettes.names.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: ChipTag(
                                text: Palettes.names[i],
                                selected: state.effectPalette == i,
                                onTap: () {
                                  setState(() => state.effectPalette = i);
                                  state.pushEffect();
                                },
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (state.effectPalette == 0) ...[
                        const SizedBox(height: 14),
                        const Text('颜色',
                            style:
                                TextStyle(fontSize: 13, color: textSecondary)),
                        const SizedBox(height: 8),
                        ColorSwatches(
                          selected: state.effectColor,
                          onPick: (c) {
                            setState(() => state.effectColor = c);
                            state.pushEffect();
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                PrimaryButton(
                  text: state.conn == ConnState.connected
                      ? '应用到灯板'
                      : '未连接 · 仅预览',
                  enabled: state.conn == ConnState.connected,
                  onTap: state.pushEffect,
                ),

                const SizedBox(height: 10),
                const Text('效果在灯板上运行,手机断开后依然继续。',
                    style: TextStyle(fontSize: 11, color: textSecondary)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EffectCell extends StatelessWidget {
  final EffectDef def;
  final bool selected;
  final VoidCallback onTap;

  const _EffectCell({
    required this.def,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        decoration: BoxDecoration(
          gradient: selected ? brandGradient : null,
          color: selected ? null : accentContainer,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(def.label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : textPrimary)),
            const SizedBox(height: 2),
            Text(def.desc,
                style: TextStyle(
                    fontSize: 10,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.75)
                        : onAccentContainer)),
          ],
        ),
      ),
    );
  }
}
