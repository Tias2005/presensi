import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../shared/theme.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';
import '../config.dart';
import '../widgets/app_refresh_wrapper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userData;
  final String _baseUrl = AppConfig.storageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_data');
    if (data != null) {
      setState(() {
        _userData = jsonDecode(data);
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _showLogoutConfirmation() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            "Keluar Akun",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Apakah Anda yakin ingin keluar dari akun Anda?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); 
              },
              child: const Text(
                "Tidak",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); 
                _logout(); 
              },
              child: const Text(
                "Ya",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Profil Saya", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.white), 
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'edit') {
                final result = await Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => EditProfilePage(userData: _userData!))
                );
                if (result == true) _loadProfile();
              } else if (value == 'logout') {
                _showLogoutConfirmation();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Text("Edit Profil"),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text("Keluar", style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: AppRefreshWrapper(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30, top: 10),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: ClipOval(
                            child: _userData!['foto_profil'] != null
                                ? Image.network(
                                    "$_baseUrl${_userData!['foto_profil']}",
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.person, size: 70, color: Colors.white);
                                    },
                                  )
                                : const Icon(Icons.person, size: 70, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _userData!['nama_user'] ?? "-",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _userData!['jabatan'] ?? "Karyawan",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), letterSpacing: 1.1),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              child: Column(
                children: [
                  _buildProfileItem("Divisi", _userData!['divisi']?.toString() ?? "-", Icons.business_center_outlined),
                  _buildProfileItem("Bergabung Sejak", _userData!['tanggal_bergabung']?.toString() ?? "-", Icons.calendar_today_outlined),
                  _buildProfileItem("Email", _userData!['email_user']?.toString() ?? "-", Icons.email_outlined),
                  _buildProfileItem("Telepon", _userData!['no_telepon']?.toString() ?? "-", Icons.phone_android_outlined),
                  _buildProfileItem("Alamat", _userData!['alamat']?.toString() ?? "-", Icons.location_on_outlined),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}