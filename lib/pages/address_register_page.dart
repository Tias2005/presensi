import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import '../shared/theme.dart';
import '../config.dart';
import 'dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/permission_helper.dart';

class AddressRegisterPage extends StatefulWidget {
  const AddressRegisterPage({super.key});

  @override
  State<AddressRegisterPage> createState() => _AddressRegisterPageState();
}

class _AddressRegisterPageState extends State<AddressRegisterPage> {
  final TextEditingController _alamatController = TextEditingController();
  final MapController _mapController = MapController();

  Position? _currentPosition;
  LatLng? _mapCenter; 
  bool _isLoading = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    final allowed = await PermissionHelper.requestLocation(context: context);
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final autoAddress =
            "${place.street}, ${place.subLocality}, ${place.locality}";

        final latLng = LatLng(position.latitude, position.longitude);

        setState(() {
          _currentPosition = position;
          _alamatController.text = autoAddress;
          _mapCenter = latLng;
        });

        _mapController.move(latLng, 15);
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
        const SnackBar(content: Text("Alamat dan Koordinat harus diisi")),
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
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      } else {
        throw data['message'] ?? "Gagal menyimpan data";
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  LatLng get _displayCenter =>
      _mapCenter ?? const LatLng(-6.2000, 106.8166);

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
              "Halo! Sepertinya Anda belum mengatur lokasi rumah. "
              "Silakan lengkapi untuk keperluan presensi Geolocation.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _alamatController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Alamat Lengkap",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Titik Lokasi Rumah",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _displayCenter,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'id.presensi.karyawan.mobile',
                    ),
                    if (_currentPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
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
            const SizedBox(height: 10),

            if (_currentPosition != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "Koordinat: ${_currentPosition!.latitude.toStringAsFixed(6)}, "
                  "${_currentPosition!.longitude.toStringAsFixed(6)}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _getCurrentLocation,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(_isLoading ? "Mengambil lokasi..." : "AMBIL LOKASI SAAT INI"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SIMPAN & MASUK KE DASHBOARD",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}