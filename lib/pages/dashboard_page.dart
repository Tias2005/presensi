import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../shared/theme.dart';
import 'profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;
  String _userName = "Memuat...";
  Map<String, dynamic>? _todayPresence;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      setState(() {
        _userName = userData['nama_user'] ?? "Karyawan";
      });
      await _fetchTodayPresence(userData['id_user'].toString());
    }
  }

  Future<void> _fetchTodayPresence(String userId) async {
    try {
      final response = await http.get(Uri.parse("http://192.168.229.178:8000/api/presensi/today/$userId"));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _todayPresence = result['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetch presensi: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildDashboardContent(),
      const Center(child: Text("Halaman Riwayat")),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _currentIndex == 0 
        ? AppBar(
            backgroundColor: AppColors.white,
            elevation: 0.5,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Selamat Datang", style: TextStyle(fontSize: 12, color: AppColors.grey)),
                Text(_userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Badge(
                  backgroundColor: Colors.red,
                  label: Text("2"), 
                  child: Icon(Icons.notifications_none, color: AppColors.primary)
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 10),
            ],
          )
        : null,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Beranda"),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: "Riwayat"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    String currentTime = DateFormat('HH.mm').format(DateTime.now());
    String currentDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jam Box
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.white, 
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
            ),
            child: Column(
              children: [
                const Text("Waktu Sekarang", style: TextStyle(color: AppColors.grey)),
                Text(currentTime, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 2)),
                Text(currentDate, style: const TextStyle(color: AppColors.grey)),
              ],
            ),
          ),
          
          const SizedBox(height: 25),
          const Text("Status Presensi Hari Ini", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
          const SizedBox(height: 15),
          
          Row(
            children: [
              _buildStatusCard(
                "Check In", 
                _todayPresence?['jam_masuk'] ?? "-- : --", 
                _todayPresence?['lokasi'] ?? "-", 
                _todayPresence?['jam_masuk'] != null
              ),
              const SizedBox(width: 15),
              _buildStatusCard(
                "Check Out", 
                _todayPresence?['jam_pulang'] ?? "-- : --", 
                _todayPresence?['lokasi'] ?? "-", 
                _todayPresence?['jam_pulang'] != null
              ),
            ],
          ),

          const SizedBox(height: 25),
          const Text("Ajukan Pengajuan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(15)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMenuItem(Icons.calendar_month, "Izin"),
                _buildMenuItem(Icons.work_history, "Cuti"),
                _buildMenuItem(Icons.more_time, "Lembur"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String time, String location, bool isDone) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDone ? AppColors.grey.withValues(alpha: 0.1) : AppColors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isDone ? Colors.transparent : AppColors.grey.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: AppColors.grey)),
            const SizedBox(height: 5),
            Text(time, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDone ? AppColors.primary : Colors.black)),
            Text(location, style: const TextStyle(fontSize: 11, color: AppColors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            if (isDone)
              const Row(children: [Icon(Icons.check_circle, size: 16, color: AppColors.success), SizedBox(width: 5), Text("Selesai", style: TextStyle(fontSize: 12, color: AppColors.success))])
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  child: const Text("Scan Sekarang", style: TextStyle(fontSize: 10, color: AppColors.white)),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.primary, size: 30),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
      ],
    );
  }
}