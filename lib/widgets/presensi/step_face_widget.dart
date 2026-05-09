import 'dart:io';
// import 'dart:ui';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
// import '../../shared/theme.dart';
import '../../services/user_service.dart';
import '../../widgets/app_dialog.dart';
// import 'dart:typed_data';
// import 'package:flutter/foundation.dart';

enum LivenessStep {
  none,
  blink,
  smile,
  turnHead,
  done,
}

class StepFaceWidget extends StatefulWidget {
  final FaceDetector faceDetector;
  final Interpreter interpreter;
  final Function(XFile) onResult;
  final VoidCallback onFailed;

  const StepFaceWidget({
    super.key,
    required this.faceDetector,
    required this.interpreter,
    required this.onResult,
    required this.onFailed,
  });

  @override
  State<StepFaceWidget> createState() => _StepFaceWidgetState();
}

class _StepFaceWidgetState extends State<StepFaceWidget> {
  CameraController? _camera;
  bool _isProcessing = false;
  bool _isSuccess = false;
  
  List<LivenessStep> _steps = []; 
  int _currentStepIndex = 0; 
  LivenessStep get _currentStep => _steps.isNotEmpty ? _steps[_currentStepIndex] : LivenessStep.none;

  bool _wasEyeOpen = false;
  bool _isActive = true;
  int get totalSteps => 4; 

  @override
  void initState() {
    super.initState();
    _generateRandomSteps(); 
    _initCamera();
  }
  
  void _generateRandomSteps() {
    List<LivenessStep> baseSteps = [
      LivenessStep.blink,
      LivenessStep.smile,
      LivenessStep.turnHead,
    ];
    baseSteps.shuffle();
    
    setState(() {
      _steps = [
        LivenessStep.none,   
        ...baseSteps,        
        LivenessStep.done,   
      ];
      _currentStepIndex = 0;
    });
  }

  @override
  void dispose() {
    _isActive = false;
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final allowed = await _checkCameraPermission();
    if (!allowed) return;

    final cams = await availableCameras();
    _camera = CameraController(
      cams.firstWhere((c) => c.lensDirection == CameraLensDirection.front),
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _camera!.initialize();

    _startDetectionLoop();

    if (mounted) setState(() {});
  }

  void _processLiveness(Face face) {
    final leftEye = face.leftEyeOpenProbability ?? 1.0;
    final rightEye = face.rightEyeOpenProbability ?? 1.0;
    final smile = face.smilingProbability ?? 0.0;
    final headY = face.headEulerAngleY ?? 0.0;

    bool isEyeOpen = leftEye > 0.4 && rightEye > 0.4;
    bool isEyeClosed = leftEye < 0.4 && rightEye < 0.4;

    bool stepCompleted = false;

    switch (_currentStep) {
      case LivenessStep.none:
        if (isEyeOpen) {
          _wasEyeOpen = true;
          stepCompleted = true;
        }
        break;

      case LivenessStep.blink:
        if (_wasEyeOpen && isEyeClosed) {
          stepCompleted = true;
        }
        break;

      case LivenessStep.smile:
        if (smile > 0.6) {
          stepCompleted = true;
        }
        break;

      case LivenessStep.turnHead:
        if (headY > 12 || headY < -12) {
          stepCompleted = true;
        }
        break;

      case LivenessStep.done:
        break;
    }

    if (stepCompleted) {
      setState(() {
        _currentStepIndex++;
        _wasEyeOpen = isEyeOpen; 
      });
    }
  }

  String get instruction {
      String text;
      switch (_currentStep) {
        case LivenessStep.none:
          text = "Arahkan wajah ke kamera";
          break;
        case LivenessStep.blink:
          text = "Kedipkan mata";
          break;
        case LivenessStep.smile:
          text = "Tersenyum";
          break;
        case LivenessStep.turnHead:
          text = "Putar kepala";
          break;
        case LivenessStep.done:
          text = "Memproses...";
          break;
      }
      return "Step ${_currentStepIndex + 1}/$totalSteps\n$text";
    }

    int get currentStepUIIndex => _currentStepIndex + 1;

  Future<void> _verifyFace(XFile photo, Face face) async {
    try {
      await UserService.refreshUserData();

      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');

      if (userDataStr == null) throw "User tidak ditemukan";

      final user = jsonDecode(userDataStr);
      final vectorData = user['embedding_vector'];

      List<double> registered = _parseVector(vectorData);

      List<double> current =
          _extract(File(photo.path), face);

      final score = _cosineDistance(registered, current);

      if (score > 0.60) {
        _isSuccess = true;

          _isActive = false;
          _camera?.dispose();

        widget.onResult(photo);
      } else {
              if (!mounted) return;

              AppDialog.show(
                context,
                message: "Wajah tidak cocok, silakan ulangi scan",
                onOk: () {
                  _generateRandomSteps(); 
                  setState(() {
                    _wasEyeOpen = false;
                    _isProcessing = false;
                    _isSuccess = false;
                  });
                },
              );
            }
    } catch (e) {
      if (!mounted) return;
      AppDialog.show(context, message: e.toString());
    }
  }

  List<double> _parseVector(dynamic vectorData) {
    if (vectorData is List) {
      return vectorData.map((e) => double.parse(e.toString())).toList();
    } else if (vectorData is String) {
      return vectorData
          .replaceAll('{', '')   
          .replaceAll('}', '')   
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(',')
          .map((e) => double.parse(e.trim()))
          .toList();
    } else {
      throw "Format embedding tidak valid";
    }
  }

  List<double> _extract(File file, Face face) {
    final image = img.decodeImage(file.readAsBytesSync())!;

    final crop = img.copyCrop(
      image,
      x: face.boundingBox.left.toInt(),
      y: face.boundingBox.top.toInt(),
      width: face.boundingBox.width.toInt(),
      height: face.boundingBox.height.toInt(),
    );

    final resized = img.copyResize(crop, width: 112, height: 112);

    final input = [
      List.generate(112, (y) => List.generate(112, (x) {
            final p = resized.getPixel(x, y);
            return [p.r / 255, p.g / 255, p.b / 255];
          }))
    ];

    final output = List.filled(1 * 192, 0.0).reshape([1, 192]);

    widget.interpreter.run(input, output);

    List<double> emb = List<double>.from(output[0]);

    final norm = math.sqrt(emb.fold(0, (s, e) => s + e * e));
    return emb.map((e) => e / norm).toList();
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

Future<void> _startDetectionLoop() async {
  while (_isActive && _camera != null && _camera!.value.isInitialized) {
    if (_isProcessing) {
      await Future.delayed(const Duration(milliseconds: 300));
      continue;
    }

    _isProcessing = true;

    try {
      final photo = await _camera!.takePicture();

      final inputImage = InputImage.fromFilePath(photo.path);

      final faces =
          await widget.faceDetector.processImage(inputImage);

      debugPrint("Faces detected: ${faces.length}");

      if (faces.isNotEmpty) {
        final face = faces.first;

        _processLiveness(face);

      if (_currentStep == LivenessStep.done) {
        await _verifyFace(photo, face);

        if (_isSuccess) {
          break;
        }
      }}
    } catch (e) {
      debugPrint("Loop error: $e");
    }

    _isProcessing = false;

    await Future.delayed(const Duration(milliseconds: 500));
  }
}

  Future<bool> _checkCameraPermission() async {
    var status = await Permission.camera.request();
    return status.isGranted;
  }

  int get currentStepIndex {
    switch (_currentStep) {
      case LivenessStep.none:
        return 1;
      case LivenessStep.blink:
        return 2;
      case LivenessStep.smile:
        return 3;
      case LivenessStep.turnHead:
        return 4;
      case LivenessStep.done:
        return 4;
    }
  }
  

  @override
  Widget build(BuildContext context) {
    if (_camera == null || !_camera!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        CameraPreview(_camera!),

        const FaceGuideOverlay(),

        Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 80),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: currentStepIndex / totalSteps,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.green),
                  ),
                ),
                const SizedBox(height: 8),

                // Text
                Text(
                  instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class FaceGuideOverlay extends StatelessWidget {
  const FaceGuideOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _FaceGuidePainter(),
      ),
    );
  }
}

class _FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayColor = Colors.black.withValues(alpha: 0.6);

    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    final finalPath = Path.combine(
      PathOperation.difference,
      path,
      circlePath,
    );

    canvas.drawPath(finalPath, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}