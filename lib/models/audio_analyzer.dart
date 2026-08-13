import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

/// 麦克风采集 + FFT 频谱分析。
/// 输出 N 个频段能量(0..1)和总音量,供灯板律动效果使用。
class AudioAnalyzer {
  static const _sampleRate = 44100;
  static const _fftSize = 1024; // 必须是 2 的幂

  final int bandCount;
  AudioAnalyzer({this.bandCount = 16})
      : bands = List<double>.filled(bandCount, 0),
        _smooth = List<double>.filled(bandCount, 0) {
    for (var i = 0; i < _fftSize; i++) {
      // Hann 窗
      _window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (_fftSize - 1));
    }
  }

  List<double> bands;
  double volume = 0;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  bool _running = false;

  final _re = Float64List(_fftSize);
  final _im = Float64List(_fftSize);
  final _window = Float64List(_fftSize);
  final List<double> _smooth;

  // PCM 缓冲:攒够一个 FFT 窗再处理
  final _pcmBuf = <double>[];

  bool get isRunning => _running;

  Future<bool> start() async {
    if (_running) return true;
    if (!await _recorder.hasPermission()) return false;

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );
      _running = true;
      _sub = stream.listen(_onData, onError: (_) {});
      return true;
    } catch (_) {
      _running = false;
      return false;
    }
  }

  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    _pcmBuf.clear();
    bands = List<double>.filled(bandCount, 0);
    volume = 0;
  }

  void dispose() {
    _recorder.dispose();
  }

  void _onData(Uint8List chunk) {
    // 16bit little-endian PCM -> [-1,1]
    final data = ByteData.sublistView(chunk);
    for (var i = 0; i + 1 < chunk.length; i += 2) {
      _pcmBuf.add(data.getInt16(i, Endian.little) / 32768.0);
    }
    while (_pcmBuf.length >= _fftSize) {
      _process(_pcmBuf.sublist(0, _fftSize));
      _pcmBuf.removeRange(0, _fftSize);
    }
    // 防止缓冲无限增长
    if (_pcmBuf.length > _fftSize * 4) {
      _pcmBuf.removeRange(0, _pcmBuf.length - _fftSize);
    }
  }

  void _process(List<double> pcm) {
    // 装填 + 加窗
    var sum = 0.0;
    for (var i = 0; i < _fftSize; i++) {
      final s = i < pcm.length ? pcm[i] : 0.0;
      sum += s * s;
      _re[i] = s * _window[i];
      _im[i] = 0;
    }
    volume = math.sqrt(sum / _fftSize).clamp(0.0, 1.0);

    _fft(_re, _im);

    // 对数分频:低频窄、高频宽,更符合听感
    final half = _fftSize ~/ 2;
    final out = List<double>.filled(bandCount, 0);
    for (var b = 0; b < bandCount; b++) {
      final lo = _binFor(b, half);
      var hi = _binFor(b + 1, half);
      if (hi <= lo) hi = lo + 1;
      if (hi > half) hi = half;
      var peak = 0.0;
      for (var k = lo; k < hi; k++) {
        final mag = math.sqrt(_re[k] * _re[k] + _im[k] * _im[k]);
        if (mag > peak) peak = mag;
      }
      // 压缩动态范围
      final db = (20 * math.log(peak + 1e-6) / math.ln10 + 60) / 60;
      out[b] = db.clamp(0.0, 1.0);
    }
    // 平滑:上升快、下降慢,视觉更稳
    for (var b = 0; b < bandCount; b++) {
      _smooth[b] = out[b] > _smooth[b]
          ? out[b]
          : _smooth[b] * 0.82 + out[b] * 0.18;
    }
    bands = List<double>.from(_smooth);
  }

  int _binFor(int band, int half) {
    final f = band / bandCount;
    // 20Hz ~ 16kHz 对数映射
    final hz = 20.0 * math.pow(800.0, f);
    return (hz / (_sampleRate / 2.0) * half).toInt().clamp(0, half - 1);
  }

  /// 原地基-2 FFT
  static void _fft(Float64List re, Float64List im) {
    final n = re.length;
    // 位反转置换
    var j = 0;
    for (var i = 1; i < n; i++) {
      var bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j |= bit;
      if (i < j) {
        var t = re[i];
        re[i] = re[j];
        re[j] = t;
        t = im[i];
        im[i] = im[j];
        im[j] = t;
      }
    }
    var len = 2;
    while (len <= n) {
      final ang = -2 * math.pi / len;
      final wr = math.cos(ang);
      final wi = math.sin(ang);
      var i = 0;
      while (i < n) {
        var curR = 1.0;
        var curI = 0.0;
        for (var k = 0; k < len ~/ 2; k++) {
          final uR = re[i + k];
          final uI = im[i + k];
          final vR = re[i + k + len ~/ 2] * curR - im[i + k + len ~/ 2] * curI;
          final vI = re[i + k + len ~/ 2] * curI + im[i + k + len ~/ 2] * curR;
          re[i + k] = uR + vR;
          im[i + k] = uI + vI;
          re[i + k + len ~/ 2] = uR - vR;
          im[i + k + len ~/ 2] = uI - vI;
          final nR = curR * wr - curI * wi;
          curI = curR * wi + curI * wr;
          curR = nR;
        }
        i += len;
      }
      len <<= 1;
    }
  }
}
