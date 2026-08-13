import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'led_matrix.dart';

const typeEffect = 0;
const typeFrame = 1;
const typeTail = 2;

/// 一个可保存/回放的"场景"。效果类只存参数;手绘/图片类存像素。
class Preset {
  final String id;
  final String name;
  final int type;
  final int effectId;
  final int speed;
  final int intensity;
  final int color;
  final int palette;
  final int tailMode;
  final int tailStyle;
  final int w;
  final int h;
  final List<int>? pixels;
  final bool builtIn;

  const Preset({
    required this.id,
    required this.name,
    required this.type,
    this.effectId = 1,
    this.speed = 128,
    this.intensity = 160,
    this.color = 0xFFFF003C,
    this.palette = 1,
    this.tailMode = 1,
    this.tailStyle = 0,
    this.w = 16,
    this.h = 16,
    this.pixels,
    this.builtIn = false,
  });

  Frame? toFrame() {
    final px = pixels;
    if (px == null) return null;
    final f = Frame(w, h);
    final n = px.length < f.pixels.length ? px.length : f.pixels.length;
    f.pixels.setRange(0, n, px);
    return f;
  }
}

class PresetStore {
  final SharedPreferences prefs;
  PresetStore(this.prefs);

  static const _listKey = 'weideng_presets_list';
  static const _playlistKey = 'weideng_playlist';

  List<Preset> load() {
    final raw = prefs.getString(_listKey);
    if (raw == null) return _builtIns();
    try {
      final arr = jsonDecode(raw) as List;
      final out = arr.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
      return [..._builtIns(), ...out];
    } catch (_) {
      return _builtIns();
    }
  }

  Future<void> save(List<Preset> presets) async {
    final arr = presets.where((p) => !p.builtIn).map(_toJson).toList();
    await prefs.setString(_listKey, jsonEncode(arr));
  }

  // ---- 播放列表:存 (预设 id, 时长秒) ----
  List<MapEntry<String, int>> loadPlaylist() {
    final raw = prefs.getString(_playlistKey);
    if (raw == null) return [];
    try {
      final arr = jsonDecode(raw) as List;
      return arr
          .map((e) => MapEntry(e['id'] as String, e['sec'] as int))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePlaylist(List<MapEntry<String, int>> items) async {
    final arr = items.map((e) => {'id': e.key, 'sec': e.value}).toList();
    await prefs.setString(_playlistKey, jsonEncode(arr));
  }

  Map<String, dynamic> _toJson(Preset p) {
    final m = <String, dynamic>{
      'id': p.id,
      'name': p.name,
      'type': p.type,
      'effectId': p.effectId,
      'speed': p.speed,
      'intensity': p.intensity,
      'color': p.color,
      'palette': p.palette,
      'tailMode': p.tailMode,
      'tailStyle': p.tailStyle,
      'w': p.w,
      'h': p.h,
    };
    final px = p.pixels;
    if (px != null) {
      final sb = StringBuffer();
      for (final c in px) {
        sb.write((c & 0xFFFFFF).toRadixString(16).padLeft(6, '0'));
      }
      m['px'] = sb.toString();
    }
    return m;
  }

  Preset _fromJson(Map<String, dynamic> o) {
    final hex = (o['px'] as String?) ?? '';
    List<int>? px;
    if (hex.length >= 6) {
      px = List<int>.generate(
        hex.length ~/ 6,
        (i) => 0xFF000000 | int.parse(hex.substring(i * 6, i * 6 + 6), radix: 16),
      );
    }
    return Preset(
      id: o['id'] as String,
      name: o['name'] as String,
      type: o['type'] as int,
      effectId: (o['effectId'] as int?) ?? 1,
      speed: (o['speed'] as int?) ?? 128,
      intensity: (o['intensity'] as int?) ?? 160,
      color: (o['color'] as int?) ?? 0xFFFF003C,
      palette: (o['palette'] as int?) ?? 1,
      tailMode: (o['tailMode'] as int?) ?? 1,
      tailStyle: (o['tailStyle'] as int?) ?? 0,
      w: (o['w'] as int?) ?? 16,
      h: (o['h'] as int?) ?? 16,
      pixels: px,
    );
  }

  /// 内置场景,开箱即用
  List<Preset> _builtIns() => const [
        Preset(id: 'b_rainbow', name: '彩虹流动', type: typeEffect, effectId: 1, palette: 1, speed: 120, builtIn: true),
        Preset(id: 'b_fire', name: '火焰', type: typeEffect, effectId: 4, palette: 2, speed: 150, intensity: 190, builtIn: true),
        Preset(id: 'b_plasma', name: '等离子', type: typeEffect, effectId: 5, palette: 1, speed: 90, builtIn: true),
        Preset(id: 'b_comet', name: '红色流星', type: typeEffect, effectId: 3, palette: 0, color: 0xFFFF0000, speed: 170, builtIn: true),
        Preset(id: 'b_breath', name: '呼吸红', type: typeEffect, effectId: 2, palette: 0, color: 0xFFFF0028, speed: 70, builtIn: true),
        Preset(id: 'b_ripple', name: '水波', type: typeEffect, effectId: 8, palette: 3, speed: 110, builtIn: true),
        Preset(id: 'b_scan', name: '扫描', type: typeEffect, effectId: 9, palette: 0, color: 0xFFFF0000, speed: 140, builtIn: true),
        Preset(id: 'b_rain', name: '雨滴', type: typeEffect, effectId: 11, palette: 3, speed: 130, builtIn: true),
        Preset(id: 'b_star', name: '星点', type: typeEffect, effectId: 6, palette: 4, speed: 100, builtIn: true),
        Preset(id: 'b_swirl', name: '旋转色轮', type: typeEffect, effectId: 10, palette: 1, speed: 110, builtIn: true),
        Preset(id: 'b_brake', name: '刹车', type: typeTail, tailMode: 2, builtIn: true),
        Preset(id: 'b_turn', name: '流水转向', type: typeTail, tailMode: 4, tailStyle: 0, builtIn: true),
      ];
}
