import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../shared/theme.dart';
import '../config.dart';
import 'dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class AddressRegisterPage extends StatefulWidget {
  const AddressRegisterPage({super.key});

  @override
  State<AddressRegisterPage> createState() => _AddressRegisterPageState();
}

class _AddressRegisterPageState extends State<AddressRegisterPage> {
  final TextEditingController _alamatController = TextEditingController();
  Position? _currentPosition;
  bool _isLoading = false;

Future<bool> _checkLocationPermission() async {
  var status = await Permission.location.status;

  if (status.isGranted) return true;

  if (status.isDenied) {
    status = await Permission.location.request();
    if (status.isGranted) return true;
  }

  if (status.isPermanentlyDenied || status.isDenied) {
    if (!mounted) return false; 

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Izin lokasi diperlukan. Silakan aktifkan di pengaturan."),
      ),
    );

    openAppSettings();
  }

  return false;
}

Future<void> _getCurrentLocation() async {
  setState(() => _isLoading = true);

  final allowed = await _checkLocationPermission();
  if (!allowed) {
    setState(() => _isLoading = false);
    return;
  }

  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw "GPS tidak aktif. Silakan aktifkan lokasi di perangkat.";
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw "Izin lokasi ditolak.";
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw "Izin lokasi ditolak permanen. Buka pengaturan aplikasi.";
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (!mounted) return;

    if (placemarks.isNotEmpty) {
      Placemark place = placemarks[0];

      String autoAddress =
          "${place.street}, ${place.subLocality}, ${place.locality}";

      setState(() {
        _currentPosition = position;
        _alamatController.text = autoAddress;
      });
    }
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  Future<void> _handleSave() async {
    if (_alamatController.text.isEmpty || _currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Alamat dan Koordinat harus diisi"))
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      final String? userDataStr = prefs.getString('user_data');
      
      if (userDataStr == null) return;
      final userData = jsonDecode(userDataStr);

      final response = await http.put(
        Uri.parse('${AppConfig.apiUrl}/user/update/${userData['id_user']}'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nama_user': userData['nama_user'],
          'email_user': userData['email_user'],
          'alamat': _alamatController.text,
          'latitude_rumah': _currentPosition!.latitude,
          'longitude_rumah': _currentPosition!.longitude,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await prefs.setString('user_data', jsonEncode(data['user']));
        
        if (!mounted) return; 
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage())
        );
      } else {
        throw data['message'] ?? "Gagal menyimpan data";
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red)
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lengkapi Data Alamat"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Halo! Sepertinya Anda belum mengatur lokasi rumah. Silakan lengkapi untuk keperluan presensi Geolocation.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _alamatController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Alamat Lengkap",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300)
              ),
              child: Column(
                children: [
                  const Text("Koordinat Rumah", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  _currentPosition == null 
                    ? const Text("Lokasi belum diambil")
                    : Text("Lat: ${_currentPosition!.latitude}\nLong: ${_currentPosition!.longitude}"),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _getCurrentLocation,
                    icon: const Icon(Icons.location_on),
                    label: const Text("Ambil Lokasi Saat Ini"),
                  )
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SIMPAN & MASUK KE DASHBOARD", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}