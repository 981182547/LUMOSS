import 'package:flutter/material.dart';

import '../models/led_matrix.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';

const _toolPen = 0;
const _toolErase = 1;
const _toolFill = 2;

class PixelEditorScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onBack;

  const PixelEditorScreen({
    super.key,
    required this.state,
    required this.onBack,
  });

  @override
  State<PixelEditorScreen> createState() => _PixelEditorScreenState();
}

class _PixelEditorScreenState extends State<PixelEditorScreen> {
  AppState get state => widget.state;

  late Frame canvas;
  final List<List<int>> _undoStack = [];
  int tool = _toolPen;
  late int color;

  @override
  void initState() {
    super.initState();
    final w = state.config.width;
    final h = state.config.height;
    canvas = Frame(w, h);
    color = state.effectColor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.mode = const ModePicture();
      _commit();
    });
  }

  void _snapshot() {
    _undoStack.add(List<int>.from(canvas.pixels));
    if (_undoStack.length > 40) _undoStack.removeAt(0);
  }

  /// 换新对象触发重绘,同步到预览
  void _commit() {
    final f = Frame(canvas.width, canvas.height);
    f.pixels.setRange(0, canvas.pixels.length, canvas.pixels);
    state.currentFrame = f;
    state.touch();
    if (mounted) setState(() {});
  }

  void _paintAt(int x, int y) {
    if (x < 0 || y < 0 || x >= canvas.width || y >= canvas.height) return;
    switch (tool) {
      case _toolErase:
        canvas.set(x, y, 0xFF000000);
        break;
      case _toolFill:
        _floodFill(canvas, x, y, color);
        break;
      default:
        canvas.set(x, y, color);
    }
    _commit();
  }

  /// 油漆桶:把与起点同色的连通区域替换成新色
  static void _floodFill(Frame frame, int sx, int sy, int newColor) {
    final target = frame.get(sx, sy);
    if (target == newColor) return;
    final stack = <List<int>>[
      [sx, sy]
    ];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final x = p[0], y = p[1];
      if (x < 0 || y < 0 || x >= frame.width || y >= frame.height) continue;
      if (frame.get(x, y) != target) continue;
      frame.set(x, y, newColor);
      stack.add([x + 1, y]);
      stack.add([x - 1, y]);
      stack.add([x, y + 1]);
      stack.add([x, y - 1]);
    }
  }

  void _handleTouch(Offset localPos, Size size) {
    final cw = size.width / canvas.width;
    final ch = size.height / canvas.height;
    _paintAt((localPos.dx / cw).floor(), (localPos.dy / ch).floor());
  }

  @override
  Widget build(BuildContext context) {
    final w = canvas.width;
    final h = canvas.height;

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
                TopBar(title: '像素编辑', onBack: widget.onBack),

                const SizedBox(height: 16),
                // 可绘制的灯板画布
                Glass(
                  radius: 20,
                  padding: const EdgeInsets.all(10),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(
                        constraints.maxWidth,
                        constraints.maxWidth * h / w,
                      );
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) {
                          _snapshot();
                          _handleTouch(d.localPosition, size);
                        },
                        onPanUpdate: (d) => _handleTouch(d.localPosition, size),
                        onTapDown: (d) {
                          _snapshot();
                          _handleTouch(d.localPosition, size);
                        },
                        child: SizedBox(
                          width: size.width,
                          height: size.height,
                          child: LedPanelPreview(frame: state.currentFrame),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ChipTag(
                        text: '画笔',
                        selected: tool == _toolPen,
                        onTap: () => setState(() => tool = _toolPen),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChipTag(
                        text: '橡皮',
                        selected: tool == _toolErase,
                        onTap: () => setState(() => tool = _toolErase),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChipTag(
                        text: '填充',
                        selected: tool == _toolFill,
                        onTap: () => setState(() => tool = _toolFill),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChipTag(
                        text: '撤销',
                        selected: false,
                        onTap: () {
                          if (_undoStack.isEmpty) return;
                          final prev = _undoStack.removeLast();
                          canvas.pixels.setRange(0, prev.length, prev);
                          _commit();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChipTag(
                        text: '清空',
                        selected: false,
                        onTap: () {
                          _snapshot();
                          for (var i = 0; i < canvas.pixels.length; i++) {
                            canvas.pixels[i] = 0xFF000000;
                          }
                          _commit();
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
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
                        selected: color,
                        onPick: (c) => setState(() => color = c),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                PrimaryButton(
                  text: state.conn == ConnState.connected
                      ? '发送到灯板'
                      : '未连接 · 仅预览',
                  enabled: state.conn == ConnState.connected,
                  onTap: () {
                    final f = Frame(w, h);
                    f.pixels.setRange(0, canvas.pixels.length, canvas.pixels);
                    state.pushFrame(f);
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
