import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
      debugShowCheckedModeBanner: false,
      home: CameraFacePage(),
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
  final MapController _mapController = MapController();
  int selectedCameraIndex = 0;
  bool isReady = false;
  bool isProcessing = false;
  bool isModelLoaded = false;

  late Interpreter _interpreter;
  List<double>? registeredEmbedding;
  static const double threshold = 0.7;

  String resultText = 'Silahkan daftarkan wajah Anda terlebih dahulu.';
  LatLng? currentLatLng;

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
    loadModel();
  }

  Future<void> initCamera() async {
    _cameraController = CameraController(
      cameras[selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController.initialize();
    if (!mounted) return;
    setState(() => isReady = true);
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      setState(() => isModelLoaded = true);
    } catch (e) {
      debugPrint("Error loading model: $e");
    }
  }

  Future<Position> getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('GPS tidak aktif');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak permanen');
    }
    return await Geolocator.getCurrentPosition();
  }

  img.Image cropFace(File file, Face face) {
    final bytes = file.readAsBytesSync();
    final original = img.decodeImage(bytes)!;
    final rect = face.boundingBox;
    return img.copyCrop(
      original,
      x: rect.left.toInt(),
      y: rect.top.toInt(),
      width: rect.width.toInt(),
      height: rect.height.toInt(),
    );
  }

  List<List<List<List<double>>>> preprocess(img.Image face) {
    final resized = img.copyResize(face, width: 112, height: 112);
    return [
      List.generate(112, (y) => List.generate(112, (x) {
        final pixel = resized.getPixel(x, y);
        return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
      })),
    ];
  }

  List<double> getEmbedding(img.Image faceImage) {
    final input = preprocess(faceImage);
    final output = List.generate(1, (_) => List.filled(192, 0.0));
    _interpreter.run(input, output);
    return output[0];
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (sqrt(normA) * sqrt(normB));
  }

  // ================= MAIN PROCESS =================
  Future<void> captureAndProcess() async {
    try {
      setState(() {
        isProcessing = true;
        resultText = 'Memproses...';
      });

      final photo = await _cameraController.takePicture();
      final imageFile = File(photo.path);
      final faces = await faceDetector.processImage(InputImage.fromFile(imageFile));

      if (faces.isEmpty) {
        setState(() => resultText = 'Tidak ada wajah terdeteksi');
        return;
      }

      final faceImage = cropFace(imageFile, faces.first);
      final embedding = getEmbedding(faceImage);

      if (registeredEmbedding == null) {
        // PROSES ENROLL (Tanpa Lokasi)
        setState(() {
          registeredEmbedding = embedding;
          resultText = 'Wajah berhasil didaftarkan!\nSekarang Anda bisa melakukan verifikasi.';
        });
      } else {
        // PROSES VERIFY (Dengan Lokasi)
        final similarity = cosineSimilarity(registeredEmbedding!, embedding);
        final bool isMatch = similarity >= threshold;
        
        String recognitionResult = isMatch ? 'Wajah COCOK (MATCH)' : 'Wajah TIDAK COCOK';

        final position = await getLocation();
        final time = DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());

        setState(() {
          currentLatLng = LatLng(position.latitude, position.longitude);
          resultText = '''
Status: $recognitionResult
Waktu: $time
Lat: ${position.latitude}, Lng: ${position.longitude}
''';
        });

        // Update peta
        Future.delayed(const Duration(milliseconds: 500), () {
          _mapController.move(currentLatLng!, 15.0);
        });
      }
    } catch (e) {
      setState(() => resultText = 'Error: $e');
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Logika Nama Tombol
    String buttonLabel = registeredEmbedding == null ? 'Input Profil' : 'Recognition';
    IconData buttonIcon = registeredEmbedding == null ? Icons.person_add : Icons.verified_user;

    return Scaffold(
      appBar: AppBar(title: const Text('Face Attendance')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          selectedCameraIndex = (selectedCameraIndex + 1) % cameras.length;
          await _cameraController.dispose();
          initCamera();
        },
        child: const Icon(Icons.cameraswitch),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: CameraPreview(_cameraController),
            ),
            const SizedBox(height: 15),
            
            // Tombol Dinamis
            ElevatedButton.icon(
              onPressed: (isProcessing || !isModelLoaded) ? null : captureAndProcess,
              icon: isProcessing 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) 
                : Icon(buttonIcon),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(8)),
                child: Text(resultText, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

            // Peta hanya muncul jika sudah ada koordinat (setelah Verify)
            if (currentLatLng != null)
              Container(
                height: 200,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: currentLatLng!,
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.presensi',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: currentLatLng!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    faceDetector.close();
    _interpreter.close();
    super.dispose();
  }
}