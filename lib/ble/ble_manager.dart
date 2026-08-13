import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'link.dart';
import 'protocol.dart';

enum Conn { disconnected, scanning, connecting, connected }

/// BLE 客户端:扫描 -> 连接 -> 协商 MTU -> 找到写特征 -> 分片顺序写入。
///
/// 每一步都有超时保护:某些手机上 requestMtu / discoverServices 会永久挂起,
/// 没有超时就会出现"灯板显示已连接、App 却一直转圈"的情况。
class BleManager implements LinkTransport {
  final void Function(Conn) onState;
  final void Function(String) onLog;

  /// 扫描列表有更新时回调,供界面显示设备选择列表(由设备选择弹层临时接管)
  void Function()? onScanUpdate;

  BleManager({
    required this.onState,
    this.onLog = _noop,
    this.onScanUpdate,
  });
  static void _noop(String _) {}

  /// 扫描到的设备(界面据此显示可选列表)
  final List<ScanResult> scanResults = [];

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx;
  int _mtu = 23;
  int get _chunkSize => (_mtu - 3).clamp(20, 512);

  Conn _state = Conn.disconnected;
  Conn get state => _state;

  BluetoothDevice? get connectedDevice =>
      _state == Conn.connected ? _device : null;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  // 顺序写入锁:把每次发送串起来,避免并发写特征
  Future<void> _writeChain = Future.value();

  @override
  bool get isConnected => _state == Conn.connected;

  void _setState(Conn s) {
    _state = s;
    onState(s);
  }

  void _log(String m) => onLog(m);

  // ---------------- 权限 ----------------
  Future<bool> hasPermissions() async {
    final scan = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;
    final loc = await Permission.location.status;
    return (scan.isGranted || scan.isLimited) &&
        (connect.isGranted || connect.isLimited) &&
        (loc.isGranted || loc.isLimited);
  }

  /// 手机蓝牙开关是否打开。
  ///
  /// 不能只看 adapterStateNow:那是缓存值,App 刚启动、状态流还没推过值时是
  /// unknown,会误判成"未开启"。这里退回到状态流取一次真实值。
  Future<bool> isAdapterOn() async {
    try {
      if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
        return true;
      }
      final st = await FlutterBluePlus.adapterState
          .firstWhere((s) => s != BluetoothAdapterState.unknown)
          .timeout(const Duration(seconds: 3));
      return st == BluetoothAdapterState.on;
    } catch (_) {
      // 读不到就别拦着,让后续扫描去试,真不行会报扫描失败
      return true;
    }
  }

  Future<bool> requestPermissions() async {
    // 安卓 BLE 扫描依赖定位权限,必须一并申请,否则扫不到任何设备
    final res = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();
    return res.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<bool> _ensureReady() async {
    if (await FlutterBluePlus.isSupported == false) {
      _log('这台设备不支持蓝牙');
      return false;
    }

    // 顺序很重要:必须【先】拿权限。
    // Android 12+ 没有 BLUETOOTH_CONNECT 权限时,连适配器状态都读不到,
    // 先查状态会得到 unknown,误判成"蓝牙未开启"而直接放弃。
    if (!await hasPermissions()) {
      if (!await requestPermissions()) {
        _log('需要蓝牙和位置权限才能搜索灯板');
        return false;
      }
    }

    if (!await isAdapterOn()) {
      _log('蓝牙未开启,请下拉通知栏打开蓝牙');
      return false;
    }
    return true;
  }

  // ---------------- 扫描 ----------------

  /// 扫描附近的灯板。结果放进 [scanResults],由界面显示供用户选择。
  ///
  /// 先按服务 UUID 过滤;若一个都没扫到,再退回"扫描全部 + 按名字匹配"——
  /// 因为广播包只有 31 字节,设备名加 128 位 UUID 可能放不下导致 UUID 被裁掉。
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_state == Conn.connected || _state == Conn.connecting) return;
    if (!await _ensureReady()) {
      _setState(Conn.disconnected);
      return;
    }

    scanResults.clear();
    onScanUpdate?.call();
    _setState(Conn.scanning);
    _log('正在搜索灯板…');

    await _scanSub?.cancel();
    // 用 scanResults(保留结果)而不是 onScanResults:
    // 后者在扫描停止的瞬间会推一个空列表,会把刚扫到的设备全清掉。
    // 这里按设备 ID 累积合并,永不因为空列表而清空。
    _scanSub = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final r in results) {
          final i = scanResults.indexWhere(
            (e) => e.device.remoteId == r.device.remoteId,
          );
          if (i >= 0) {
            scanResults[i] = r;
          } else {
            scanResults.add(r);
          }
        }
        if (results.isNotEmpty) onScanUpdate?.call();
      },
      onError: (e) => _log('扫描出错: $e'),
    );

    try {
      // 不按服务 UUID 过滤,直接扫全部:
      // 广播包只有 31 字节,设备名 + 128 位服务 UUID 常常放不下而被裁掉,
      // 一过滤就什么都扫不到。列表会把灯板(WeiDeng-LED)排在最前面。
      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (e) {
      _log('扫描失败: $e');
    }

    if (_state == Conn.scanning) {
      if (scanResults.isEmpty) {
        _log('没有找到设备,请确认灯板已上电');
      } else {
        _log('找到 ${scanResults.length} 个设备,点击选择');
      }
      _setState(Conn.disconnected);
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    if (_state == Conn.scanning) _setState(Conn.disconnected);
  }

  /// 扫描并自动连接第一个匹配的灯板(名字匹配优先)
  Future<void> connect() async {
    await startScan();
    if (scanResults.isEmpty) return;

    // 优先选名字匹配的,其次第一个
    final named = scanResults.where(
      (r) => r.device.platformName == Protocol.deviceName,
    );
    final target =
        named.isNotEmpty ? named.first.device : scanResults.first.device;
    await connectTo(target);
  }

  // ---------------- 连接 ----------------
  Future<void> connectTo(BluetoothDevice device) async {
    await stopScan();
    if (_state == Conn.connected || _state == Conn.connecting) return;

    _setState(Conn.connecting);
    _device = device;
    final name = device.platformName.isEmpty ? '设备' : device.platformName;
    _log('正在连接 $name…');

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      _log('已连接,协商 MTU…');

      // MTU 协商:部分手机会挂起,超时就用默认值继续,不能卡死
      try {
        _mtu = await device
            .requestMtu(247)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        _mtu = 23;
        _log('MTU 协商跳过($e),用默认 23');
      }
      _log('MTU = $_mtu,发现服务…');

      // 发现服务同样加超时
      final services = await device
          .discoverServices()
          .timeout(const Duration(seconds: 15));

      BluetoothCharacteristic? rx;
      for (final svc in services) {
        for (final c in svc.characteristics) {
          if (c.uuid == Guid(Protocol.rxUuid)) rx = c;
        }
      }
      // 没找到指定 UUID 时,退而求其次找任意可写特征
      if (rx == null) {
        for (final svc in services) {
          for (final c in svc.characteristics) {
            if (c.properties.write || c.properties.writeWithoutResponse) {
              rx = c;
              break;
            }
          }
          if (rx != null) break;
        }
        if (rx != null) _log('未找到标准写特征,改用 ${rx.uuid}');
      }

      if (rx == null) {
        _log('未找到可写特征,断开');
        await disconnect();
        return;
      }

      _rx = rx;

      // 连上之后才监听断开事件:提前监听会立刻收到一个 disconnected 初始值
      await _connSub?.cancel();
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected &&
            _state == Conn.connected) {
          _log('灯板已断开');
          _cleanup();
          _setState(Conn.disconnected);
        }
      });

      _setState(Conn.connected);
      _log('就绪');
    } on TimeoutException {
      _log('连接超时,请重试');
      await disconnect();
    } catch (e) {
      _log('连接失败: $e');
      await disconnect();
    }
  }

  // ---------------- 发送 ----------------
  @override
  Future<void> sendPacket(Uint8List msg) {
    if (_state != Conn.connected) return Future.value();
    _writeChain = _writeChain.then((_) => _writeChunks(msg)).catchError((e) {
      _log('发送失败: $e');
    });
    return _writeChain;
  }

  Future<void> _writeChunks(Uint8List msg) async {
    final c = _rx;
    if (c == null) return;
    final noResp = !c.properties.write && c.properties.writeWithoutResponse;
    var i = 0;
    while (i < msg.length) {
      final end = (i + _chunkSize < msg.length) ? i + _chunkSize : msg.length;
      await c.write(msg.sublist(i, end), withoutResponse: noResp);
      i = end;
    }
  }

  // ---------------- 断开 ----------------
  Future<void> disconnect() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      await _device?.disconnect();
    } catch (_) {}
    _cleanup();
    _setState(Conn.disconnected);
  }

  void _cleanup() {
    _scanSub?.cancel();
    _scanSub = null;
    _connSub?.cancel();
    _connSub = null;
    _rx = null;
    _mtu = 23;
  }
}
