import 'dart:io';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/theme.dart'; // Import tema warna
import 'dashboard_page.dart';

class FaceRegisterPage extends StatefulWidget {
  const FaceRegisterPage({super.key});

  @override
  State<FaceRegisterPage> createState() => _FaceRegisterPageState();
}

class _FaceRegisterPageState extends State<FaceRegisterPage> {
  late CameraController _controller;
  Interpreter? _interpreter;
  bool _isReady = false;
  bool _isProcessing = false;
  final FaceDetector _faceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate));

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  Future<void> _initScanner() async {
    final cameras = await availableCameras();
    // Gunakan kamera depan (biasanya index 1)
    _controller = CameraController(cameras[1], ResolutionPreset.high);
    await _controller.initialize();
    _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
    if (mounted) setState(() => _isReady = true);
  }

  List<double> _extractEmbedding(File file, Face face) {
    final image = img.decodeImage(file.readAsBytesSync())!;
    final crop = img.copyCrop(image,
        x: face.boundingBox.left.toInt(),
        y: face.boundingBox.top.toInt(),
        width: face.boundingBox.width.toInt(),
        height: face.boundingBox.height.toInt());
    final resized = img.copyResize(crop, width: 112, height: 112);

    var input = [
      List.generate(112, (y) => List.generate(112, (x) {
            final pixel = resized.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          }))
    ];

    var output = List.filled(1 * 192, 0.0).reshape([1, 192]);
    _interpreter?.run(input, output);
    return List<double>.from(output[0]);
  }

  Future<void> _registerFace() async {
    setState(() => _isProcessing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) throw "Sesi berakhir, silakan login kembali.";

      final userData = jsonDecode(userDataString);
      final String idUser = userData['id_user'].toString();

      final photo = await _controller.takePicture();
      final faces = await _faceDetector.processImage(InputImage.fromFile(File(photo.path)));

      if (faces.isEmpty) throw "Wajah tidak terdeteksi. Pastikan pencahayaan cukup.";

      final embedding = _extractEmbedding(File(photo.path), faces.first);
      String postgresArray = "{${embedding.join(',')}}";

      var request = http.MultipartRequest('POST',
          Uri.parse('http://192.168.229.178:8000/api/user/register-face'));

      request.fields['id_user'] = idUser;
      request.fields['embedding'] = postgresArray;
      request.files.add(await http.MultipartFile.fromPath('foto', photo.path));
      request.headers.addAll({ 'Accept': 'application/json', 'Authorization': 'Bearer $token', });

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        userData['embedding_vector'] = responseData['user']['embedding_vector'];
        await prefs.setString('user_data', jsonEncode(userData));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Berhasil! Wajah Anda kini terdaftar."), backgroundColor: AppColors.success));
        
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
            (route) => false);
      } else {
        dev.log("Error Body: ${response.body}", name: "API_ERROR");
        throw "Gagal mendaftarkan wajah. Coba lagi nanti.";
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Registrasi Wajah", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Kamera
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _controller.value.aspectRatio,
              child: CameraPreview(_controller),
            ),
          ),

          // Overlay Bingkai Lingkaran
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.7),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 100),
                    height: 280,
                    width: 280,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(140),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Border Lingkaran (Glow Effect)
          Align(
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.only(bottom: 100),
              height: 285,
              width: 285,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 4),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
          ),

          // Instruksi Teks
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Posisikan Wajah Anda",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Pastikan wajah berada di dalam lingkaran dan pencahayaan terang.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _registerFace,
                        icon: _isProcessing 
                          ? const SizedBox.shrink() 
                          : const Icon(Icons.camera_alt, color: Colors.white),
                        label: _isProcessing
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("AMBIL FOTO WAJAH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    _interpreter?.close();
    super.dispose();
  }
}