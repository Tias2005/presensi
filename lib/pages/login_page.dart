import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/theme.dart';
import 'dashboard_page.dart';
import 'face_register_page.dart';
import 'forgot_password_page.dart';
import '../config.dart';
import 'address_register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan Password harus diisi"))
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/login-mobile'),
        headers: {'Accept': 'application/json'},
        body: {
          'email': _emailController.text.trim(),
          'password': _passController.text,
        },
      );

      final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('user_data', jsonEncode(data['user']));

      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        await http.post(
          Uri.parse('${AppConfig.apiUrl}/save-fcm-token'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${data['token']}',
          },
          body: {
            'id_user': data['user']['id_user'],
            'fcm_token': fcmToken,
          },
        );
      }

      if (!mounted) return;

      final dynamic embedding = data['user']['embedding_vector'];
      bool hasFaceData = false;
        if (embedding != null) {
          if (embedding is List && embedding.isNotEmpty) {
            hasFaceData = true;
          } else if (embedding.toString() != "[]" && embedding.toString().isNotEmpty && embedding.toString() != "null") {
            hasFaceData = true;
          }
        }

        if (!hasFaceData) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const FaceRegisterPage())
          );
        } else {
        final lat = data['user']['latitude_rumah'];
        final long = data['user']['longitude_rumah'];

        bool hasLocation = (lat != null && long != null && lat != 0);

        if (!hasLocation) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const AddressRegisterPage())
          );
        } else {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const DashboardPage())
          );
        }
      }} else {
        throw data['message'] ?? 'Gagal Terhubung ke Server';
      } 
    } catch (e) {
      dev.log("Login Error: $e", name: "AUTH");
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
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 350,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(80)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Image.asset(
                      'assets/logo/logo_aplikasi_presensi.png', 
                      height: 120, 
                      errorBuilder: (c, e, s) => const Icon(Icons.account_circle, size: 100, color: Colors.white)
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "APLIKASI PRESENSI", 
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)
                    ),
                    const Text(
                      "Sistem Kehadiran Karyawan", 
                      style: TextStyle(color: Colors.white70, fontSize: 14)
                    ),
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: Column(
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email Karyawan",
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: AppColors.accent, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: _passController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: AppColors.accent, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordPage()));
                      },
                      child: const Text("Lupa Password? Reset di sini", style: TextStyle(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(
                            height: 20, 
                            width: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          ) 
                        : const Text(
                            "MASUK", 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}