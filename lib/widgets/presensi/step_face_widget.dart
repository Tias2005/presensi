import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../shared/theme.dart';
import '../../services/user_service.dart';
import '../../widgets/app_dialog.dart';

class StepFaceWidget extends StatefulWidget {
  final FaceDetector faceDetector;
  final Interpreter interpreter;
  final Function(XFile) onResult;

  const StepFaceWidget({
    super.key,
    required this.faceDetector,
    required this.interpreter,
    required this.onResult,
  });

  @override
  State<StepFaceWidget> createState() => _StepFaceWidgetState();
}

class _StepFaceWidgetState extends State<StepFaceWidget> {
  CameraController? _camera;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final bool allowed = await _checkCameraPermission();
    if (!allowed) return;
    final cams = await availableCameras();
    _camera = CameraController(cams[1], ResolutionPreset.high, enableAudio: false);
    await _camera!.initialize();
    if (mounted) setState(() {});
  }

  List<double> _extract(File file, Face face) {
    final image = img.decodeImage(file.readAsBytesSync())!;

    final int x = face.boundingBox.left.toInt().clamp(0, image.width - 1);
    final int y = face.boundingBox.top.toInt().clamp(0, image.height - 1);
    final int w = face.boundingBox.width.toInt().clamp(0, image.width - x);
    final int h = face.boundingBox.height.toInt().clamp(0, image.height - y);

    final crop = img.copyCrop(image, x: x, y: y, width: w, height: h);
    final resized = img.copyResize(crop, width: 112, height: 112);

    final input = [
      List.generate(112, (iy) => List.generate(112, (ix) {
            final p = resized.getPixel(ix, iy);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          }))
    ];

    final out = List.filled(1 * 192, 0.0).reshape([1, 192]);
    widget.interpreter.run(input, out);

    List<double> emb = List<double>.from(out[0]);
    final double norm = math.sqrt(emb.fold(0, (sum, e) => sum + e * e));
    emb = emb.map((e) => e / norm).toList();

    return emb;
  }

  double _cosineDistance(List<double> e1, List<double> e2) {
    double dot = 0, n1 = 0, n2 = 0;
    for (int i = 0; i < e1.length; i++) {
      dot += e1[i] * e2[i];
      n1 += e1[i] * e1[i];
      n2 += e2[i] * e2[i];
    }
    return dot / (math.sqrt(n1) * math.sqrt(n2));
  }

  Future<void> _processCapture() async {
    setState(() => _isProcessing = true);
    try {
      final photo = await _camera!.takePicture();
      final faces = await widget.faceDetector
          .processImage(InputImage.fromFile(File(photo.path)));

      if (faces.isEmpty) throw "Wajah tidak ditemukan!";

      await UserService.refreshUserData();
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');
      if (userDataStr == null) throw "Sesi user tidak ditemukan";

      final user = jsonDecode(userDataStr);
      final vectorData = user['embedding_vector'];
      if (vectorData == null) throw "Data wajah belum terdaftar di profil.";

      List<double> registered;
      try {
        if (vectorData is List) {
          registered = vectorData.map((item) => double.parse(item.toString())).toList();
        } else if (vectorData is Map) {
          registered = vectorData.values
              .map((item) => double.parse(item.toString()))
              .toList();
        } else if (vectorData is String) {
          final cleanString = vectorData
              .replaceAll('{', '')
              .replaceAll('}', '')
              .replaceAll('[', '')
              .replaceAll(']', '');
          registered = cleanString
              .split(',')
              .where((s) => s.trim().isNotEmpty)
              .map((e) => double.parse(e.trim()))
              .toList();
        } else {
          throw "Format data wajah (${vectorData.runtimeType}) tidak dikenal";
        }
      } catch (e) {
        throw "Gagal membaca data wajah: $e";
      }

      List<double> current = _extract(File(photo.path), faces.first);
      final double norm = math.sqrt(current.fold(0, (sum, e) => sum + e * e));
      current = current.map((e) => e / norm).toList();

      final double score = _cosineDistance(registered, current);

      if (score > 0.70) {
        widget.onResult(photo);
      } else {
        throw "Verifikasi gagal. Wajah Anda tidak match dengan profil Anda";
      }
    } catch (e) {
      if (!mounted) return;
      AppDialog.show(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool> _checkCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      status = await Permission.camera.request();
      return status.isGranted;
    }
    if (status.isPermanentlyDenied) {
      _showPermissionDialog(
        "Izin Kamera Dibutuhkan",
        "Untuk melakukan scan wajah Anda harus mengaktifkan izin kamera terlebih dahulu di pengaturan.",
      );
    }
    return false;
  }

  void _showPermissionDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("Nanti Saja"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: openAppSettings,
            child: const Text("Pengaturan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_camera == null || !_camera!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(
          child: AspectRatio(
            aspectRatio: _camera!.value.aspectRatio,
            child: CameraPreview(_camera!),
          ),
        ),
        // Overlay gelap dengan lubang oval
        ColorFiltered(
          colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.7), BlendMode.srcOut),
          child: Stack(
            children: [
              Container(
                  decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut)),
              Align(
                alignment: Alignment.center,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 100),
                  height: 280,
                  width: 280,
                  decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(140)),
                ),
              ),
            ],
          ),
        ),
        // Border lingkaran
        Align(
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.only(bottom: 100),
            height: 285,
            width: 285,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 4),
              borderRadius: BorderRadius.circular(150),
            ),
          ),
        ),
        // Tombol bawah
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Face Recognition",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _processCapture,
                    icon: _isProcessing
                        ? const SizedBox.shrink()
                        : const Icon(Icons.face_unlock_outlined,
                            color: Colors.white),
                    label: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("SCAN WAJAH SEKARANG",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}