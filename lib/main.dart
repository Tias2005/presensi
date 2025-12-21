import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:intl/intl.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CameraFacePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CameraFacePage extends StatefulWidget {
  const CameraFacePage({super.key});

  @override
  State<CameraFacePage> createState() => _CameraFacePageState();
}

class _CameraFacePageState extends State<CameraFacePage> {
  late CameraController _cameraController;
  int selectedCameraIndex = 0;
  bool isReady = false;
  bool isProcessing = false;
  String resultText = '';

  final FaceDetector faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
    ),
  );

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    _cameraController = CameraController(
      cameras[selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController.initialize();
    setState(() => isReady = true);
  }

  Future<Position> getLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('GPS tidak aktif');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied) {
    throw Exception('Izin lokasi ditolak');
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception('Izin lokasi ditolak permanen');
  }

  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}
  

  Future<void> captureAndProcess() async {
    try {
      setState(() {
        isProcessing = true;
        resultText = '';
      });

      final XFile photo = await _cameraController.takePicture();
      final File imageFile = File(photo.path);

      final DateTime captureTime = DateTime.now();
      final String formattedTime =
        DateFormat('dd-MM-yyyy HH:mm:ss').format(captureTime);

      final position = await getLocation();

      final inputImage = InputImage.fromFile(imageFile);
      final faces = await faceDetector.processImage(inputImage);

      setState(() {
        resultText = '''
          Latitude : ${position.latitude}
          Longitude: ${position.longitude}
          Waktu    : $formattedTime
          Wajah terdeteksi: ${faces.isNotEmpty}
          Jumlah wajah    : ${faces.length}
          ''';
      });
    } catch (e) {
      setState(() {
        resultText = 'Error: $e';
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Camera + GPS + Face')),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.cameraswitch),
        onPressed: () async {
          selectedCameraIndex =
              (selectedCameraIndex + 1) % cameras.length;

          await _cameraController.dispose();
          await initCamera();
        },
      ),

      body: Stack(
        children: [
          Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: CameraPreview(_cameraController),
              ),
              ElevatedButton(
                onPressed: isProcessing ? null : captureAndProcess,
                child: const Text('Ambil Foto & Deteksi Wajah'),
              ),
              Text(resultText),
            ],
          ),

          if (isProcessing)
            Container(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Memproses data...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    faceDetector.close();
    super.dispose();
  }
}
