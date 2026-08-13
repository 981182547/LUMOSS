import 'dart:typed_data';

/// 传输通道抽象:BLE 和 WiFi 都实现它,上层用同一套接口发 0xA5 封包。
abstract class LinkTransport {
  bool get isConnected;

  /// 发送一个完整封包(内部自行分片)
  Future<void> sendPacket(Uint8List msg);
}
