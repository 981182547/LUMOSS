import 'dart:math' as math;

import 'led_matrix.dart';
import 'pattern_paint.dart';
import 'patterns_premium.dart';
import 'text_render.dart';

enum PatternCat { premium, warm, animal, drive, face, cute, car, festival }

const patternCatNames = {
  PatternCat.premium: '高级',
  PatternCat.warm: '温馨',
  PatternCat.animal: '动物',
  PatternCat.drive: '行车沟通',
  PatternCat.face: '表情',
  PatternCat.cute: '可爱',
  PatternCat.car: '车主题',
  PatternCat.festival: '节日',
};

/// 一个可显示的图案。
///
/// 用绘制函数而不是硬编码位图:同一个图案能自动适配 16×16、20×40 等任意尺寸。
/// [symmetric] 为 false 的(文字、箭头这类有左右之分的)在双屏时必须复制而不是镜像,
/// 否则右屏会翻转成反的。
class PatternDef {
  final String id;
  final String name;
  final PatternCat cat;
  final bool symmetric;

  /// 动画帧数。1 = 静态图
  final int frames;

  /// 帧间隔毫秒
  final int frameDelayMs;

  /// 文字类图案要用的竖排文字(用系统字体渲染,中文没问题)
  final String? text;

  /// 绘制第 [frame] 帧。文字类图案的文字已经画好,这里可以再叠加图形。
  final void Function(Painter p, int frame, int color)? draw;

  const PatternDef({
    required this.id,
    required this.name,
    required this.cat,
    this.symmetric = true,
    this.frames = 1,
    this.frameDelayMs = 120,
    this.text,
    this.draw,
  });

  bool get animated => frames > 1;
}

class Patterns {

  // ==========================================================
  // 高级 —— 慢速、渐变、留白,克制才显贵
  // ==========================================================
  static const premium = <PatternDef>[
    PatternDef(id: 'p_silk', name: '流光', cat: PatternCat.premium,
        frames: 40, frameDelayMs: 55, draw: pxSilk),
    PatternDef(id: 'p_breath', name: '呼吸', cat: PatternCat.premium,
        frames: 60, frameDelayMs: 60, draw: pxBreath),
    PatternDef(id: 'p_bubble', name: '气泡', cat: PatternCat.premium,
        frames: 60, frameDelayMs: 65, draw: pxBubbles),
    PatternDef(id: 'p_ripple', name: '涟漪', cat: PatternCat.premium,
        frames: 50, frameDelayMs: 60, draw: pxRipple),
    PatternDef(id: 'p_startrail', name: '星轨', cat: PatternCat.premium,
        frames: 80, frameDelayMs: 55, draw: pxStarTrail),
    PatternDef(id: 'p_ink', name: '水墨', cat: PatternCat.premium,
        frames: 60, frameDelayMs: 65, draw: pxInk),
  ];

  // ==========================================================
  // 温馨 —— 暖色、柔和,让后车的人心里一暖
  // ==========================================================
  static const warm = <PatternDef>[
    PatternDef(id: 'w_firefly', name: '萤火虫', cat: PatternCat.warm,
        frames: 70, frameDelayMs: 60, draw: wmFirefly),
    PatternDef(id: 'w_sunset', name: '暖阳', cat: PatternCat.warm,
        frames: 60, frameDelayMs: 70, draw: wmSunset),
    PatternDef(id: 'w_petals', name: '花瓣', cat: PatternCat.warm,
        frames: 80, frameDelayMs: 60, draw: wmPetals),
    PatternDef(id: 'w_candle', name: '烛光', cat: PatternCat.warm,
        frames: 40, frameDelayMs: 70, draw: wmCandle),
    PatternDef(id: 'w_balloon', name: '气球', cat: PatternCat.warm,
        frames: 90, frameDelayMs: 55, draw: wmBalloons),
    PatternDef(id: 'w_window', name: '雪夜窗', cat: PatternCat.warm,
        frames: 80, frameDelayMs: 65, draw: wmWinterWindow),
  ];

  // ==========================================================
  // 动物 —— 按 20x40 竖屏构图
  // ==========================================================
  static const animal = <PatternDef>[
    PatternDef(id: 'a_jelly', name: '水母', cat: PatternCat.animal,
        frames: 48, frameDelayMs: 60, draw: anJellyfish),
    PatternDef(id: 'a_butterfly', name: '蝴蝶', cat: PatternCat.animal,
        frames: 24, frameDelayMs: 70, draw: anButterfly),
    PatternDef(id: 'a_fish', name: '小鱼', cat: PatternCat.animal,
        frames: 60, frameDelayMs: 60, draw: anFish),
    PatternDef(id: 'a_cat', name: '猫咪', cat: PatternCat.animal,
        frames: 60, frameDelayMs: 70, draw: anCat),
    PatternDef(id: 'a_whale', name: '鲸鱼', cat: PatternCat.animal,
        frames: 70, frameDelayMs: 65, draw: anWhale),
    PatternDef(id: 'a_bird', name: '小鸟', cat: PatternCat.animal,
        frames: 20, frameDelayMs: 70, draw: anBird),
  ];

  // ==========================================================
  // A. 行车沟通 —— 竖排文字为主,20 列宽刚好放下两个字
  // ==========================================================
  static const drive = <PatternDef>[
    PatternDef(
      id: 'd_thanks',
      name: '谢谢',
      cat: PatternCat.drive,
      symmetric: false,
      text: '谢谢',
    ),
    PatternDef(
      id: 'd_sorry',
      name: '抱歉',
      cat: PatternCat.drive,
      symmetric: false,
      text: '抱歉',
    ),
    PatternDef(
      id: 'd_lowbeam',
      name: '请关远光',
      cat: PatternCat.drive,
      symmetric: false,
      text: '远光',
      draw: _drawDazzle,
    ),
    PatternDef(
      id: 'd_tooclose',
      name: '跟车太近',
      cat: PatternCat.drive,
      symmetric: true,
      frames: 4,
      frameDelayMs: 220,
      draw: _drawTooClose,
    ),
    PatternDef(
      id: 'd_newbie',
      name: '新手上路',
      cat: PatternCat.drive,
      symmetric: false,
      text: '新手',
    ),
    PatternDef(
      id: 'd_yield',
      name: '你先请',
      cat: PatternCat.drive,
      symmetric: false,
      text: '你先',
    ),
    PatternDef(
      id: 'd_warning',
      name: '前方慢行',
      cat: PatternCat.drive,
      symmetric: true,
      frames: 2,
      frameDelayMs: 400,
      draw: _drawWarning,
    ),
    PatternDef(
      id: 'd_reverse',
      name: '我在倒车',
      cat: PatternCat.drive,
      symmetric: true,
      frames: 4,
      frameDelayMs: 200,
      draw: _drawReversing,
    ),
  ];

  // ==========================================================
  // B. 表情
  // ==========================================================
  static const face = <PatternDef>[
    PatternDef(id: 'f_smile', name: '笑脸', cat: PatternCat.face, draw: _fSmile),
    PatternDef(
      id: 'f_wink',
      name: '眨眼',
      cat: PatternCat.face,
      frames: 6,
      frameDelayMs: 160,
      draw: _fWink,
    ),
    PatternDef(id: 'f_love', name: '爱心眼', cat: PatternCat.face, draw: _fLove),
    PatternDef(id: 'f_cool', name: '墨镜', cat: PatternCat.face, draw: _fCool),
    PatternDef(id: 'f_sad', name: '难过', cat: PatternCat.face, draw: _fSad),
    PatternDef(id: 'f_angry', name: '生气', cat: PatternCat.face, draw: _fAngry),
    PatternDef(id: 'f_surprise', name: '惊讶', cat: PatternCat.face, draw: _fSurprise),
    PatternDef(id: 'f_sleep', name: '困了', cat: PatternCat.face, draw: _fSleep),
  ];

  // ==========================================================
  // C. 可爱角色
  // ==========================================================
  static const cute = <PatternDef>[
    PatternDef(id: 'c_paw', name: '猫爪', cat: PatternCat.cute, draw: _cPaw),
    PatternDef(id: 'c_cat', name: '小猫', cat: PatternCat.cute, draw: _cCat),
    PatternDef(id: 'c_dog', name: '柴犬', cat: PatternCat.cute, draw: _cDog),
    PatternDef(id: 'c_ghost', name: '幽灵', cat: PatternCat.cute, draw: _cGhost),
    PatternDef(
      id: 'c_heartbeat',
      name: '心跳',
      cat: PatternCat.cute,
      frames: 12,
      frameDelayMs: 70,
      draw: _cHeartbeat,
    ),
    PatternDef(id: 'c_star', name: '星星', cat: PatternCat.cute, draw: _cStar),
    PatternDef(id: 'c_moon', name: '月亮', cat: PatternCat.cute, draw: _cMoon),
    PatternDef(id: 'c_penguin', name: '企鹅', cat: PatternCat.cute, draw: _cPenguin),
  ];

  // ==========================================================
  // D. 车主题
  // ==========================================================
  static const car = <PatternDef>[
    PatternDef(id: 'v_bolt', name: '闪电', cat: PatternCat.car, draw: _vBolt),
    PatternDef(
      id: 'v_charging',
      name: '充电中',
      cat: PatternCat.car,
      frames: 10,
      frameDelayMs: 160,
      draw: _vCharging,
    ),
    PatternDef(id: 'v_battery', name: '电量', cat: PatternCat.car, draw: _vBattery),
    PatternDef(id: 'v_flag', name: '格子旗', cat: PatternCat.car, draw: _vFlag),
    PatternDef(id: 'v_wheel', name: '方向盘', cat: PatternCat.car, draw: _vWheel),
    PatternDef(id: 'v_speed', name: '速度线', cat: PatternCat.car, frames: 8,
        frameDelayMs: 80, draw: _vSpeed),
  ];

  // ==========================================================
  // E. 节日
  // ==========================================================
  static const festival = <PatternDef>[
    PatternDef(id: 'h_tree', name: '圣诞树', cat: PatternCat.festival, draw: _hTree),
    PatternDef(
      id: 'h_snow',
      name: '雪花',
      cat: PatternCat.festival,
      frames: 16,
      frameDelayMs: 110,
      draw: _hSnow,
    ),
    PatternDef(id: 'h_pumpkin', name: '南瓜', cat: PatternCat.festival, draw: _hPumpkin),
    PatternDef(
      id: 'h_firework',
      name: '烟花',
      cat: PatternCat.festival,
      frames: 14,
      frameDelayMs: 90,
      draw: _hFirework,
    ),
    PatternDef(id: 'h_lantern', name: '灯笼', cat: PatternCat.festival, draw: _hLantern),
    PatternDef(
      id: 'h_heart',
      name: '爱心',
      cat: PatternCat.festival,
      frames: 10,
      frameDelayMs: 90,
      draw: _hHeart,
    ),
  ];

  static List<PatternDef> get all => [
        ...premium,
        ...warm,
        ...animal,
        ...drive,
        ...face,
        ...cute,
        ...car,
        ...festival,
      ];

  static List<PatternDef> byCat(PatternCat c) =>
      all.where((p) => p.cat == c).toList();

  /// 渲染一帧。文字类会先把竖排文字画上,再叠加图形。
  static Future<Frame> render(
    PatternDef def,
    DeviceConfig cfg,
    int frame,
    int color,
  ) async {
    final f = Frame(cfg.width, cfg.height);
    final p = Painter(f);
    p.clear();

    if (def.text != null) {
      await _drawVerticalText(f, def.text!, color);
    }
    def.draw?.call(p, frame, color);
    return f;
  }

  /// 竖排文字:20 列宽的屏,横排两个汉字每个只有 10 像素太小了,
  /// 竖着排每个字能占满整个宽度,清晰得多。
  static Future<void> _drawVerticalText(Frame f, String text, int color) async {
    final chars = text.characters();
    if (chars.isEmpty) return;
    final cellH = f.height ~/ chars.length;

    for (var i = 0; i < chars.length; i++) {
      final bmp = await TextRender.renderText(
        chars[i],
        cellH,
        fontScale: 0.95,
      );
      if (bmp == null) continue;
      final startX = ((f.width - bmp.width) / 2).round();
      final startY = i * cellH;
      for (var y = 0; y < cellH && y < bmp.height; y++) {
        for (var x = 0; x < bmp.width; x++) {
          if (bmp.lumAt(x, y) > 100) f.set(startX + x, startY + y, color);
        }
      }
    }
  }
}

extension _Chars on String {
  List<String> characters() => runes.map(String.fromCharCode).toList();
}

// ============================================================
// A. 行车沟通
// ============================================================

/// "远光"两字下面画一个刺眼的光晕 + 禁止斜杠
void _drawDazzle(Painter p, int frame, int color) {
  final y = 0.86;
  p.circle(0.5, y, 0.10, color);
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    p.line(0.5 + math.cos(a) * 0.10, y + math.sin(a) * 0.06,
        0.5 + math.cos(a) * 0.22, y + math.sin(a) * 0.12, color);
  }
}

/// 跟车太近:向下的箭头逐个点亮,像在说"退后"
void _drawTooClose(Painter p, int frame, int color) {
  for (var i = 0; i < 3; i++) {
    final lit = ((frame + i) % 4) < 3;
    if (!lit) continue;
    p.arrow(0.5, 0.25 + i * 0.25, 0.11, 1, color);
  }
}

/// 前方慢行:三角警示牌闪烁
void _drawWarning(Painter p, int frame, int color) {
  if (frame % 2 == 1) return; // 闪
  p.warningTriangle(0.5, 0.5, 0.30, color);
}

/// 倒车:两侧向中间收拢的横条
void _drawReversing(Painter p, int frame, int color) {
  final white = rgb(255, 255, 255);
  for (var i = 0; i < 4; i++) {
    final lit = ((frame + i) % 4) == 0;
    if (!lit) continue;
    p.rect(0.1, 0.12 + i * 0.22, 0.8, 0.07, white);
  }
}

// ============================================================
// B. 表情 —— 统一用"上半脸眼睛、下半脸嘴"的布局
// ============================================================

void _eyes(Painter p, int color, {double r = 0.075, double y = 0.36}) {
  p.circle(0.28, y, r, color);
  p.circle(0.72, y, r, color);
}

/// 弧线嘴:[curve] 正数上扬(笑),负数下弯(哭)
void _mouth(Painter p, int color, double curve, {double y = 0.66}) {
  const n = 22;
  for (var i = 0; i <= n; i++) {
    final t = i / n;
    final x = 0.25 + t * 0.5;
    final yy = y - math.sin(t * math.pi) * curve;
    p.dot(x, yy, color);
    p.dot(x, yy + 0.022, color);
  }
}

void _fSmile(Painter p, int f, int c) {
  _eyes(p, c);
  _mouth(p, c, 0.10);
}

void _fWink(Painter p, int f, int c) {
  // 前几帧睁眼,后几帧右眼闭成一条线
  final closed = f >= 3;
  p.circle(0.28, 0.36, 0.075, c);
  if (closed) {
    p.rect(0.62, 0.35, 0.2, 0.035, c);
  } else {
    p.circle(0.72, 0.36, 0.075, c);
  }
  _mouth(p, c, 0.10);
}

void _fLove(Painter p, int f, int c) {
  final pink = rgb(255, 60, 120);
  p.heart(0.28, 0.36, 0.16, pink);
  p.heart(0.72, 0.36, 0.16, pink);
  _mouth(p, c, 0.10);
}

void _fCool(Painter p, int f, int c) {
  // 墨镜:两块镜片 + 鼻梁
  p.rect(0.10, 0.30, 0.32, 0.14, c);
  p.rect(0.58, 0.30, 0.32, 0.14, c);
  p.rect(0.42, 0.35, 0.16, 0.035, c);
  _mouth(p, c, 0.07);
}

void _fSad(Painter p, int f, int c) {
  _eyes(p, c);
  _mouth(p, c, -0.10, y: 0.74);
}

void _fAngry(Painter p, int f, int c) {
  _eyes(p, c, r: 0.065);
  // 压低的眉毛
  p.line(0.16, 0.22, 0.40, 0.29, c, thick: 2);
  p.line(0.84, 0.22, 0.60, 0.29, c, thick: 2);
  _mouth(p, c, -0.08, y: 0.74);
}

void _fSurprise(Painter p, int f, int c) {
  _eyes(p, c, r: 0.085);
  p.circle(0.5, 0.70, 0.10, c, fill: false);
  p.circle(0.5, 0.70, 0.07, c);
}

void _fSleep(Painter p, int f, int c) {
  // 闭着的眼睛 + Z
  p.rect(0.16, 0.35, 0.24, 0.035, c);
  p.rect(0.60, 0.35, 0.24, 0.035, c);
  _mouth(p, c, 0.05);
  p.line(0.72, 0.10, 0.90, 0.10, c);
  p.line(0.90, 0.10, 0.72, 0.20, c);
  p.line(0.72, 0.20, 0.90, 0.20, c);
}

// ============================================================
// C. 可爱角色
// ============================================================

void _cPaw(Painter p, int f, int c) {
  p.circle(0.5, 0.62, 0.22, c); // 掌垫
  p.circle(0.22, 0.34, 0.085, c);
  p.circle(0.42, 0.24, 0.085, c);
  p.circle(0.62, 0.24, 0.085, c);
  p.circle(0.80, 0.34, 0.085, c);
}

void _cCat(Painter p, int f, int c) {
  // 耳朵
  p.polygon([
    [0.18, 0.34],
    [0.28, 0.14],
    [0.40, 0.32]
  ], c);
  p.polygon([
    [0.82, 0.34],
    [0.72, 0.14],
    [0.60, 0.32]
  ], c);
  p.circle(0.5, 0.52, 0.30, c, fill: false);
  p.circle(0.36, 0.46, 0.045, c);
  p.circle(0.64, 0.46, 0.045, c);
  // 胡须
  p.line(0.06, 0.58, 0.30, 0.60, c);
  p.line(0.94, 0.58, 0.70, 0.60, c);
  p.dot(0.5, 0.58, c);
}

void _cDog(Painter p, int f, int c) {
  // 垂耳
  p.circle(0.18, 0.42, 0.12, c);
  p.circle(0.82, 0.42, 0.12, c);
  p.circle(0.5, 0.50, 0.28, c, fill: false);
  p.circle(0.38, 0.45, 0.045, c);
  p.circle(0.62, 0.45, 0.045, c);
  p.circle(0.5, 0.60, 0.05, c); // 鼻子
  _mouth(p, c, 0.05, y: 0.70);
}

void _cGhost(Painter p, int f, int c) {
  // 半圆脑袋 + 波浪下摆
  p.circle(0.5, 0.42, 0.30, c);
  p.rect(0.20, 0.42, 0.60, 0.34, c);
  for (var i = 0; i < 4; i++) {
    p.circle(0.26 + i * 0.16, 0.78, 0.075, c);
  }
  p.circle(0.38, 0.38, 0.05, 0xFF000000);
  p.circle(0.62, 0.38, 0.05, 0xFF000000);
}

void _cHeartbeat(Painter p, int f, int c) {
  // 心脏随帧缩放,模拟跳动
  final t = f / 12.0 * math.pi * 2;
  final beat = 0.20 + (math.sin(t) * 0.5 + 0.5) * 0.10;
  p.heart(0.5, 0.5, beat, c);
}

void _cStar(Painter p, int f, int c) => p.star(0.5, 0.5, 0.36, c);

void _cMoon(Painter p, int f, int c) {
  p.circle(0.5, 0.5, 0.34, c);
  p.circle(0.70, 0.42, 0.30, 0xFF000000); // 挖出月牙
  p.star(0.18, 0.20, 0.09, c);
  p.star(0.28, 0.80, 0.06, c);
}

void _cPenguin(Painter p, int f, int c) {
  final white = rgb(255, 255, 255);
  final orange = rgb(255, 150, 0);
  p.circle(0.5, 0.34, 0.22, c);      // 头
  p.rect(0.24, 0.44, 0.52, 0.40, c); // 身体
  p.circle(0.5, 0.62, 0.20, white);  // 肚皮
  p.circle(0.40, 0.30, 0.04, white);
  p.circle(0.60, 0.30, 0.04, white);
  p.polygon([
    [0.44, 0.38],
    [0.56, 0.38],
    [0.50, 0.45]
  ], orange);
}

// ============================================================
// D. 车主题
// ============================================================

void _vBolt(Painter p, int f, int c) {
  p.polygon([
    [0.58, 0.08],
    [0.26, 0.54],
    [0.46, 0.54],
    [0.38, 0.92],
    [0.74, 0.44],
    [0.52, 0.44],
  ], c);
}

void _vCharging(Painter p, int f, int c) {
  final green = rgb(40, 230, 90);
  // 电池外框
  p.rect(0.22, 0.16, 0.56, 0.70, c, fill: false);
  p.rect(0.42, 0.10, 0.16, 0.05, c);
  // 从下往上充
  final lvl = (f % 10) / 9.0;
  final fillH = 0.62 * lvl;
  if (fillH > 0.02) p.rect(0.27, 0.80 - fillH, 0.46, fillH, green);
}

void _vBattery(Painter p, int f, int c) {
  p.rect(0.22, 0.16, 0.56, 0.70, c, fill: false);
  p.rect(0.42, 0.10, 0.16, 0.05, c);
  // 三格电量
  for (var i = 0; i < 3; i++) {
    p.rect(0.29, 0.70 - i * 0.20, 0.42, 0.14, c);
  }
}

void _vFlag(Painter p, int f, int c) {
  final white = rgb(255, 255, 255);
  const cols = 6, rows = 8;
  for (var gy = 0; gy < rows; gy++) {
    for (var gx = 0; gx < cols; gx++) {
      if ((gx + gy) % 2 == 0) {
        p.rect(0.12 + gx * (0.76 / cols), 0.16 + gy * (0.68 / rows),
            0.76 / cols * 0.95, 0.68 / rows * 0.95, white);
      }
    }
  }
}

void _vWheel(Painter p, int f, int c) {
  p.circle(0.5, 0.5, 0.36, c, fill: false);
  p.circle(0.5, 0.5, 0.10, c);
  p.line(0.5, 0.5, 0.5, 0.86, c, thick: 2);
  p.line(0.5, 0.5, 0.18, 0.34, c, thick: 2);
  p.line(0.5, 0.5, 0.82, 0.34, c, thick: 2);
}

void _vSpeed(Painter p, int f, int c) {
  // 向下流动的速度线,像车在飞驰
  for (var i = 0; i < 5; i++) {
    final y = ((f * 0.12) + i * 0.2) % 1.2 - 0.1;
    final len = 0.10 + (i % 3) * 0.05;
    p.rect(0.16 + (i % 3) * 0.26, y, 0.10, len, c);
  }
}

// ============================================================
// E. 节日
// ============================================================

void _hTree(Painter p, int f, int c) {
  final green = rgb(30, 200, 70);
  final brown = rgb(140, 80, 30);
  p.polygon([
    [0.5, 0.08],
    [0.76, 0.38],
    [0.24, 0.38]
  ], green);
  p.polygon([
    [0.5, 0.26],
    [0.84, 0.62],
    [0.16, 0.62]
  ], green);
  p.polygon([
    [0.5, 0.46],
    [0.92, 0.84],
    [0.08, 0.84]
  ], green);
  p.rect(0.44, 0.84, 0.12, 0.14, brown);
  p.star(0.5, 0.06, 0.08, rgb(255, 220, 0));
}

void _hSnow(Painter p, int f, int c) {
  final white = rgb(220, 240, 255);
  // 确定性的下落雪点
  for (var i = 0; i < 14; i++) {
    final rnd = math.Random(i * 977);
    final x = rnd.nextDouble();
    final speed = 0.5 + rnd.nextDouble() * 0.8;
    final y = ((f * 0.055 * speed) + rnd.nextDouble()) % 1.0;
    p.dot(x, y, white);
  }
}

void _hPumpkin(Painter p, int f, int c) {
  final orange = rgb(255, 130, 0);
  p.circle(0.5, 0.56, 0.34, orange);
  p.rect(0.46, 0.14, 0.08, 0.12, rgb(60, 160, 40));
  // 三角眼 + 锯齿嘴
  p.polygon([
    [0.30, 0.44],
    [0.42, 0.44],
    [0.36, 0.56]
  ], 0xFF000000);
  p.polygon([
    [0.70, 0.44],
    [0.58, 0.44],
    [0.64, 0.56]
  ], 0xFF000000);
  p.polygon([
    [0.30, 0.66],
    [0.70, 0.66],
    [0.62, 0.76],
    [0.56, 0.68],
    [0.50, 0.76],
    [0.44, 0.68],
    [0.38, 0.76]
  ], 0xFF000000);
}

void _hFirework(Painter p, int f, int c) {
  // 前段上升,后段炸开
  if (f < 5) {
    final y = 0.95 - f * 0.11;
    p.dot(0.5, y, c);
    p.dot(0.5, y + 0.03, scaleColor(c, 0.5));
    return;
  }
  final t = (f - 5) / 9.0;
  final r = t * 0.42;
  for (var i = 0; i < 14; i++) {
    final a = i * math.pi * 2 / 14;
    final col = hsv((i * 18) & 0xFF);
    p.dot(0.5 + math.cos(a) * r, 0.42 + math.sin(a) * r,
        scaleColor(col, 1.0 - t * 0.8));
  }
}

void _hLantern(Painter p, int f, int c) {
  final red = rgb(230, 20, 20);
  final gold = rgb(255, 200, 40);
  p.rect(0.46, 0.06, 0.08, 0.10, gold);
  p.circle(0.5, 0.46, 0.32, red);
  p.rect(0.30, 0.16, 0.40, 0.06, gold);
  p.rect(0.30, 0.70, 0.40, 0.06, gold);
  // 流苏
  p.rect(0.47, 0.76, 0.06, 0.16, gold);
}

void _hHeart(Painter p, int f, int c) {
  final t = f / 10.0 * math.pi * 2;
  final s = 0.26 + (math.sin(t) * 0.5 + 0.5) * 0.08;
  p.heart(0.5, 0.5, s, rgb(255, 40, 90));
}
