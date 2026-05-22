import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/theme.dart';
import '../config.dart';
import '../widgets/app_dialog.dart';
import '../services/user_service.dart';
import '../widgets/presensi/step_mode_widget.dart';
import '../widgets/presensi/step_face_widget.dart';
import '../widgets/presensi/step_geo_widget.dart';
import '../widgets/presensi/step_verify_widget.dart';

class PresensiPage extends StatefulWidget {
  const PresensiPage({super.key});

  @override
  State<PresensiPage> createState() => _PresensiPageState();
}

class _PresensiPageState extends State<PresensiPage> {
  int _currentStep = 1;
  bool _isCheckingStatus = true;
  bool _isLoading = false;
  bool _isCheckOut = false;

  int? _selectedModeId;
  XFile? _capturedPhoto;
  Position? _currentPosition;
  String? _currentAddress;
  Map<String, dynamic>? _configKantor;
  Map<String, dynamic>? _userData;

  Interpreter? _interpreter;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast, 
      enableClassification: true,             
      enableLandmarks: true,                  
    ),
  );

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _init() async {
    await UserService.refreshUserData();
    await _loadModelAndConfig();
    await _checkTodayStatus();
  }

  Future<void> _loadModelAndConfig() async {
    try {
      _interpreter =
          await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      final response =
          await http.get(Uri.parse('${AppConfig.apiUrl}/lokasi-presensi'));
      if (response.statusCode == 200 && mounted) {
        setState(() => _configKantor = jsonDecode(response.body)['data']);
      }
    } catch (e) {
      debugPrint("Init Error: $e");
    }
  }

  Future<void> _checkTodayStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataStr = prefs.getString('user_data');

    if (userDataStr == null) {
      setState(() => _isCheckingStatus = false);
      return;
    }

    final user = jsonDecode(userDataStr);
    _userData = user;

    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/presensi/today/${user['id_user']}'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['data'] != null) {

        final presensi = data['data'];

        if (presensi['jam_pulang'] == null) {

          _isCheckOut = true;
          _selectedModeId = presensi['id_kategori_kerja'];

        } else {

          _isCheckOut = false;
          _selectedModeId = null;
        }

        _currentStep = 1;
      }
    }

    if (mounted) setState(() => _isCheckingStatus = false);
  }

  String _getStepTitle() {
    if (_isCheckOut) {
      switch (_currentStep) {
        case 2: return "Face Recognition";
        case 3: return "Geolocation";
        case 4: return "Verifikasi Akhir";
        default: return "Presensi";
      }
    }
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

  Future<String> _getAddressFromLatLng(double lat, double lon) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json');
    final response =
        await http.get(url, headers: {'User-Agent': 'presensi-app'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['display_name'] ?? "Alamat tidak ditemukan";
    }
    return "Alamat tidak ditemukan";
  }

  Future<void> _submitPresensi() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');
      if (userDataStr == null) throw "Sesi user tidak ditemukan";
      final user = jsonDecode(userDataStr);

      final request = http.MultipartRequest(
          'POST', Uri.parse('${AppConfig.apiUrl}/presensi/store'));
      request.headers['Accept'] = 'application/json';
      request.fields['id_user'] = user['id_user'].toString();
      if (!_isCheckOut) {
        request.fields['id_kategori_kerja'] = _selectedModeId.toString();
      }
      request.fields['latitude'] = _currentPosition!.latitude.toString();
      request.fields['longitude'] = _currentPosition!.longitude.toString();

      final String alamat = await _getAddressFromLatLng(
          _currentPosition!.latitude, _currentPosition!.longitude);
      request.fields['lokasi'] = alamat;

      request.files.add(
          await http.MultipartFile.fromPath('foto', _capturedPhoto!.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        AppDialog.show(
          context,
          message: responseData['message'] ?? "Presensi Berhasil!",
          isSuccess: true,
          onOk: () => Navigator.pop(context, true),
        );
      } else {
        throw responseData['message'] ??
            "Gagal menyimpan data (Error ${response.statusCode})";
      }
    } catch (e) {
      if (!mounted) return;
      AppDialog.show(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return StepModeWidget(
          selectedModeId: _selectedModeId,
          isCheckOut: _isCheckOut,
          onModeSelected: (id) => setState(() {
            _selectedModeId = id;
            _currentStep = 2;
          }),
        );

      case 2:
        return StepFaceWidget(
          faceDetector: _faceDetector,
          interpreter: _interpreter!,
          onResult: (file) => setState(() {
            _capturedPhoto = file;
            _currentStep = 3;
          }),
          onFailed: () => setState(() {
            _currentStep = 1; 
          }),
        );

      case 3:
        return StepGeoWidget(
          modeId: _selectedModeId!,
          config: _configKantor!,
          onResult: (pos) async {
            final String alamat =
                await _getAddressFromLatLng(pos.latitude, pos.longitude);
            setState(() {
              _currentPosition = pos;
              _currentAddress = alamat;
              _currentStep = 4;
            });
          },
        );

      case 4:
        return StepVerifyWidget(
          capturedPhoto: _capturedPhoto!,
          currentPosition: _currentPosition!,
          currentAddress: _currentAddress,
          userData: _userData,
          selectedModeId: _selectedModeId,
          isCheckOut: _isCheckOut,
          isLoading: _isLoading,
          onSubmit: _submitPresensi,
        );

      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStatus || _configKantor == null || _interpreter == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getStepTitle()),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
      ),
      body: _buildCurrentStep(),
    );
  }
}