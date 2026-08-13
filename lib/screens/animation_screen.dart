import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/image_convert.dart';
import '../models/led_matrix.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';

class AnimationScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onBack;

  const AnimationScreen({super.key, required this.state, required this.onBack});

  @override
  State<AnimationScreen> createState() => _AnimationScreenState();
}

class _AnimationScreenState extends State<AnimationScreen> {
  AppState get state => widget.state;

  List<Frame> frames = [];
  int delayMs = 80;
  bool playing = true;
  int idx = 0;
  String status = '';
  bool loading = false;

  Timer? _playTimer;

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickGif() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() {
      loading = true;
      status = '正在解析…';
    });

    GifAnim? anim;
    try {
      final bytes = await file.readAsBytes();
      anim = loadGif(bytes, state.config);
    } catch (_) {
      anim = null;
    }

    if (!mounted) return;
    setState(() {
      loading = false;
      if (anim == null || anim.frames.isEmpty) {
        status = '无法解析,请选择 GIF 动图';
      } else {
        frames = anim.frames;
        delayMs = anim.delayMs;
        idx = 0;
        playing = true;
        state.mode = const ModeAnimation();
        status = '共 ${anim.frames.length} 帧 · ${anim.delayMs}ms/帧';
      }
    });
    _restartPlayback();
  }

  /// 本地播放预览
  void _restartPlayback() {
    _playTimer?.cancel();
    if (frames.isEmpty || !playing) return;
    _playTimer = Timer.periodic(Duration(milliseconds: delayMs), (_) {
      if (!mounted || frames.isEmpty) return;
      state.currentFrame = frames[idx % frames.length];
      state.touch();
      setState(() => idx = (idx + 1) % frames.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = loading
        ? '解析中…'
        : frames.isEmpty
            ? '先选择一个 GIF'
            : state.conn != ConnState.connected
                ? '未连接 · 仅预览'
                : '上传到灯板 (${frames.length} 帧)';

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
                TopBar(title: '动画', onBack: widget.onBack),

                const SizedBox(height: 16),
                Glass(
                  radius: 20,
                  padding: const EdgeInsets.all(10),
                  child: LedPanelPreview(frame: state.currentFrame),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChipTag(
                        text: '选择 GIF',
                        selected: false,
                        onTap: _pickGif,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChipTag(
                        text: playing ? '暂停' : '播放',
                        selected: playing,
                        onTap: () {
                          setState(() => playing = !playing);
                          _restartPlayback();
                        },
                      ),
                    ),
                  ],
                ),

                if (frames.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LabeledSlider(
                          label: '帧间隔 (ms)',
                          value: delayMs,
                          min: 20,
                          max: 300,
                          onChange: (v) => setState(() => delayMs = v),
                          onDone: _restartPlayback,
                        ),
                        Text('帧数 ${frames.length} · 第 ${idx + 1} 帧',
                            style: const TextStyle(
                                fontSize: 11, color: textSecondary)),
                      ],
                    ),
                  ),
                ],

                if (status.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(status,
                      style:
                          const TextStyle(fontSize: 12, color: textSecondary)),
                ],

                const SizedBox(height: 16),
                PrimaryButton(
                  text: buttonText,
                  enabled: frames.isNotEmpty &&
                      !loading &&
                      state.conn == ConnState.connected,
                  onTap: () async {
                    final rgbFrames = <Uint8List>[
                      for (final f in frames) f.toRgbBytes(state.config)
                    ];
                    // 总量大时会询问是否改用 WiFi
                    await state.pushAnimation(rgbFrames, delayMs);
                    if (!mounted) return;
                    setState(() =>
                        status = '已上传 ${frames.length} 帧,灯板将循环播放');
                  },
                ),

                const SizedBox(height: 10),
                const Text(
                  '动画上传后存在灯板中循环播放,不需要手机保持连接。帧数过多会占用灯板内存,建议 32 帧以内。',
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
