import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/theme.dart';
import '../config.dart';

class PresensiPage extends StatefulWidget {
  const PresensiPage({super.key});

  @override
  State<PresensiPage> createState() => _PresensiPageState();
}

class _PresensiPageState extends State<PresensiPage> {
  int _currentStep = 1;
  bool _isLoading = false;

  int? _selectedModeId;
  XFile? _capturedPhoto;
  Position? _currentPosition;
  Map<String, dynamic>? _configKantor;

  Interpreter? _interpreter;
  final FaceDetector _faceDetector =
      FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate));

  @override
  void initState() {
    super.initState();
    _loadModelAndConfig();
  }

  Future<void> _loadModelAndConfig() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/lokasi-presensi'));
      if (response.statusCode == 200) {
        if (mounted) setState(() => _configKantor = jsonDecode(response.body)['data']);
      }
    } catch (e) {
      debugPrint("Init Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getStepTitle()),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleBack),
      ),
      body: _buildCurrentStep(),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 1: return "Pilih Mode Kerja";
      case 2: return "Face Recognition";
      case 3: return "Geolocation";
      case 4: return "Verifikasi Akhir";
      default: return "Presensi";
    }
  }

  void _handleBack() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Widget _buildCurrentStep() {
    if (_configKantor == null) return const Center(child: CircularProgressIndicator());

    switch (_currentStep) {
      case 1: return _stepMode();
      case 2: return _StepFace(
          faceDetector: _faceDetector,
          interpreter: _interpreter!,
          onResult: (file) => setState(() { _capturedPhoto = file; _currentStep = 3; }),
        );
      case 3: return _StepGeo(
          modeId: _selectedModeId!,
          config: _configKantor!,
          onResult: (pos) => setState(() { _currentPosition = pos; _currentStep = 4; }),
        );
      case 4: return _stepVerify();
      default: return const SizedBox();
    }
  }

  Widget _stepMode() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _modeCard(1, "WFO (Office)", "Kerja dari Kantor", Icons.business),
        _modeCard(2, "WFH (Home)", "Kerja dari Rumah", Icons.home),
        _modeCard(3, "WFA (Anywhere)", "Kerja dari Mana Saja", Icons.public),
      ],
    );
  }

  Widget _modeCard(int id, String title, String sub, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub),
        onTap: () => setState(() { _selectedModeId = id; _currentStep = 2; }),
      ),
    );
  }

  Widget _stepVerify() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(File(_capturedPhoto!.path), height: 200, width: 200, fit: BoxFit.cover),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.red),
                  title: const Text("Lokasi Terdeteksi"),
                  subtitle: Text("${_currentPosition?.latitude}, ${_currentPosition?.longitude}"),
                ),
                ListTile(
                  leading: const Icon(Icons.work, color: AppColors.primary),
                  title: const Text("Mode Kerja"),
                  subtitle: Text(_selectedModeId == 1 ? "WFO" : _selectedModeId == 2 ? "WFH" : "WFA"),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitPresensi,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("KIRIM PRESENSI SEKARANG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _submitPresensi() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');
      if (userDataStr == null) return;
      final user = jsonDecode(userDataStr);
      
      var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.apiUrl}/presensi/store'));
      request.fields['id_user'] = user['id_user'].toString();
      request.fields['id_kategori_kerja'] = _selectedModeId.toString();
      request.fields['latitude'] = _currentPosition!.latitude.toString();
      request.fields['longitude'] = _currentPosition!.longitude.toString();
      request.fields['lokasi'] = "Lokasi terverifikasi GPS";
      
      request.files.add(await http.MultipartFile.fromPath('foto', _capturedPhoto!.path));
      
      var res = await request.send();
      if (res.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Presensi Berhasil Dikirim!")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _StepFace extends StatefulWidget {
  final FaceDetector faceDetector;
  final Interpreter interpreter;
  final Function(XFile) onResult;
  const _StepFace({required this.faceDetector, required this.interpreter, required this.onResult});

  @override
  State<_StepFace> createState() => _StepFaceState();
}

class _StepFaceState extends State<_StepFace> {
  CameraController? _camera;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cams = await availableCameras();
    _camera = CameraController(cams[1], ResolutionPreset.high, enableAudio: false);
    await _camera!.initialize();
    if (mounted) setState(() {});
  }

  List<double> _extract(File file, Face face) {
    final image = img.decodeImage(file.readAsBytesSync())!;
    final crop = img.copyCrop(image, 
      x: face.boundingBox.left.toInt(), 
      y: face.boundingBox.top.toInt(), 
      width: face.boundingBox.width.toInt(), 
      height: face.boundingBox.height.toInt()
    );
    final resized = img.copyResize(crop, width: 112, height: 112);
    
    var input = [List.generate(112, (y) => List.generate(112, (x) {
      final p = resized.getPixel(x, y);
      return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
    }))];
    
    var out = List.filled(1 * 192, 0.0).reshape([1, 192]);
    widget.interpreter.run(input, out);
    return List<double>.from(out[0]);
  }

  double _cosineDistance(List<double> e1, List<double> e2) {
    double dot = 0, n1 = 0, n2 = 0;
    for (int i = 0; i < e1.length; i++) {
      dot += e1[i] * e2[i];
      n1 += e1[i] * e1[i];
      n2 += e2[i] * e2[i];
    }
    double similarity = dot / (math.sqrt(n1) * math.sqrt(n2));
    return similarity;
  }

  Future<void> _processCapture() async {
    setState(() => _isProcessing = true);
    try {
      final photo = await _camera!.takePicture();
      final faces = await widget.faceDetector.processImage(InputImage.fromFile(File(photo.path)));
      
      if (faces.isEmpty) throw "Wajah tidak ditemukan!";

      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');
      if (userDataStr == null) throw "Sesi user tidak ditemukan";
      
      final user = jsonDecode(userDataStr);
      var vectorData = user['embedding_vector'];

      if (vectorData == null) throw "Data wajah belum terdaftar di profil.";

      List<double> registered;

      try {
        if (vectorData is List) {
          registered = vectorData.map((item) => double.parse(item.toString())).toList();
        } else if (vectorData is Map) {
          registered = vectorData.values.map((item) => double.parse(item.toString())).toList();
        } else if (vectorData is String) {
          String cleanString = vectorData.replaceAll('{', '').replaceAll('}', '').replaceAll('[', '').replaceAll(']', '');
          registered = cleanString.split(',')
              .where((s) => s.trim().isNotEmpty)
              .map((e) => double.parse(e.trim()))
              .toList();
        } else {
          throw "Tipe data ${vectorData.runtimeType} tidak didukung.";
        }
      } catch (e) {
        throw "Gagal memproses format data wajah: $e";
      }

      final current = _extract(File(photo.path), faces.first);
      double score = _cosineDistance(registered, current);

      if (score > 0.70) { 
        widget.onResult(photo);
      } else {
        throw "Wajah tidak cocok. Tingkat kemiripan: ${(score * 100).toStringAsFixed(1)}%";
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_camera == null || !_camera!.value.isInitialized) return const Center(child: CircularProgressIndicator());
    return Stack(
      children: [
        Positioned.fill(child: AspectRatio(aspectRatio: _camera!.value.aspectRatio, child: CameraPreview(_camera!))),
        ColorFiltered(
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.srcOut),
          child: Stack(
            children: [
              Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
              Align(
                alignment: Alignment.center,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 100),
                  height: 280, width: 280,
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(140)),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.only(bottom: 100),
            height: 285, width: 285,
            decoration: BoxDecoration(border: Border.all(color: AppColors.primary, width: 4), borderRadius: BorderRadius.circular(150)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Face Recognition", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _processCapture,
                    icon: _isProcessing ? const SizedBox.shrink() : const Icon(Icons.face_unlock_outlined, color: Colors.white),
                    label: _isProcessing ? const CircularProgressIndicator(color: Colors.white) : const Text("SCAN WAJAH SEKARANG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }
}

class _StepGeo extends StatefulWidget {
  final int modeId;
  final Map<String, dynamic> config;
  final Function(Position) onResult;
  const _StepGeo({required this.modeId, required this.config, required this.onResult});

  @override
  State<_StepGeo> createState() => _StepGeoState();
}

class _StepGeoState extends State<_StepGeo> {
  Position? _pos;
  bool _isValid = false;
  double _dist = 0;
  bool _loadingLocation = false;
  LatLng? _targetLocation;

  Future<void> _checkLocation() async {
    setState(() => _loadingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      
  const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high, 
    distanceFilter: 10, 
  );

  Position p = await Geolocator.getCurrentPosition(
    locationSettings: locationSettings,
  );

      double targetLat;
      double targetLng;
      double limit;

      if (widget.modeId == 1) { // WFO
        targetLat = double.parse(widget.config['latitude_kantor'].toString());
        targetLng = double.parse(widget.config['longitude_kantor'].toString());
        limit = double.parse(widget.config['radius_wfo'].toString());
      } else { // WFH
        final prefs = await SharedPreferences.getInstance();
        final user = jsonDecode(prefs.getString('user_data') ?? '{}');
        targetLat = double.parse(user['latitude_rumah']?.toString() ?? '0');
        targetLng = double.parse(user['longitude_rumah']?.toString() ?? '0');
        limit = double.parse(widget.config['radius_wfh'].toString());
      }

      _targetLocation = LatLng(targetLat, targetLng);
      double d = Geolocator.distanceBetween(p.latitude, p.longitude, targetLat, targetLng);

      if (mounted) {
        setState(() {
          _pos = p;
          _dist = d;
          _isValid = widget.modeId == 3 ? true : (d <= limit);
          _loadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mendapatkan lokasi: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _pos == null 
            ? const Center(child: Text("Klik tombol untuk melacak lokasi"))
            : FlutterMap(
                options: MapOptions(initialCenter: LatLng(_pos!.latitude, _pos!.longitude), initialZoom: 16),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.presensi',
                  ),
                  MarkerLayer(markers: [
                    Marker(point: LatLng(_pos!.latitude, _pos!.longitude), child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40)),
                    if (_targetLocation != null)
                      Marker(point: _targetLocation!, child: const Icon(Icons.location_on, color: Colors.red, size: 40)),
                  ]),
                  if (widget.modeId != 3 && _targetLocation != null) CircleLayer(circles: [
                    CircleMarker(
                      point: _targetLocation!,
                      radius: widget.modeId == 1 ? double.parse(widget.config['radius_wfo'].toString()) : double.parse(widget.config['radius_wfh'].toString()),
                      useRadiusInMeter: true, 
                      color: Colors.blue.withValues(alpha: 0.2), 
                      borderColor: Colors.blue, 
                      borderStrokeWidth: 2,
                    )
                  ]),
                ],
              ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            children: [
              if (_pos != null) 
                Text(
                  "Jarak ke ${widget.modeId == 1 ? 'Kantor' : 'Rumah'}: ${_dist.toStringAsFixed(0)} meter", 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _loadingLocation ? null : (_pos == null ? _checkLocation : (_isValid ? () => widget.onResult(_pos!) : null)),
                  style: ElevatedButton.styleFrom(backgroundColor: _isValid || _pos == null ? AppColors.primary : Colors.grey),
                  child: _loadingLocation 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_pos == null ? "LACAK LOKASI" : (_isValid ? "LANJUT VERIFIKASI" : "DI LUAR RADIUS"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}