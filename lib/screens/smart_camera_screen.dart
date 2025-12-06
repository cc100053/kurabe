import 'dart:io';

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

class _SmartCameraScreenState extends State<SmartCameraScreen> {
  CameraController? _controller;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
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
      setState(() => _error = 'カメラの初期化に失敗しました: $e');
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) return;
    try {
      setState(() => _isCapturing = true);
      final file = await controller.takePicture();
      final savedPath = await _saveCapture(file);
      if (!mounted) return;
      Navigator.of(context).pop(savedPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('撮影に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<String> _saveCapture(XFile xfile) async {
    final directory = await getApplicationDocumentsDirectory();
    final filename = 'capture_${DateTime.now().millisecondsSinceEpoch}${p.extension(xfile.path)}';
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
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller),
                    const CameraOverlayGuide(),
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
                                    child: CircularProgressIndicator(strokeWidth: 3),
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
