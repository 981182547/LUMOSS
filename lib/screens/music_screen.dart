import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/audio_analyzer.dart';
import '../models/led_matrix.dart';
import '../models/music_effects.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';

class MusicScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onBack;

  const MusicScreen({super.key, required this.state, required this.onBack});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen>
    with SingleTickerProviderStateMixin {
  AppState get state => widget.state;

  final _analyzer = AudioAnalyzer(bandCount: 16);
  List<double> bands = List<double>.filled(16, 0);
  String err = '';
  bool granted = false;

  Ticker? _ticker;
  final _stopwatch = Stopwatch();
  int _lastSend = 0;
  int _lastRender = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      state.mode = ModeMusic(state.musicStyle);
      await _startAnalyzer();
    });
  }

  Future<void> _startAnalyzer() async {
    final ok = await _analyzer.start();
    if (!mounted) return;
    setState(() {
      granted = ok;
      if (!ok) err = '需要麦克风权限才能律动';
    });
    if (ok) _startTicker();
  }

  /// 采集 + 渲染循环
  void _startTicker() {
    _stopwatch.start();
    _ticker?.dispose();
    _ticker = createTicker((_) {
      if (!mounted) return;
      final t = _stopwatch.elapsedMilliseconds;
      // 限到 ~30fps:每帧都要重建界面(频谱条 + 灯板预览),
      // 跑满刷新率只是白烧 CPU 和电,视觉上没差别
      if (t - _lastRender < 33) return;
      _lastRender = t;
      final f = Frame(state.config.width, state.config.height);
      MusicEffects.render(
        f,
        state.musicStyle,
        _analyzer.bands,
        _analyzer.volume,
        state.effectColor,
        state.effectPalette,
        t,
      );
      // touch() 已经会让整棵树重建,不用再 setState 一次
      bands = _analyzer.bands;
      state.currentFrame = f;
      state.touch();

      // 只发频谱数据(20 字节),画面由灯板自己渲染,
      // 所以这里可以跑到 33fps 而不会塞满蓝牙。
      if (state.conn == ConnState.connected && t - _lastSend > 30) {
        _lastSend = t;
        state.sendSpectrum(_analyzer.bands, _analyzer.volume);
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _analyzer.stop();
    _analyzer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                TopBar(title: '音乐律动', onBack: widget.onBack),

                const SizedBox(height: 16),
                Glass(
                  radius: 20,
                  padding: const EdgeInsets.all(10),
                  child: LedPanelPreview(frame: state.currentFrame),
                ),

                // 实时频谱条
                const SizedBox(height: 14),
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('实时频谱',
                          style:
                              TextStyle(fontSize: 13, color: textSecondary)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: CustomPaint(painter: _SpectrumPainter(bands)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                const Text('样式',
                    style: TextStyle(fontSize: 13, color: textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < MusicEffects.styles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: ChipTag(
                          text: MusicEffects.styles[i],
                          selected: state.musicStyle == i,
                          onTap: () {
                            setState(() => state.musicStyle = i);
                            state.mode = ModeMusic(i);
                          },
                        ),
                      ),
                    ],
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
                        selected: state.effectColor,
                        onPick: (c) => setState(() => state.effectColor = c),
                      ),
                    ],
                  ),
                ),

                if (err.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(err,
                      style:
                          const TextStyle(fontSize: 12, color: textSecondary)),
                ],
                if (!granted) ...[
                  const SizedBox(height: 12),
                  PrimaryButton(
                    text: '授予麦克风权限',
                    onTap: _startAnalyzer,
                  ),
                ],

                const SizedBox(height: 10),
                const Text(
                  '手机负责听音和频谱分析,只把 16 个频段的能量发给灯板(每帧 20 字节),'
                  '画面由灯板自己渲染,因此比推整帧流畅得多。需要保持本页在前台。',
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

class _SpectrumPainter extends CustomPainter {
  final List<double> bands;
  _SpectrumPainter(this.bands);

  @override
  void paint(Canvas canvas, Size size) {
    final n = bands.length;
    if (n == 0) return;
    const gap = 3.0;
    final bw = (size.width - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      final v = bands[i].clamp(0.0, 1.0);
      final bh = (size.height * v).clamp(2.0, size.height);
      final ratio = i / n;
      final c = Color.lerp(gradA, gradB, ratio)!;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (bw + gap), size.height - bh, bw, bh),
        Radius.circular(bw / 2),
      );
      canvas.drawRRect(rect, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) => true;
}
