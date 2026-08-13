import 'dart:async';

import 'package:flutter/material.dart';

import '../models/preset.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';
import '../widgets/main_scaffold.dart';

class ScenesScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onOpenMusic;
  final VoidCallback onOpenEffects;

  const ScenesScreen({
    super.key,
    required this.state,
    required this.onOpenMusic,
    required this.onOpenEffects,
  });

  @override
  State<ScenesScreen> createState() => _ScenesScreenState();
}

class _ScenesScreenState extends State<ScenesScreen> {
  Timer? _playlistTimer;
  AppState get state => widget.state;

  @override
  void didUpdateWidget(ScenesScreen old) {
    super.didUpdateWidget(old);
    _syncPlaylistTimer();
  }

  @override
  void initState() {
    super.initState();
    _syncPlaylistTimer();
  }

  /// 播放列表自动轮播
  void _syncPlaylistTimer() {
    _playlistTimer?.cancel();
    _playlistTimer = null;
    if (!state.playlistRunning || state.playlist.isEmpty) return;
    _scheduleNext(0);
  }

  void _scheduleNext(int i) {
    if (!mounted || !state.playlistRunning || state.playlist.isEmpty) return;
    final idx = i % state.playlist.length;
    final entry = state.playlist[idx];
    state.playlistIndex = idx;
    final matches = state.presets.where((p) => p.id == entry.key);
    if (matches.isNotEmpty) state.applyPreset(matches.first);
    final sec = entry.value < 1 ? 1 : entry.value;
    _playlistTimer = Timer(Duration(seconds: sec), () => _scheduleNext(i + 1));
  }

  @override
  void dispose() {
    _playlistTimer?.cancel();
    super.dispose();
  }

  Future<void> _showSaveDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardSurface,
        title: const Text('保存当前场景',
            style: TextStyle(
                color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: textPrimary),
          cursorColor: accent,
          decoration: const InputDecoration(
            labelText: '场景名称',
            labelStyle: TextStyle(fontSize: 12, color: textSecondary),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: glassBorder)),
            focusedBorder:
                OutlineInputBorder(borderSide: BorderSide(color: accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存',
                style:
                    TextStyle(color: accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final name = ctrl.text.trim().isEmpty ? '我的场景' : ctrl.text.trim();
      state.addPreset(state.captureCurrent(name));
    }
    ctrl.dispose();
  }

  Future<void> _confirmDelete(Preset p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardSurface,
        title: const Text('删除场景',
            style: TextStyle(color: textPrimary, fontSize: 16)),
        content: Text('确定删除「${p.name}」?',
            style: const TextStyle(color: textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除',
                style: TextStyle(
                    color: Color(0xFFFF5A6E), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) state.deletePreset(p);
  }

  @override
  Widget build(BuildContext context) {
    final rows = <List<Preset>>[];
    for (var i = 0; i < state.presets.length; i += 2) {
      rows.add(state.presets.sublist(
          i, (i + 2 > state.presets.length) ? state.presets.length : i + 2));
    }

    return SingleChildScrollView(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('场景',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: textPrimary)),
                        Text('${state.presets.length} 个场景',
                            style: const TextStyle(
                                fontSize: 13, color: textSecondary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showSaveDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: brandGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text('存当前',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 快捷入口
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _QuickCard(
                        title: '音乐律动',
                        desc: '跟着节奏跳动',
                        icon: Icons.graphic_eq_rounded,
                        highlight: true,
                        onTap: widget.onOpenMusic,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickCard(
                        title: '全部特效',
                        desc: '12 种可调效果',
                        icon: Icons.play_arrow_rounded,
                        highlight: false,
                        onTap: widget.onOpenEffects,
                      ),
                    ),
                  ],
                ),
              ),

              // 播放列表
              const SizedBox(height: 20),
              _PlaylistCard(
                state: state,
                onToggleRun: () {
                  setState(() {
                    state.playlistRunning = !state.playlistRunning;
                  });
                  _syncPlaylistTimer();
                },
              ),

              // 场景网格
              const SizedBox(height: 20),
              const Text('场景库',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textPrimary)),
              const SizedBox(height: 10),
              ...rows.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < 2; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(
                              child: i < row.length
                                  ? _SceneCard(
                                      preset: row[i],
                                      inPlaylist: state.playlist
                                          .any((e) => e.key == row[i].id),
                                      onApply: () =>
                                          state.applyPreset(row[i]),
                                      onDelete: () => _confirmDelete(row[i]),
                                      onTogglePlaylist: () {
                                        final id = row[i].id;
                                        final has = state.playlist
                                            .any((e) => e.key == id);
                                        state.updatePlaylist(has
                                            ? state.playlist
                                                .where((e) => e.key != id)
                                                .toList()
                                            : [
                                                ...state.playlist,
                                                MapEntry(id, 10)
                                              ]);
                                      },
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )),

              const SizedBox(height: bottomBarSpace),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final bool highlight;
  final VoidCallback onTap;

  const _QuickCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 16,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: highlight ? brandGradient : null,
              color: highlight ? null : accentContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                size: 20,
                color: highlight ? Colors.white : onAccentContainer),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textPrimary)),
          Text(desc,
              style: const TextStyle(fontSize: 11, color: textSecondary)),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final AppState state;
  final VoidCallback onToggleRun;

  const _PlaylistCard({required this.state, required this.onToggleRun});

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('播放列表',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: textPrimary)),
                    Text(
                      state.playlist.isEmpty
                          ? '点击场景卡片右上角 + 加入轮播'
                          : '${state.playlist.length} 个场景 · 自动轮播',
                      style: const TextStyle(
                          fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
              ),
              if (state.playlist.isNotEmpty)
                GestureDetector(
                  onTap: onToggleRun,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: state.playlistRunning ? brandGradient : null,
                      color: state.playlistRunning ? null : accentContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      state.playlistRunning
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      size: 20,
                      color: state.playlistRunning
                          ? Colors.white
                          : onAccentContainer,
                    ),
                  ),
                ),
            ],
          ),
          if (state.playlist.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...state.playlist.asMap().entries.map((e) {
              final i = e.key;
              final id = e.value.key;
              final sec = e.value.value;
              final matches = state.presets.where((p) => p.id == id);
              if (matches.isEmpty) return const SizedBox();
              final p = matches.first;
              final active = state.playlistRunning && state.playlistIndex == i;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? accentContainer : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 11, color: textSecondary)),
                    ),
                    Expanded(
                      child: Text(p.name,
                          style: TextStyle(
                              fontSize: 13,
                              color: active ? onAccentContainer : textPrimary)),
                    ),
                    // 时长调节
                    ...[5, 10, 30].map((s) => GestureDetector(
                          onTap: () {
                            final list = [...state.playlist];
                            list[i] = MapEntry(id, s);
                            state.updatePlaylist(list);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: sec == s ? accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                  color: sec == s ? accent : glassBorder,
                                  width: 0.8),
                            ),
                            child: Text('${s}s',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: sec == s
                                        ? Colors.white
                                        : textSecondary)),
                          ),
                        )),
                    GestureDetector(
                      onTap: () => state.updatePlaylist(
                          state.playlist.where((x) => x.key != id).toList()),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  final Preset preset;
  final bool inPlaylist;
  final VoidCallback onApply;
  final VoidCallback onDelete;
  final VoidCallback onTogglePlaylist;

  const _SceneCard({
    required this.preset,
    required this.inPlaylist,
    required this.onApply,
    required this.onDelete,
    required this.onTogglePlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 16,
      onTap: onApply,
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              PresetThumb(preset: preset, animated: true),
              // 加入播放列表按钮
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onTogglePlaylist,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: inPlaylist ? accent : const Color(0x99000000),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      inPlaylist ? Icons.close_rounded : Icons.add_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textPrimary)),
              ),
              if (!preset.builtIn)
                GestureDetector(
                  onTap: onDelete,
                  child: const Text('删除',
                      style: TextStyle(fontSize: 10, color: textSecondary)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
