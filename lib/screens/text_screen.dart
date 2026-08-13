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
  int speed = 140;
  int _offset = 0;

  TextBitmap? _bmp;
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    color = state.effectColor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.mode = const ModeScroll();
      _rebuildBitmap();
    });
    _textCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    super.dispose();
  }

  Timer? _debounce;
  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _rebuildBitmap);
  }

  /// 渲染文字位图(支持中文)
  Future<void> _rebuildBitmap() async {
    final bmp =
        await TextRender.renderText(_textCtrl.text, state.config.height);
    if (!mounted) return;
    setState(() => _bmp = bmp);
    _restartScroll();
  }

  /// 本地滚动预览
  void _restartScroll() {
    _scrollTimer?.cancel();
    final bmp = _bmp;
    if (bmp == null) return;
    _offset = 0;
    final stepMs = (260 - speed).clamp(16, 260);
    _scrollTimer =
        Timer.periodic(Duration(milliseconds: stepMs), (_) {
      if (!mounted) return;
      state.currentFrame =
          TextRender.scrollFrame(bmp, state.config, _offset, color);
      state.touch();
      _offset++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bmp = _bmp;
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
                TopBar(title: '滚动文字', onBack: widget.onBack),

                const SizedBox(height: 16),
                Glass(
                  radius: 20,
                  padding: const EdgeInsets.all(10),
                  child: LedPanelPreview(frame: state.currentFrame),
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: _textCtrl,
                  style: const TextStyle(color: textPrimary),
                  cursorColor: accent,
                  decoration: const InputDecoration(
                    labelText: '文字内容(支持中文)',
                    labelStyle:
                        TextStyle(fontSize: 12, color: textSecondary),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: glassBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: accent)),
                  ),
                ),

                const SizedBox(height: 14),
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LabeledSlider(
                        label: '滚动速度',
                        value: speed,
                        min: 20,
                        max: 240,
                        onChange: (v) => setState(() => speed = v),
                        onDone: _restartScroll,
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
                          _restartScroll();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                PrimaryButton(
                  text: state.conn == ConnState.connected
                      ? '发送到灯板'
                      : '未连接 · 仅预览',
                  enabled: state.conn == ConnState.connected && bmp != null,
                  onTap: () {
                    if (bmp == null) return;
                    state.pushScrollText(
                      bmp.width,
                      state.config.height,
                      color,
                      speed,
                      TextRender.toBits(bmp),
                    );
                  },
                ),

                const SizedBox(height: 10),
                const Text(
                  '文字在手机上渲染成点阵后上传,因此中文和任何字体都能显示;滚动由灯板自己完成。',
                  style: TextStyle(
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
