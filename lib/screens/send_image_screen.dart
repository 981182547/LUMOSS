import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../models/image_convert.dart';
import '../models/led_matrix.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/led_panel.dart';

class SendImageScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onBack;

  const SendImageScreen({super.key, required this.state, required this.onBack});

  @override
  State<SendImageScreen> createState() => _SendImageScreenState();
}

class _SendImageScreenState extends State<SendImageScreen> {
  AppState get state => widget.state;

  Uint8List? _rawBytes; // 用于界面缩略图
  img.Image? _decoded;
  int saturation = 115;
  int contrast = 100;
  String status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.mode = const ModePicture();
      _refreshFrame();
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final decoded = decodeImageBytes(bytes);
    if (!mounted) return;
    setState(() {
      _rawBytes = bytes;
      _decoded = decoded;
      status = decoded == null ? '无法解析这张图片' : '';
    });
    _refreshFrame();
  }

  /// 帧按当前参数生成
  Frame _buildFrame() {
    final src = _decoded;
    if (src == null) return Frame(state.config.width, state.config.height);
    return imageToFrame(
      src,
      state.config,
      brightness: contrast / 100.0,
      saturation: saturation / 100.0,
    );
  }

  void _refreshFrame() {
    state.currentFrame = _buildFrame();
    state.touch();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bytes = state.config.count * 3;

    return Container(
      color: appBackground,
      child: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                TopBar(title: '发送图片', onBack: widget.onBack),

                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 110,
                    decoration: BoxDecoration(
                      color: accentContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _rawBytes != null
                        ? Image.memory(_rawBytes!, fit: BoxFit.cover)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded,
                                  size: 20, color: textSecondary),
                              SizedBox(width: 6),
                              Text('选择图片',
                                  style: TextStyle(
                                      fontSize: 14, color: textSecondary)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text('灯板效果预览',
                    style: TextStyle(fontSize: 13, color: textSecondary)),
                const SizedBox(height: 8),
                Glass(
                  radius: 20,
                  padding: const EdgeInsets.all(10),
                  child: LedPanelPreview(frame: state.currentFrame),
                ),

                const SizedBox(height: 14),
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      LabeledSlider(
                        label: '饱和度',
                        value: saturation,
                        min: 0,
                        max: 200,
                        onChange: (v) => setState(() => saturation = v),
                        onDone: _refreshFrame,
                      ),
                      LabeledSlider(
                        label: '明度',
                        value: contrast,
                        min: 20,
                        max: 150,
                        onChange: (v) => setState(() => contrast = v),
                        onDone: _refreshFrame,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                PrimaryButton(
                  text: state.conn == ConnState.connected
                      ? '发送到灯板'
                      : '未连接 · 仅预览',
                  enabled: _decoded != null &&
                      state.conn == ConnState.connected,
                  onTap: () async {
                    final f = _buildFrame();
                    // 数据量大时,pushFrame 内部会询问是否改用 WiFi
                    await state.pushFrame(f);
                    if (!mounted) return;
                    setState(() => status = '已发送 $bytes 字节到灯板');
                  },
                ),

                if (status.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(status,
                      style:
                          const TextStyle(fontSize: 12, color: textSecondary)),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
