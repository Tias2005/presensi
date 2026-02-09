import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.userData['nama_user']);
    _emailController = TextEditingController(text: widget.userData['email_user']);
    _phoneController = TextEditingController(text: widget.userData['no_telepon']);
    _alamatController = TextEditingController(text: widget.userData['alamat']);
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
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'nama_user': _namaController.text,
          'email_user': _emailController.text,
          'no_telepon': _phoneController.text,
          'alamat': _alamatController.text,
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
      } else if (response.statusCode == 401) {
        throw "Sesi Anda telah berakhir. Silakan login ulang.";
      } else {
        throw data['message'] ?? "Terjadi kesalahan pada server.";
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()), 
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      appBar: AppBar(title: const Text("Edit Profil"), foregroundColor: AppColors.primary, backgroundColor: Colors.white, elevation: 0.5),
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
              
              const SizedBox(height: 25),
              const Text("Ganti Password (Kosongkan jika tidak diubah)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)),
              const SizedBox(height: 15),
              _buildTextField("Password Lama", _passLamaController, Icons.lock_outline, isPass: true),
              _buildTextField("Password Baru", _passBaruController, Icons.lock_reset, isPass: true),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SIMPAN PERUBAHAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FaceRegisterPage())),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.face_retouching_natural),
                label: const Text("UPDATE SCAN WAJAH (FOTO PROFIL)"),
              )
            ],
          ),
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