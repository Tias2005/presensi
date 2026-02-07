// lib/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_page.dart';
import 'face_register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;
  
  // Warna Tema Website (Navy Blue)
  final Color primaryColor = const Color(0xFF111827); 

  Future<void> _handleLogin() async {
    // Validasi input sederhana
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan Password harus diisi"))
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('http://192.168.229.178:8000/api/login-mobile'),
        headers: {
          'Accept': 'application/json',
          // Header ini penting agar Laravel tahu kita minta response JSON
        },
        body: {
          'email': _emailController.text.trim(),
          'password': _passController.text,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        
        // 1. Simpan Token Sanctum yang asli dari Laravel
        await prefs.setString('token', data['token']);
        
        // 2. Simpan Data User
        await prefs.setString('user_data', jsonEncode(data['user']));

        if (!mounted) return;
        
        // 3. Cek apakah user sudah daftar wajah (embedding_vector)
        final dynamic embedding = data['user']['embedding_vector'];
        
        // Logika pengecekan yang lebih kuat untuk null atau string kosong
        bool hasFaceData = embedding != null && 
                           embedding.toString().isNotEmpty && 
                           embedding.toString() != "null";

        if (!hasFaceData) {
          // Jika belum ada data wajah, paksa ke halaman registrasi wajah
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const FaceRegisterPage())
          );
        } else {
          // Jika sudah ada, langsung ke Dashboard
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const DashboardPage())
          );
        }
      } else {
        // Handle error seperti "Email tidak terdaftar" atau "Password salah"
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
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header melengkung Navy
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(80)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo_web.png', 
                      height: 80, 
                      errorBuilder: (c, e, s) => const Icon(Icons.verified_user, size: 80, color: Colors.white)
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Monitoring Presensi", 
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
                    ),
                    const Text(
                      "Mobile App Karyawan", 
                      style: TextStyle(color: Colors.white70)
                    ),
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email Karyawan",
                      prefixIcon: Icon(Icons.email, color: primaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock, color: primaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text(
                            "MASUK", 
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
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