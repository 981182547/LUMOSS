import 'dart:typed_data';

/// Web 端占位实现:浏览器没有原始 TCP socket,WiFi 通道在 web 上不可用。
/// 真机(Android/iOS)会用 socket_io.dart 里的真实实现。
class RawTcp {
  static Future<RawTcp> connect(String host, int port,
      {Duration? timeout}) async {
    throw UnsupportedError('Web 端不支持 TCP,请在手机上使用 WiFi 传输');
  }

  Future<void> send(Uint8List data) async {}
  Future<void> close() async {}
  void destroy() {}
  Future<void> get done => Future.value();
}
