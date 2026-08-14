import 'package:flutter/material.dart';

import '../models/led_matrix.dart';
import '../theme.dart';

/// 玻璃拟态卡片
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const Glass({
    super.key,
    required this.child,
    this.radius = 16,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget w = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glassBorder, width: 0.8),
      ),
      child: child,
    );
    if (onTap != null) {
      w = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: w,
        ),
      );
    }
    return w;
  }
}

/// 顶部返回栏
class TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  const TopBar({super.key, required this.title, required this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: const Icon(Icons.chevron_left_rounded, color: textPrimary, size: 28),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary)),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// 带标题和数值的滑条
class LabeledSlider extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChange;
  final VoidCallback? onDone;

  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    this.min = 0,
    this.max = 255,
    required this.onChange,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: textSecondary)),
            const Spacer(),
            Text('$value',
                style: const TextStyle(
                    fontSize: 13,
                    color: onAccentContainer,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbColor: accent,
            activeTrackColor: accent,
            inactiveTrackColor: accentContainer,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            onChanged: (v) => onChange(v.toInt()),
            onChangeEnd: (_) => onDone?.call(),
          ),
        ),
      ],
    );
  }
}

/// 数字步进器:加减按钮 + 可直接输入。
/// 比滑条更适合调"多少行多少列"这种需要精确值的场景。
class NumberStepper extends StatefulWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    this.min = 1,
    this.max = 64,
    required this.onChanged,
  });

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
    _focus = FocusNode()..addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(NumberStepper old) {
    super.didUpdateWidget(old);
    // 外部改了值(比如点了常用尺寸)时同步显示,但别打断正在输入的用户
    if (widget.value != old.value && !_focus.hasFocus) {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final v = int.tryParse(_ctrl.text.trim());
    final clamped = (v ?? widget.value).clamp(widget.min, widget.max);
    _ctrl.text = '$clamped';
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  void _step(int delta) {
    final v = (widget.value + delta).clamp(widget.min, widget.max);
    if (v != widget.value) {
      _ctrl.text = '$v';
      widget.onChanged(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(widget.label,
                style: const TextStyle(fontSize: 13, color: textSecondary)),
          ),
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: widget.value > widget.min,
            onTap: () => _step(-1),
          ),
          SizedBox(
            width: 58,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _commit(),
              style: const TextStyle(
                  fontSize: 16,
                  color: textPrimary,
                  fontWeight: FontWeight.w600),
              cursorColor: accent,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: widget.value < widget.max,
            onTap: () => _step(1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? accentContainer : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled ? onAccentContainer : textSecondary),
      ),
    );
  }
}

/// 主按钮(品牌渐变)
class PrimaryButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  const PrimaryButton({
    super.key,
    required this.text,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: enabled ? brandGradient : null,
          color: enabled ? null : accentContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: enabled ? Colors.white : textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 可选中的胶囊标签
class ChipTag extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const ChipTag({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? brandGradient : null,
          color: selected ? null : accentContainer,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : onAccentContainer,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 预设调色
final swatchColors = <int>[
  rgb(255, 0, 0), rgb(255, 60, 0), rgb(255, 150, 0), rgb(255, 230, 0),
  rgb(120, 255, 0), rgb(0, 255, 90), rgb(0, 220, 255), rgb(0, 90, 255),
  rgb(140, 0, 255), rgb(255, 0, 200), rgb(255, 90, 140), rgb(255, 255, 255),
];

class ColorSwatches extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onPick;

  const ColorSwatches({super.key, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final rows = <List<int>>[];
    for (var i = 0; i < swatchColors.length; i += 6) {
      rows.add(swatchColors.sublist(
          i, (i + 6 > swatchColors.length) ? swatchColors.length : i + 6));
    }
    return Column(
      children: rows
          .map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    for (var i = 0; i < row.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onPick(row[i]),
                          child: Container(
                            height: 34,
                            decoration: BoxDecoration(
                              color: Color(row[i]),
                              borderRadius: BorderRadius.circular(10),
                              border: row[i] == selected
                                  ? Border.all(color: Colors.white, width: 2.5)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ))
          .toList(),
    );
  }
}
