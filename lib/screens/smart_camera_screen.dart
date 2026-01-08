import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../widgets/camera_overlay_guide.dart';

class SmartCameraScreen extends StatefulWidget {
  const SmartCameraScreen({super.key});

  @override
  State<SmartCameraScreen> createState() => _SmartCameraScreenState();
}

class _SmartCameraScreenState extends State<SmartCameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  String? _error;
  Offset? _focusRingPosition;
  bool _showFocusRing = false;
  late final AnimationController _focusRingController;
  late final Animation<double> _focusRingScale;
  late final Animation<double> _focusRingOpacity;
  static const double _focusRingSize = 72;
  static const Color _focusRingColor = Color(0xFFFFD60A);

  @override
  void initState() {
    super.initState();
    _focusRingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    _focusRingScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.03)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.03, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
    ]).animate(_focusRingController);
    _focusRingOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(
        tween:
            Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_focusRingController);
    _focusRingController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showFocusRing = false);
      }
    });
    _initializeCamera();
  }

  @override
  void dispose() {
    _focusRingController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = '利用可能なカメラがありません');
        return;
      }
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller?.dispose();
        _controller = controller;
        _isCameraReady = true;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'カメラの初期化に失敗しました。設定を確認してください。');
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing)
      return;
    try {
      setState(() => _isCapturing = true);
      final file = await controller.takePicture();
      final savedPath = await _saveCapture(file);
      if (!mounted) return;
      Navigator.of(context).pop(savedPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('撮影に失敗しました。もう一度お試しください。')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _setFocusPoint(Offset localPosition, Size previewSize) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final supportsFocus = controller.value.focusPointSupported;
    final supportsExposure = controller.value.exposurePointSupported;
    if (!supportsFocus && !supportsExposure) return;

    final dx = (localPosition.dx / previewSize.width).clamp(0.0, 1.0);
    final dy = (localPosition.dy / previewSize.height).clamp(0.0, 1.0);
    final point = Offset(dx, dy);

    try {
      if (mounted) {
        setState(() {
          _focusRingPosition = localPosition;
          _showFocusRing = true;
        });
        _focusRingController.forward(from: 0);
      }
      if (supportsExposure) {
        await controller.setExposurePoint(point);
      }
      if (supportsFocus) {
        await controller.setFocusPoint(point);
        await controller.setFocusMode(FocusMode.auto);
      }
    } catch (e) {
      debugPrint('[SmartCamera] focus failed: $e');
    }
  }

  Future<String> _saveCapture(XFile xfile) async {
    final directory = await getApplicationDocumentsDirectory();
    final filename =
        'capture_${DateTime.now().millisecondsSinceEpoch}${p.extension(xfile.path)}';
    final savedPath = p.join(directory.path, filename);
    final bytes = await xfile.readAsBytes();
    final file = File(savedPath);
    await file.writeAsBytes(bytes, flush: true);
    return savedPath;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('スマートカメラ'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : !_isCameraReady || controller == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) =>
                              _setFocusPoint(details.localPosition, size),
                          child: CameraPreview(controller),
                        );
                      },
                    ),
                    const CameraOverlayGuide(),
                    if (_showFocusRing && _focusRingPosition != null)
                      Positioned(
                        left: _focusRingPosition!.dx - _focusRingSize / 2,
                        top: _focusRingPosition!.dy - _focusRingSize / 2,
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _focusRingController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _focusRingOpacity.value,
                                child: Transform.scale(
                                  scale: _focusRingScale.value,
                                  child: child,
                                ),
                              );
                            },
                            child: SizedBox(
                              width: _focusRingSize,
                              height: _focusRingSize,
                              child: CustomPaint(
                                painter: _FocusRingPainter(
                                  color: _focusRingColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 32,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        top: false,
                        child: Center(
                          child: FloatingActionButton.large(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            onPressed: _isCapturing ? null : _capturePhoto,
                            child: _isCapturing
                                ? const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 3),
                                  )
                                : const Icon(Icons.camera_alt, size: 36),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const double strokeWidth = 2.0;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      const Radius.circular(10),
    );

    final glowPaint = Paint()
      ..color = color.withAlpha(90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, glowPaint);
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
