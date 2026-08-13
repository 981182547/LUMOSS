import 'dart:async';
import 'dart:typed_data';

import 'link.dart';
// 条件导入:真机用 dart:io 的 Socket,web 端用占位实现(浏览器无原始 TCP)
import 'socket_stub.dart' if (dart.library.io) 'socket_io.dart';

enum WifiConn { disconnected, connecting, connected }

/// WiFi(TCP)传输:连到 ESP32 的 TCP 端口,发和蓝牙完全相同的 0xA5 封包。
/// 平时用蓝牙,遇到大数据传输时切到这里走 WiFi。
class WifiManager implements LinkTransport {
  final void Function(WifiConn) onState;
  final void Function(String) onLog;

  WifiManager({required this.onState, this.onLog = _noop});
  static void _noop(String _) {}

  RawTcp? _socket;
  WifiConn _state = WifiConn.disconnected;
  WifiConn get state => _state;

  String host = '';
  int port = 8266;

  Future<void> _writeChain = Future.value();

  @override
  bool get isConnected => _state == WifiConn.connected;

  void _setState(WifiConn s) {
    _state = s;
    onState(s);
  }

  Future<bool> connect(String ip, int p) async {
    host = ip;
    port = p;
    _setState(WifiConn.connecting);
    onLog('正在连接 $ip:$p …');
    try {
      _socket = await RawTcp.connect(ip, p,
          timeout: const Duration(seconds: 6));
      _socket!.done.then((_) => _onClosed()).catchError((_) => _onClosed());
      _setState(WifiConn.connected);
      onLog('WiFi 已连接');
      return true;
    } catch (e) {
      onLog('WiFi 连接失败: $e');
      _setState(WifiConn.disconnected);
      return false;
    }
  }

  @override
  Future<void> sendPacket(Uint8List msg) {
    if (_state != WifiConn.connected || _socket == null) return Future.value();
    _writeChain = _writeChain.then((_) => _socket!.send(msg)).catchError((e) {
      onLog('WiFi 发送失败: $e');
    });
    return _writeChain;
  }

  void _onClosed() {
    if (_state != WifiConn.disconnected) {
      _setState(WifiConn.disconnected);
      onLog('WiFi 连接已断开');
    }
  }

  Future<void> disconnect() async {
    try {
      await _socket?.close();
    } catch (_) {}
    _socket?.destroy();
    _socket = null;
    _setState(WifiConn.disconnected);
  }
}
