import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/colors.dart';

/// スキャン対象のドキュメントタイプ
enum DocumentType {
  vehicleCertificate('車検証', '車検証を枠内に収めてください'),
  invoice('請求書', '請求書を枠内に収めてください'),
  maintenanceRecord('整備記録簿', '整備記録簿を枠内に収めてください');

  final String displayName;
  final String instruction;

  const DocumentType(this.displayName, this.instruction);
}

/// ドキュメントスキャン画面
class DocumentScannerScreen extends StatefulWidget {
  final DocumentType documentType;

  const DocumentScannerScreen({
    super.key,
    required this.documentType,
  });

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _hasError = false;
  String? _errorMessage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = 'カメラが利用できません';
        });
        return;
      }

      // 背面カメラを選択
      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'カメラの初期化に失敗しました: $e';
      });
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final xFile = await _controller!.takePicture();
      final file = File(xFile.path);

      if (mounted) {
        Navigator.of(context).pop(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('撮影に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final xFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );

      if (xFile != null && mounted) {
        Navigator.of(context).pop(File(xFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の選択に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.documentType.displayName}をスキャン'),
        elevation: 0,
      ),
      body: _hasError
          ? _buildErrorView()
          : !_isInitialized
              ? _buildLoadingView()
              : _buildCameraView(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'カメラを起動中...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'カメラを利用できません',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library),
              label: const Text('ギャラリーから選択'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        // カメラプレビュー
        Positioned.fill(
          child: CameraPreview(_controller!),
        ),

        // ガイド枠オーバーレイ
        Positioned.fill(
          child: _buildGuideOverlay(),
        ),

        // 説明テキスト
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.documentType.instruction,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),

        // コントロールボタン
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildControlBar(),
        ),
      ],
    );
  }

  Widget _buildGuideOverlay() {
    return CustomPaint(
      painter: _GuideFramePainter(
        documentType: widget.documentType,
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // ギャラリーボタン
            IconButton(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library, size: 32),
              color: Colors.white,
              tooltip: 'ギャラリーから選択',
            ),

            // 撮影ボタン
            GestureDetector(
              onTap: _isCapturing ? null : _captureImage,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCapturing ? Colors.grey : Colors.white,
                  ),
                  child: _isCapturing
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black54,
                          ),
                        )
                      : null,
                ),
              ),
            ),

            // フラッシュボタン（プレースホルダー）
            IconButton(
              onPressed: () {
                // TODO: フラッシュ切り替え
              },
              icon: const Icon(Icons.flash_auto, size: 32),
              color: Colors.white,
              tooltip: 'フラッシュ',
            ),
          ],
        ),
      ),
    );
  }
}

/// ガイド枠を描画するカスタムペインター
class _GuideFramePainter extends CustomPainter {
  final DocumentType documentType;

  _GuideFramePainter({required this.documentType});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    // 枠のサイズを計算（画面の80%幅、A4比率に近い）
    final frameWidth = size.width * 0.85;
    final frameHeight = documentType == DocumentType.vehicleCertificate
        ? frameWidth * 0.65  // 車検証は横長
        : frameWidth * 1.4;  // A4縦向き

    final frameLeft = (size.width - frameWidth) / 2;
    final frameTop = (size.height - frameHeight) / 2 - 40;  // 少し上寄せ

    final frameRect = Rect.fromLTWH(frameLeft, frameTop, frameWidth, frameHeight);

    // 暗いオーバーレイ（枠の外側）
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // 枠線
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(12)),
      borderPaint,
    );

    // 角のマーカー
    _drawCornerMarkers(canvas, frameRect);
  }

  void _drawCornerMarkers(Canvas canvas, Rect rect) {
    final markerPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const markerLength = 30.0;
    const radius = 12.0;

    // 左上
    canvas.drawLine(
      Offset(rect.left, rect.top + radius + markerLength),
      Offset(rect.left, rect.top + radius),
      markerPaint,
    );
    canvas.drawLine(
      Offset(rect.left + radius, rect.top),
      Offset(rect.left + radius + markerLength, rect.top),
      markerPaint,
    );

    // 右上
    canvas.drawLine(
      Offset(rect.right, rect.top + radius + markerLength),
      Offset(rect.right, rect.top + radius),
      markerPaint,
    );
    canvas.drawLine(
      Offset(rect.right - radius, rect.top),
      Offset(rect.right - radius - markerLength, rect.top),
      markerPaint,
    );

    // 左下
    canvas.drawLine(
      Offset(rect.left, rect.bottom - radius - markerLength),
      Offset(rect.left, rect.bottom - radius),
      markerPaint,
    );
    canvas.drawLine(
      Offset(rect.left + radius, rect.bottom),
      Offset(rect.left + radius + markerLength, rect.bottom),
      markerPaint,
    );

    // 右下
    canvas.drawLine(
      Offset(rect.right, rect.bottom - radius - markerLength),
      Offset(rect.right, rect.bottom - radius),
      markerPaint,
    );
    canvas.drawLine(
      Offset(rect.right - radius, rect.bottom),
      Offset(rect.right - radius - markerLength, rect.bottom),
      markerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
