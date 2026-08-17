import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/led_matrix.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';
import '../widgets/toast.dart';

enum Tool { pen, erase, fill, pick }

/// 对称绘制:画一笔同时镜像到其它象限
enum Mirror { none, horizontal, vertical, quad }

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
  final List<List<int>> _redoStack = [];

  Tool tool = Tool.pen;
  Mirror mirror = Mirror.none;
  bool showGrid = true;
  late int color;

  @override
  void initState() {
    super.initState();
    canvas = Frame(state.config.width, state.config.height);
    color = state.effectColor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.mode = const ModePicture();
      _commit();
    });
  }

  // ---------------- 撤销 / 重做 ----------------

  void _snapshot() {
    _undoStack.add(List<int>.from(canvas.pixels));
    if (_undoStack.length > 60) _undoStack.removeAt(0);
    // 新的一笔会让之前的重做记录失效
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    HapticFeedback.selectionClick();
    _redoStack.add(List<int>.from(canvas.pixels));
    final prev = _undoStack.removeLast();
    canvas.pixels.setRange(0, prev.length, prev);
    _commit();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    HapticFeedback.selectionClick();
    _undoStack.add(List<int>.from(canvas.pixels));
    final next = _redoStack.removeLast();
    canvas.pixels.setRange(0, next.length, next);
    _commit();
  }

  /// 换新对象触发重绘,同步到预览
  void _commit() {
    final f = Frame(canvas.width, canvas.height);
    f.pixels.setRange(0, canvas.pixels.length, canvas.pixels);
    state.currentFrame = f;
    state.touch();
    if (mounted) setState(() {});
  }

  // ---------------- 绘制 ----------------

  /// 一个点在当前对称模式下要落笔的所有位置
  List<List<int>> _mirroredPoints(int x, int y) {
    final mx = canvas.width - 1 - x;
    final my = canvas.height - 1 - y;
    switch (mirror) {
      case Mirror.horizontal:
        return [
          [x, y],
          [mx, y]
        ];
      case Mirror.vertical:
        return [
          [x, y],
          [x, my]
        ];
      case Mirror.quad:
        return [
          [x, y],
          [mx, y],
          [x, my],
          [mx, my]
        ];
      case Mirror.none:
        return [
          [x, y]
        ];
    }
  }

  void _paintAt(int x, int y) {
    if (x < 0 || y < 0 || x >= canvas.width || y >= canvas.height) return;

    // 取色器:吸一下就切回画笔,符合大多数绘图工具的习惯
    if (tool == Tool.pick) {
      final picked = canvas.get(x, y);
      HapticFeedback.selectionClick();
      setState(() {
        color = picked;
        tool = Tool.pen;
      });
      return;
    }

    if (tool == Tool.fill) {
      _floodFill(canvas, x, y, color);
      _commit();
      return;
    }

    final target = tool == Tool.erase ? 0xFF000000 : color;
    for (final p in _mirroredPoints(x, y)) {
      canvas.set(p[0], p[1], target);
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
                TopBar(
                  title: '像素编辑',
                  onBack: widget.onBack,
                  trailing: GestureDetector(
                    onTap: () => setState(() => showGrid = !showGrid),
                    child: Icon(
                      showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                      size: 20,
                      color: showGrid ? accent : textSecondary,
                    ),
                  ),
                ),

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
                      // 手势分两层,解决"画画时页面跟着滚动"的冲突:
                      //  · Listener 收原始指针事件,不参与手势竞技场,画笔一定跟手;
                      //  · 外层 GestureDetector 声明拖动但什么都不做,
                      //    把控制权从父级滚动视图手里抢过来。
                      return Listener(
                        onPointerDown: (e) {
                          if (tool != Tool.pick) _snapshot();
                          _handleTouch(e.localPosition, size);
                        },
                        onPointerMove: (e) {
                          if (tool == Tool.pick || tool == Tool.fill) return;
                          _handleTouch(e.localPosition, size);
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: (_) {},
                          onVerticalDragUpdate: (_) {},
                          onVerticalDragEnd: (_) {},
                          onHorizontalDragStart: (_) {},
                          onHorizontalDragUpdate: (_) {},
                          onHorizontalDragEnd: (_) {},
                          child: SizedBox(
                            width: size.width,
                            height: size.height,
                            child: LedPanelPreview(
                              frame: state.currentFrame,
                              showGrid: showGrid,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ---- 工具 ----
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final t in const [
                      (Tool.pen, '画笔'),
                      (Tool.erase, '橡皮'),
                      (Tool.fill, '填充'),
                      (Tool.pick, '取色'),
                    ]) ...[
                      if (t.$1 != Tool.pen) const SizedBox(width: 8),
                      Expanded(
                        child: ChipTag(
                          text: t.$2,
                          selected: tool == t.$1,
                          onTap: () => setState(() => tool = t.$1),
                        ),
                      ),
                    ],
                  ],
                ),

                // ---- 撤销 / 重做 / 清空 ----
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ActionChip(
                        icon: Icons.undo_rounded,
                        label: '撤销',
                        enabled: _undoStack.isNotEmpty,
                        onTap: _undo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionChip(
                        icon: Icons.redo_rounded,
                        label: '重做',
                        enabled: _redoStack.isNotEmpty,
                        onTap: _redo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionChip(
                        icon: Icons.delete_outline_rounded,
                        label: '清空',
                        enabled: true,
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

                // ---- 对称绘制 ----
                const SizedBox(height: 14),
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('对称绘制',
                          style:
                              TextStyle(fontSize: 13, color: textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final m in const [
                            (Mirror.none, '关闭'),
                            (Mirror.horizontal, '左右'),
                            (Mirror.vertical, '上下'),
                            (Mirror.quad, '四向'),
                          ]) ...[
                            if (m.$1 != Mirror.none) const SizedBox(width: 8),
                            Expanded(
                              child: ChipTag(
                                text: m.$2,
                                selected: mirror == m.$1,
                                onTap: () => setState(() => mirror = m.$1),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text('颜色',
                              style: TextStyle(
                                  fontSize: 13, color: textSecondary)),
                          const Spacer(),
                          // 当前色块,取色后能直观看到吸到了什么
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Color(color),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: glassBorder, width: 0.8),
                            ),
                          ),
                        ],
                      ),
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
                  onTap: () async {
                    final f = Frame(w, h);
                    f.pixels.setRange(0, canvas.pixels.length, canvas.pixels);
                    await state.pushFrame(f);
                    if (context.mounted) Toast.success(context, '画面已发送到灯板');
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

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: enabled ? accentContainer : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: enabled ? onAccentContainer : textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: enabled ? onAccentContainer : textSecondary)),
          ],
        ),
      ),
    );
  }
}
