import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/effects.dart';
import '../models/led_matrix.dart';
import '../models/preset.dart';
import '../models/taillight.dart';
import '../theme.dart';

/// 模拟灯板显示效果:黑底 + 发光灯珠。
///
/// [maxHeight] 限制高度,避免大灯板在首页占掉整屏。
/// [expandable] 为 true 时点击可全屏查看。
class LedPanelPreview extends StatelessWidget {
  final Frame frame;
  final double? maxHeight;
  final bool expandable;

  const LedPanelPreview({
    super.key,
    required this.frame,
    this.maxHeight,
    this.expandable = false,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = frame.width / frame.height;
    Widget panel = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: panelBg,
        child: AspectRatio(
          aspectRatio: ratio,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: CustomPaint(
              painter: _PanelPainter(frame),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );

    if (maxHeight != null) {
      panel = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight!),
          child: panel,
        ),
      );
    }

    if (!expandable) return panel;

    return Stack(
      children: [
        panel,
        // 放大提示角标
        Positioned(
          right: 6,
          bottom: 6,
          child: IgnorePointer(
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
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => showPanelFullscreen(context, frame),
            ),
          ),
        ),
      ],
    );
  }
}

/// 全屏查看灯板。传 [listenable] 时会跟着状态实时刷新(特效/动画不会卡住)。
void showPanelFullscreen(
  BuildContext context,
  Frame frame, {
  Listenable? listenable,
  Frame Function()? liveFrame,
}) {
  showDialog(
    context: context,
    barrierColor: const Color(0xF2000000),
    builder: (ctx) {
      Widget content(Frame f) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LedPanelPreview(frame: f),
            ),
          );

      return GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          children: [
            if (listenable != null && liveFrame != null)
              ListenableBuilder(
                listenable: listenable,
                builder: (_, _) => content(liveFrame()),
              )
            else
              content(frame),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: const BoxDecoration(
                    color: Color(0x33FFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 20, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(ctx).padding.bottom + 24,
              left: 0,
              right: 0,
              child: const Center(
                child: Text('点击任意处关闭',
                    style: TextStyle(fontSize: 12, color: textSecondary)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PanelPainter extends CustomPainter {
  final Frame frame;
  _PanelPainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / frame.width;
    final cellH = size.height / frame.height;
    final cell = cellW < cellH ? cellW : cellH;
    final radius = cell * 0.42;
    final offsetX = (size.width - cell * frame.width) / 2;
    final offsetY = (size.height - cell * frame.height) / 2;
    // 灯珠很小时跳过辉光,否则一页十几个卡片会掉帧
    final drawGlow = cell > 7;

    final paint = Paint();
    final offPaint = Paint()..color = const Color(0xFF1A1A20);

    for (var y = 0; y < frame.height; y++) {
      for (var x = 0; x < frame.width; x++) {
        final argb = frame.get(x, y);
        final r = (argb >> 16) & 0xFF;
        final g = (argb >> 8) & 0xFF;
        final b = argb & 0xFF;
        final cx = offsetX + cell * x + cell / 2;
        final cy = offsetY + cell * y + cell / 2;
        final lit = (r + g + b) > 12;
        if (lit) {
          final color = Color.fromARGB(255, r, g, b);
          if (drawGlow) {
            paint.color = color.withValues(alpha: 0.35);
            canvas.drawCircle(Offset(cx, cy), radius * 1.8, paint);
          }
          paint.color = color;
          canvas.drawCircle(Offset(cx, cy), radius, paint);
        } else {
          canvas.drawCircle(Offset(cx, cy), radius * 0.85, offPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PanelPainter old) => true;
}

/// 场景缩略图。效果/尾灯类会真正动起来,缩略图用较小分辨率渲染以节省开销。
class PresetThumb extends StatefulWidget {
  final Preset preset;
  final bool animated;

  const PresetThumb({super.key, required this.preset, this.animated = true});

  @override
  State<PresetThumb> createState() => _PresetThumbState();
}

class _PresetThumbState extends State<PresetThumb> {
  late Frame _frame;
  Timer? _timer;
  late DateTime _start;

  int get _w => (widget.preset.type == typeEffect || widget.preset.type == typeTail)
      ? 12
      : widget.preset.w;
  int get _h => (widget.preset.type == typeEffect || widget.preset.type == typeTail)
      ? 12
      : widget.preset.h;

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();
    _frame = _renderAt(widget.preset, 0, _w, _h);
    _startTicker();
  }

  @override
  void didUpdateWidget(PresetThumb old) {
    super.didUpdateWidget(old);
    if (old.preset.id != widget.preset.id || old.animated != widget.animated) {
      _timer?.cancel();
      _start = DateTime.now();
      _frame = _renderAt(widget.preset, 0, _w, _h);
      _startTicker();
    }
  }

  void _startTicker() {
    if (!widget.animated || widget.preset.type == typeFrame) return;
    // 缩略图限流到 ~15fps:一页十几个卡片同时跑,全速会明显掉帧
    _timer = Timer.periodic(const Duration(milliseconds: 66), (_) {
      if (!mounted) return;
      final t = DateTime.now().difference(_start).inMilliseconds;
      setState(() => _frame = _renderAt(widget.preset, t, _w, _h));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static Frame _renderAt(Preset p, int t, int w, int h) {
    final f = Frame(w, h);
    switch (p.type) {
      case typeEffect:
        Effects.render(f, p.effectId, t, p.speed, p.intensity, p.color, p.palette);
        break;
      case typeTail:
        Taillight.render(f, p.tailMode, p.tailStyle, t, 140);
        break;
      default:
        final src = p.toFrame();
        if (src != null) {
          final n = src.pixels.length < f.pixels.length
              ? src.pixels.length
              : f.pixels.length;
          f.pixels.setRange(0, n, src.pixels);
        }
    }
    return f;
  }

  @override
  Widget build(BuildContext context) => LedPanelPreview(frame: _frame);
}

/// 实时预览循环:驱动 renderPreview,只在需要动画时运行。
class PreviewTicker extends StatefulWidget {
  final bool active;
  final void Function(int elapsedMs) onTick;
  final Widget child;

  const PreviewTicker({
    super.key,
    required this.active,
    required this.onTick,
    required this.child,
  });

  @override
  State<PreviewTicker> createState() => _PreviewTickerState();
}

class _PreviewTickerState extends State<PreviewTicker>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  late DateTime _start;

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();
    _ticker = createTicker((_) {
      if (widget.active) {
        widget.onTick(DateTime.now().difference(_start).inMilliseconds);
      }
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
