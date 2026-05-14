import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as dev;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../shared/theme.dart';
import '../config.dart';
import '../widgets/app_dialog.dart';
import '../helpers/permission_helper.dart';
import 'login_page.dart';
import 'face_update_page.dart';
import '../widgets/profile/section_header.dart';
import '../widgets/profile/profile_text_field.dart';
import '../widgets/profile/home_location_map.dart';
import '../widgets/profile/security_section.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfilePage({super.key, required this.userData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController; 
  late TextEditingController _alamatController;
  final TextEditingController _passLamaController = TextEditingController();
  final TextEditingController _passBaruController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng? _selectedLocation;
  bool _isLoading = false;

  String _stripPrefix(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    String s = raw.trim();
    if (s.startsWith('+62')) return s.substring(3);
    if (s.startsWith('62')) return s.substring(2);
    if (s.startsWith('0')) return s.substring(1);
    return s;
  }

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.userData['nama_user']);
    _emailController = TextEditingController(text: widget.userData['email_user']);
    _phoneController = TextEditingController(
      text: _stripPrefix(widget.userData['no_telepon']?.toString()),
    );
    _alamatController = TextEditingController(text: widget.userData['alamat']);

    double lat = double.tryParse(widget.userData['latitude_rumah']?.toString() ?? "0") ?? -6.2000;
    double lng = double.tryParse(widget.userData['longitude_rumah']?.toString() ?? "0") ?? 106.8166;
    if (lat == 0 && lng == 0) {
      lat = -6.2000;
      lng = 106.8166;
    }
    _selectedLocation = LatLng(lat, lng);
  }

  Future<void> _getCurrentLocation() async {
    final allowed = await PermissionHelper.requestLocation(context: context);
    if (!allowed) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar("Layanan lokasi nonaktif. Aktifkan GPS Anda.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
      final position = await Geolocator.getCurrentPosition(locationSettings: locationSettings);
      final currentLatLng = LatLng(position.latitude, position.longitude);

      setState(() => _selectedLocation = currentLatLng);
      await _getAddressFromLatLng(currentLatLng);
      _mapController.move(currentLatLng, 15);
      _showSnackBar("Lokasi rumah berhasil diarahkan ke posisi Anda.");
    } catch (e) {
      _showSnackBar("Gagal mengambil lokasi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _alamatController.text =
              "${p.street ?? ''}, ${p.subLocality ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}";
        });
      }
    } catch (e) {
      dev.log("Reverse geocoding error: $e");
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final fullPhone = '+62${_phoneController.text.trim()}';

      final response = await http.post(
        Uri.parse("${AppConfig.apiUrl}/user/update/${widget.userData['id_user']}"),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: {
          'nama_user': _namaController.text,
          'email_user': _emailController.text,
          'no_telepon': fullPhone,
          'alamat': _alamatController.text,
          'latitude_rumah': _selectedLocation?.latitude.toString(),
          'longitude_rumah': _selectedLocation?.longitude.toString(),
          'password_before': _passLamaController.text,
          'new_password': _passBaruController.text,
        },
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['password_changed'] == true) {
          await prefs.clear();
          if (!mounted) return;
          AppDialog.show(
            context,
            message: "Password berhasil diubah. Silakan login kembali.",
            isSuccess: true,
            onOk: () {
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          );
        } else {
          AppDialog.show(
            context,
            message: "Profil berhasil diperbarui",
            isSuccess: true,
            onOk: () {
              if (mounted) Navigator.pop(context, true);
            },
          );
        }
      } else {
        throw data['message'] ?? "Terjadi kesalahan pada server.";
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _goToFaceUpdate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FaceUpdatePage()),
    );
    if (!mounted) return;
    if (result == true) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Edit Profil",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: "Data Umum"),
              const SizedBox(height: 20),

              ProfileTextField("Nama Lengkap", _namaController, Icons.person_outline),
              ProfileTextField("Email", _emailController, Icons.email_outlined),

              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: "No. Telepon",
                    prefixIcon: const Icon(Icons.phone_android_outlined),
                    prefix: const Text(
                      '+62 ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'No. telepon wajib diisi';
                    if (val.trim().length < 7) return 'Nomor terlalu pendek';
                    return null;
                  },
                ),
              ),

              ProfileTextField("Alamat", _alamatController, Icons.location_on_outlined, maxLines: 2),

              const SizedBox(height: 10),
              const Text(
                "Titik Lokasi Rumah",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
              ),
              const SizedBox(height: 12),

              HomeLocationMap(
                mapController: _mapController,
                selectedLocation: _selectedLocation!,
                onTap: (point) async {
                  setState(() => _selectedLocation = point);
                  await _getAddressFromLatLng(point);
                },
                onGetCurrentLocation: _getCurrentLocation,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 25),

              SecuritySection(
                passLamaController: _passLamaController,
                passBaruController: _passBaruController,
                onUpdateFace: _goToFaceUpdate,
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "SIMPAN PERUBAHAN",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}