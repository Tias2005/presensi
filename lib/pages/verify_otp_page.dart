import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../shared/theme.dart';
import '../config.dart';
import 'reset_password_page.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;
  const VerifyOtpPage({super.key, required this.email});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiUrl}/verify-otp'),
        body: {'email_user': widget.email, 'otp': _otpController.text.trim()},
      );
      if (res.statusCode == 200) {
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => ResetPasswordPage(email: widget.email, otp: _otpController.text.trim())
        ));
      } else {
        throw jsonDecode(res.body)['message'] ?? 'OTP Salah';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60))),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo/logo_aplikasi_presensi.png',
                  height: 80,
                ),
                const SizedBox(height: 10),
                const Text(
                  "VERIFIKASI OTP",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),          ),
          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                Text("Masukkan 6 digit kode yang dikirim ke\n${widget.email}", textAlign: TextAlign.center),
                const SizedBox(height: 30),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(hintText: "000000", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text("VERIFIKASI", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}