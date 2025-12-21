import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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
  bool isReady = false;
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
      cameras.first,
      ResolutionPreset.medium,
    );
    await _cameraController.initialize();
    setState(() => isReady = true);
  }

  Future<Position> getLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  // 1️⃣ Cek GPS aktif atau tidak
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('GPS tidak aktif');
  }

  // 2️⃣ Cek permission
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

  // 3️⃣ Ambil lokasi
  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}
  

  Future<void> captureAndProcess() async {
  try {
    // 1️⃣ Ambil foto
    final XFile photo = await _cameraController.takePicture();
    final File imageFile = File(photo.path);

    // 2️⃣ Ambil lokasi
    final position = await getLocation();

    // 3️⃣ Face detection
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await faceDetector.processImage(inputImage);

    setState(() {
      resultText = '''
Latitude : ${position.latitude}
Longitude: ${position.longitude}
Wajah terdeteksi: ${faces.isNotEmpty}
Jumlah wajah    : ${faces.length}
''';
    });
  } catch (e) {
    setState(() {
      resultText = 'Error: $e';
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
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: _cameraController.value.aspectRatio,
            child: CameraPreview(_cameraController),
          ),
          ElevatedButton(
            onPressed: captureAndProcess,
            child: const Text('Ambil Foto & Deteksi Wajah'),
          ),
          Text(resultText),
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
