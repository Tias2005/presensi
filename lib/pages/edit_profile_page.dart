import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../shared/theme.dart';
import 'login_page.dart';
import 'face_register_page.dart';
import '../config.dart';

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

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.userData['nama_user']);
    _emailController = TextEditingController(text: widget.userData['email_user']);
    _phoneController = TextEditingController(text: widget.userData['no_telepon']?.toString());
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
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar("Layanan lokasi nonaktif. Aktifkan GPS Anda.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar("Izin lokasi ditolak.");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedLocation = currentLatLng;
      });

      _mapController.move(currentLatLng, 15);
      _showSnackBar("Lokasi rumah berhasil diarahkan ke posisi Anda.");
    } catch (e) {
      _showSnackBar("Gagal mengambil lokasi: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      final response = await http.post(
        Uri.parse("${AppConfig.apiUrl}/user/update/${widget.userData['id_user']}"),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: {
          'nama_user': _namaController.text,
          'email_user': _emailController.text,
          'no_telepon': _phoneController.text,
          'alamat': _alamatController.text,
          'latitude_rumah': _selectedLocation?.latitude.toString(),
          'longitude_rumah': _selectedLocation?.longitude.toString(),
          'password_before': _passLamaController.text,
          'new_password': _passBaruController.text,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['password_changed'] == true) {
          await prefs.clear();
          if (!mounted) return;
          _showDialogSuccess("Password berhasil diubah. Silakan login kembali.", isLogout: true);
        } else {
          if (data['user'] != null) {
            await prefs.setString('user_data', jsonEncode(data['user']));
          }
          if (!mounted) return;
          _showDialogSuccess("Profil berhasil diperbarui.");
        }
      } else {
        throw data['message'] ?? "Terjadi kesalahan pada server.";
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDialogSuccess(String msg, {bool isLogout = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Icon(Icons.check_circle, color: AppColors.success, size: 50),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isLogout) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (r) => false);
              } else {
                Navigator.pop(context, true);
              }
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profil"),
        foregroundColor: AppColors.primary,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Data Umum", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
              const SizedBox(height: 15),
              _buildTextField("Nama Lengkap", _namaController, Icons.person_outline),
              _buildTextField("Email", _emailController, Icons.email_outlined),
              _buildTextField("No. Telepon", _phoneController, Icons.phone_android_outlined),
              _buildTextField("Alamat", _alamatController, Icons.location_on_outlined, maxLines: 2),

              const SizedBox(height: 10),
              const Text("Titik Lokasi Rumah", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
              const SizedBox(height: 10),
              
              _buildMapSection(),
              
              const SizedBox(height: 10),
              
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _getCurrentLocation,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text("AMBIL LOKASI SAAT INI"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                "Koordinat Terpilih: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}",
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),

              const SizedBox(height: 25),
              const Text("Keamanan & Wajah", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)),
              const SizedBox(height: 15),
              _buildTextField("Password Lama", _passLamaController, Icons.lock_outline, isPass: true),
              _buildTextField("Password Baru", _passBaruController, Icons.lock_reset, isPass: true),

              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FaceRegisterPage())),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.face_retouching_natural),
                label: const Text("UPDATE SCAN WAJAH (FOTO PROFIL)"),
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
                      : const Text("SIMPAN PERUBAHAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
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
            initialCenter: _selectedLocation!,
            initialZoom: 15,
            onTap: (tapPosition, point) {
              setState(() {
                _selectedLocation = point;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'id.presensi.karyawan.mobile',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _selectedLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPass = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: isPass,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}