import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/ble_manager.dart';
import '../ble/protocol.dart';
import '../theme.dart';

/// 设备选择弹层:扫描附近蓝牙设备,点一个连接。
/// 灯板(WeiDeng-LED)会排在最前面并高亮。
Future<void> showDevicePicker(BuildContext context, BleManager ble) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: cardSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _DevicePickerSheet(ble: ble),
  );
}

class _DevicePickerSheet extends StatefulWidget {
  final BleManager ble;
  const _DevicePickerSheet({required this.ble});

  @override
  State<_DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends State<_DevicePickerSheet> {
  BleManager get ble => widget.ble;
  bool _scanning = false;
  String _diag = '';

  @override
  void initState() {
    super.initState();
    ble.onScanUpdate = _refresh;
    // 直接开扫:扫描内部会先申请权限,扫完再刷新诊断,
    // 若先查诊断会显示申请前的旧状态,反而误导
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  /// 诊断信息:权限、蓝牙开关、扫到的数量 —— 出问题时一眼看出卡在哪
  Future<void> _updateDiag() async {
    final perm = await ble.hasPermissions();
    final adapter = await ble.isAdapterOn();
    if (!mounted) return;
    setState(() {
      _diag = '权限 ${perm ? "已授予" : "缺失"} · '
          '蓝牙 ${adapter ? "已开启" : "未开启"} · '
          '扫到 ${ble.scanResults.length} 个';
    });
  }

  @override
  void dispose() {
    ble.onScanUpdate = null;
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    await ble.startScan();
    if (mounted) setState(() => _scanning = false);
    await _updateDiag();
  }

  /// 灯板排最前,其余按信号强度排序
  List<ScanResult> get _sorted {
    final list = [...ble.scanResults];
    list.sort((a, b) {
      final an = a.device.platformName == Protocol.deviceName ? 1 : 0;
      final bn = b.device.platformName == Protocol.deviceName ? 1 : 0;
      if (an != bn) return bn - an;
      return b.rssi.compareTo(a.rssi);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = _sorted;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('选择灯板',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: textPrimary)),
                      const Text('点击设备开始连接',
                          style:
                              TextStyle(fontSize: 12, color: textSecondary)),
                      // 诊断行:权限 / 蓝牙 / 扫到数量
                      if (_diag.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_diag,
                              style: const TextStyle(
                                  fontSize: 11, color: onAccentContainer)),
                        ),
                    ],
                  ),
                ),
                if (_scanning)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accent),
                  )
                else
                  GestureDetector(
                    onTap: _scan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: accentContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('重新扫描',
                          style: TextStyle(
                              fontSize: 12, color: onAccentContainer)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: list.isEmpty
                  ? SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          _scanning ? '搜索中…' : '没有找到设备\n确认灯板已上电、手机蓝牙已打开',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: textSecondary, height: 1.6),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = list[i];
                        return _DeviceTile(
                          result: r,
                          onTap: () async {
                            Navigator.pop(context);
                            await ble.connectTo(r.device);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onTap;

  const _DeviceTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = result.device.platformName;
    final isTarget = name == Protocol.deviceName;
    final display = name.isEmpty ? '(未命名设备)' : name;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isTarget ? accentContainer : cardSurfaceAlt,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isTarget ? accent : glassBorder,
            width: isTarget ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: isTarget ? brandGradient : null,
                color: isTarget ? null : accentContainer,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.bluetooth_rounded,
                  size: 17,
                  color: isTarget ? Colors.white : onAccentContainer),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: isTarget
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: textPrimary)),
                      ),
                      if (isTarget) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: brandGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('灯板',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                  Text(result.device.remoteId.str,
                      style: const TextStyle(
                          fontSize: 10, color: textSecondary)),
                ],
              ),
            ),
            Text('${result.rssi} dBm',
                style: const TextStyle(fontSize: 11, color: textSecondary)),
          ],
        ),
      ),
    );
  }
}
