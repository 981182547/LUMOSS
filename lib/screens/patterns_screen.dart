import 'dart:async';

import 'package:flutter/material.dart';

import '../models/led_matrix.dart';
import '../models/patterns.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';
import '../widgets/toast.dart';

/// 图案库:分类浏览 + 实时预览 + 一键发送
class PatternsScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onBack;

  const PatternsScreen({super.key, required this.state, required this.onBack});

  @override
  State<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends State<PatternsScreen> {
  AppState get state => widget.state;

  PatternCat cat = PatternCat.drive;
  PatternDef? selected;
  Timer? _animTimer;
  int _frame = 0;

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  /// 选中图案后在本地循环预览
  Future<void> _select(PatternDef def) async {
    _animTimer?.cancel();
    setState(() {
      selected = def;
      _frame = 0;
    });
    state.mode = const ModePicture();
    await _renderFrame(def, 0);

    if (def.animated) {
      _animTimer =
          Timer.periodic(Duration(milliseconds: def.frameDelayMs), (_) async {
        if (!mounted) return;
        _frame = (_frame + 1) % def.frames;
        await _renderFrame(def, _frame);
      });
    }
  }

  Future<void> _renderFrame(PatternDef def, int frame) async {
    final f = await Patterns.render(def, state.config, frame, state.effectColor);
    if (!mounted) return;
    state.currentFrame = f;
    state.touch();
  }

  @override
  Widget build(BuildContext context) {
    final list = Patterns.byCat(cat);
    final sel = selected;

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
                TopBar(title: '图案库', onBack: widget.onBack),

                const SizedBox(height: 16),
                Glass(
                  radius: 20,
                  padding: const EdgeInsets.all(10),
                  child: LedPanelPreview(
                    frame: state.currentFrame,
                    maxHeight: 240,
                    dualMirror: state.config.panels == 2,
                  ),
                ),

                if (sel != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(sel.name,
                          style: const TextStyle(
                              fontSize: 14,
                              color: textPrimary,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      if (sel.animated)
                        const Text('动图',
                            style: TextStyle(fontSize: 11, color: accent)),
                      const Spacer(),
                      // 不对称的图案会提示双屏用复制而不是镜像
                      if (!sel.symmetric && state.config.panels == 2)
                        const Text('双屏复制显示',
                            style:
                                TextStyle(fontSize: 11, color: textSecondary)),
                    ],
                  ),
                ],

                // ---- 分类 ----
                const SizedBox(height: 14),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final c in PatternCat.values) ...[
                        ChipTag(
                          text: patternCatNames[c]!,
                          selected: cat == c,
                          onTap: () => setState(() => cat = c),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),

                // ---- 图案网格 ----
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (context, i) => _PatternCell(
                    def: list[i],
                    config: state.config,
                    color: state.effectColor,
                    selected: selected?.id == list[i].id,
                    onTap: () => _select(list[i]),
                  ),
                ),

                const SizedBox(height: 16),
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('颜色',
                          style:
                              TextStyle(fontSize: 13, color: textSecondary)),
                      const SizedBox(height: 8),
                      ColorSwatches(
                        selected: state.effectColor,
                        onPick: (c) {
                          setState(() => state.effectColor = c);
                          final s = selected;
                          if (s != null) _renderFrame(s, _frame);
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text('部分图案(南瓜、圣诞树、企鹅等)用固定配色,不受这里影响',
                          style: TextStyle(
                              fontSize: 11, color: textSecondary, height: 1.4)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                PrimaryButton(
                  text: state.conn == ConnState.connected
                      ? (sel == null ? '先选一个图案' : '发送到灯板')
                      : '未连接 · 仅预览',
                  enabled: sel != null && state.conn == ConnState.connected,
                  onTap: () async {
                    if (sel == null) return;
                    await state.pushPattern(sel);
                    if (context.mounted) {
                      Toast.success(context, '已发送「${sel.name}」到灯板');
                    }
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

/// 图案缩略图。用小分辨率渲染,一屏几十个也不卡。
class _PatternCell extends StatefulWidget {
  final PatternDef def;
  final DeviceConfig config;
  final int color;
  final bool selected;
  final VoidCallback onTap;

  const _PatternCell({
    required this.def,
    required this.config,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_PatternCell> createState() => _PatternCellState();
}

class _PatternCellState extends State<_PatternCell> {
  Frame? _thumb;

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(_PatternCell old) {
    super.didUpdateWidget(old);
    if (old.color != widget.color || old.def.id != widget.def.id) _build();
  }

  Future<void> _build() async {
    // 缩略图用较小尺寸,但保持屏幕的长宽比
    final ratio = widget.config.height / widget.config.width;
    final tw = 14;
    final th = (14 * ratio).round().clamp(8, 28);
    final cfg = widget.config.copyWith(width: tw, height: th);
    final f = await Patterns.render(widget.def, cfg, 0, widget.color);
    if (mounted) setState(() => _thumb = f);
  }

  @override
  Widget build(BuildContext context) {
    final t = _thumb;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: widget.selected ? accentContainer : cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.selected ? accent : glassBorder,
            width: widget.selected ? 1.2 : 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: t == null
                  ? const SizedBox()
                  : LedPanelPreview(frame: t),
            ),
            const SizedBox(height: 4),
            Text(
              widget.def.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: widget.selected ? onAccentContainer : textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
