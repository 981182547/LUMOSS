import 'dart:async';

import 'package:flutter/material.dart';

import '../models/text_render.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';

class TextScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onBack;

  const TextScreen({super.key, required this.state, required this.onBack});

  @override
  State<TextScreen> createState() => _TextScreenState();
}

class _TextScreenState extends State<TextScreen> {
  AppState get state => widget.state;

  final _textCtrl = TextEditingController(text: '你好');
  late int color;

  // 显示方式:true = 滚动,false = 静止
  bool scrolling = true;

  int speed = 140;
  int fontScale = 100; // 字号百分比
  int vOffset = 0; // 垂直偏移(像素),负数上移
  int align = 0; // 静止时的水平对齐:-1 左 0 中 1 右

  int _offset = 0;
  TextBitmap? _bmp;
  Timer? _scrollTimer;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    color = state.effectColor;
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildBitmap());
    _textCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _debounce?.cancel();
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _rebuildBitmap);
  }

  /// 渲染文字位图(支持中文),参数变化后都要重来一次
  Future<void> _rebuildBitmap() async {
    final bmp = await TextRender.renderText(
      _textCtrl.text,
      state.config.height,
      fontScale: fontScale / 100.0,
      verticalOffset: vOffset,
    );
    if (!mounted) return;
    setState(() => _bmp = bmp);
    _restartPreview();
  }

  /// 本地预览:滚动模式跑定时器,静止模式直接定格一帧
  void _restartPreview() {
    _scrollTimer?.cancel();
    final bmp = _bmp;
    if (bmp == null) return;

    if (!scrolling) {
      state.mode = const ModePicture();
      state.currentFrame =
          TextRender.staticFrame(bmp, state.config, color, align);
      state.touch();
      return;
    }

    state.mode = const ModeScroll();
    _offset = 0;
    final stepMs = (260 - speed).clamp(16, 260);
    _scrollTimer = Timer.periodic(Duration(milliseconds: stepMs), (_) {
      if (!mounted) return;
      state.currentFrame =
          TextRender.scrollFrame(bmp, state.config, _offset, color);
      state.touch();
      _offset++;
    });
  }

  /// 位图字节数,和固件的 MAX_SCROLL_BYTES 对齐
  static const _maxScrollBytes = 4096;

  int _bitmapBytes(TextBitmap b) => b.width * ((b.height + 7) ~/ 8);

  void _send() {
    final bmp = _bmp;
    if (bmp == null) return;
    if (scrolling) {
      // 超出固件缓冲会被静默丢弃,这里提前拦住并说清楚原因
      final bytes = _bitmapBytes(bmp);
      if (bytes > _maxScrollBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardSurface,
            content: Text(
              '文字太长了($bytes 字节,上限 $_maxScrollBytes)。'
              '请减少字数或调小字号。',
              style: const TextStyle(color: textPrimary, fontSize: 13),
            ),
          ),
        );
        return;
      }
      // 位图上传给灯板,滚动由灯板自己完成
      state.pushScrollText(
        bmp.width,
        state.config.height,
        color,
        speed,
        TextRender.toBits(bmp),
      );
    } else {
      // 静止就是一张普通画面,直接当整帧发送
      state.pushFrame(
          TextRender.staticFrame(bmp, state.config, color, align));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bmp = _bmp;
    final tooWide = !scrolling && bmp != null && bmp.width > state.config.width;

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
                TopBar(title: '文字显示', onBack: widget.onBack),

                const SizedBox(height: 16),
                Glass(
                  radius: 20,
                  padding: const EdgeInsets.all(10),
                  child: LedPanelPreview(
                    frame: state.currentFrame,
                    maxHeight: 200,
                    expandable: true,
                  ),
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: _textCtrl,
                  style: const TextStyle(color: textPrimary),
                  cursorColor: accent,
                  decoration: const InputDecoration(
                    labelText: '文字内容(支持中文)',
                    labelStyle: TextStyle(fontSize: 12, color: textSecondary),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: glassBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: accent)),
                  ),
                ),

                // ---- 显示方式 ----
                const SizedBox(height: 14),
                const Text('显示方式',
                    style: TextStyle(fontSize: 13, color: textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChipTag(
                        text: '滚动',
                        selected: scrolling,
                        onTap: () {
                          setState(() => scrolling = true);
                          _restartPreview();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChipTag(
                        text: '静止',
                        selected: !scrolling,
                        onTap: () {
                          setState(() => scrolling = false);
                          _restartPreview();
                        },
                      ),
                    ),
                  ],
                ),

                // ---- 位置与外观 ----
                const SizedBox(height: 14),
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 静止模式才需要选水平位置
                      if (!scrolling) ...[
                        const Text('水平位置',
                            style:
                                TextStyle(fontSize: 13, color: textSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final item in const [
                              (-1, '靠左'),
                              (0, '居中'),
                              (1, '靠右'),
                            ]) ...[
                              if (item.$1 != -1) const SizedBox(width: 8),
                              Expanded(
                                child: ChipTag(
                                  text: item.$2,
                                  selected: align == item.$1,
                                  onTap: () {
                                    setState(() => align = item.$1);
                                    _restartPreview();
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      LabeledSlider(
                        label: '垂直位置(负数上移)',
                        value: vOffset,
                        min: -(state.config.height ~/ 2),
                        max: state.config.height ~/ 2,
                        onChange: (v) => setState(() => vOffset = v),
                        onDone: _rebuildBitmap,
                      ),
                      LabeledSlider(
                        label: '字号 %',
                        value: fontScale,
                        min: 30,
                        max: 150,
                        onChange: (v) => setState(() => fontScale = v),
                        onDone: _rebuildBitmap,
                      ),
                      if (scrolling)
                        LabeledSlider(
                          label: '滚动速度',
                          value: speed,
                          min: 20,
                          max: 240,
                          onChange: (v) => setState(() => speed = v),
                          onDone: _restartPreview,
                        ),

                      const SizedBox(height: 8),
                      const Text('颜色',
                          style:
                              TextStyle(fontSize: 13, color: textSecondary)),
                      const SizedBox(height: 8),
                      ColorSwatches(
                        selected: color,
                        onPick: (c) {
                          setState(() => color = c);
                          _restartPreview();
                        },
                      ),
                    ],
                  ),
                ),

                if (tooWide) ...[
                  const SizedBox(height: 10),
                  Text(
                    '文字宽 ${bmp.width} 像素,超出灯板 ${state.config.width} 列,'
                    '两端会被裁掉。可以调小字号,或改用滚动显示。',
                    style: const TextStyle(
                        fontSize: 11, color: warnAmber, height: 1.4),
                  ),
                ],

                const SizedBox(height: 16),
                PrimaryButton(
                  text: state.conn == ConnState.connected
                      ? '发送到灯板'
                      : '未连接 · 仅预览',
                  enabled: state.conn == ConnState.connected && bmp != null,
                  onTap: _send,
                ),

                const SizedBox(height: 10),
                Text(
                  scrolling
                      ? '文字在手机上渲染成点阵后上传,因此中文和任何字体都能显示;滚动由灯板自己完成。'
                      : '静止文字作为一张画面发送,灯板会一直显示,手机断开也不受影响。',
                  style: const TextStyle(
                      fontSize: 11, color: textSecondary, height: 1.4),
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
