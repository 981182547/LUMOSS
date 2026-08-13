import 'dart:io';
import 'dart:typed_data';

/// 真机端 TCP 实现(Android/iOS/桌面)。
class RawTcp {
  final Socket _socket;
  RawTcp._(this._socket);

  static Future<RawTcp> connect(String host, int port,
      {Duration? timeout}) async {
    final s = await Socket.connect(host, port, timeout: timeout);
    return RawTcp._(s);
  }

  Future<void> send(Uint8List data) async {
    _socket.add(data);
    await _socket.flush();
  }

  Future<void> close() => _socket.close();

  void destroy() => _socket.destroy();

  Future<void> get done => _socket.done;
}
