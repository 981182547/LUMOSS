// 基础冒烟测试:验证核心渲染逻辑可用(不依赖蓝牙硬件)。
import 'package:flutter_test/flutter_test.dart';

import 'package:bt_controller/models/effects.dart';
import 'package:bt_controller/models/led_matrix.dart';
import 'package:bt_controller/ble/protocol.dart';

void main() {
  test('特效渲染产出非空画面', () {
    final f = Frame(16, 16);
    Effects.render(f, 1, 500, 128, 160, 0xFFFF003C, 1);
    expect(f.pixels.length, 256);
    // 彩虹特效应该产生多种颜色
    expect(f.pixels.toSet().length, greaterThan(1));
  });

  test('协议封包格式正确', () {
    final pkt = Protocol.brightness(200);
    expect(pkt[0], 0xA5); // MAGIC
    expect(pkt[1], Protocol.opBright);
    expect(pkt[2], 0); // LEN_hi
    expect(pkt[3], 1); // LEN_lo
    expect(pkt[4], 200);
  });

  test('灯板坐标映射:蛇形走线', () {
    const c = DeviceConfig(width: 4, height: 4, serpentine: true, flipX: false);
    expect(c.indexOf(0, 0), 0); // 第0行正向
    expect(c.indexOf(0, 1), 7); // 第1行反向
  });
}
