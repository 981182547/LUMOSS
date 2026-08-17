import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';
import '../widgets/main_scaffold.dart';

/// 创作 Tab:进入各种创作工具
class CreateScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenEditor;
  final VoidCallback onOpenImage;
  final VoidCallback onOpenAnimation;
  final VoidCallback onOpenText;
  final VoidCallback onOpenPatterns;

  const CreateScreen({
    super.key,
    required this.state,
    required this.onOpenEditor,
    required this.onOpenImage,
    required this.onOpenAnimation,
    required this.onOpenText,
    required this.onOpenPatterns,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('创作',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)),
              const Text('做好的作品可以保存到场景库',
                  style: TextStyle(fontSize: 13, color: textSecondary)),

              const SizedBox(height: 16),
              Glass(
                radius: 20,
                padding: const EdgeInsets.all(10),
                child: LedPanelPreview(frame: state.currentFrame),
              ),

              const SizedBox(height: 18),
              _BigTool(
                icon: Icons.auto_awesome_rounded,
                title: '图案库',
                desc: '36 个现成图案:行车沟通 · 表情 · 可爱 · 车主题 · 节日',
                highlight: true,
                onTap: onOpenPatterns,
              ),

              const SizedBox(height: 12),
              _BigTool(
                icon: Icons.brush_rounded,
                title: '像素编辑器',
                desc: '逐点手绘,画笔 · 橡皮 · 填充 · 取色 · 对称 · 撤销重做',
                highlight: false,
                onTap: onOpenEditor,
              ),

              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SmallTool(
                        icon: Icons.image_rounded,
                        title: '图片',
                        desc: '照片转点阵',
                        onTap: onOpenImage,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SmallTool(
                        icon: Icons.movie_rounded,
                        title: 'GIF 动画',
                        desc: '拆帧播放',
                        onTap: onOpenAnimation,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SmallTool(
                icon: Icons.text_fields_rounded,
                title: '滚动文字',
                desc: '支持中文,任意字体',
                onTap: onOpenText,
              ),

              const SizedBox(height: bottomBarSpace),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigTool extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool highlight;
  final VoidCallback onTap;

  const _BigTool({
    required this.icon,
    required this.title,
    required this.desc,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 18,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: highlight ? brandGradient : null,
              color: highlight ? null : accentContainer,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon,
                size: 24,
                color: highlight ? Colors.white : onAccentContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textPrimary)),
                const SizedBox(height: 2),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 12, color: textSecondary, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallTool extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;

  const _SmallTool({
    required this.icon,
    required this.title,
    required this.desc,
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
              color: accentContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: onAccentContainer),
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
