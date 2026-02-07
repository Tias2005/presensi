import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'profile_page.dart'; // Pastikan file ini sudah dibuat

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;
  String _userName = "Memuat...";

  // List halaman untuk navigasi
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _pages = [
        const DashboardContent(), // Index 0: Beranda
        const Center(child: Text("Halaman Riwayat (Segera Hadir)")), // Index 1: Riwayat (Tambahkan ini sebagai placeholder)
        const ProfilePage(),      // Index 2: Profil
      ];
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      setState(() {
        _userName = userData['nama_user'] ?? "Karyawan";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      // AppBar hanya muncul jika sedang di halaman Beranda (index 0)
      // Karena ProfilePage biasanya punya AppBar sendiri
      appBar: _currentIndex == 0 
        ? AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Selamat Datang", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(_userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Badge(label: Text("2"), child: Icon(Icons.notifications_none, color: Colors.black)),
                onPressed: () {},
              ),
              const SizedBox(width: 10),
            ],
          )
        : null, 
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF111827), // Navy
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Beranda"),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: "Riwayat"), // Placeholder Riwayat
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }
}

// Widget terpisah untuk isi konten Dashboard agar rapi
class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    String currentTime = DateFormat('HH.mm').format(DateTime.now());
    String currentDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Jam & Waktu
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
            ),
            child: Column(
              children: [
                const Text("Waktu Sekarang", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 5),
                Text(currentTime, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 2)),
                Text(currentDate, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          
          const SizedBox(height: 25),
          
          // Status Presensi (Check In / Out)
          const Text("Status Presensi Hari Ini", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildStatusCard("Check In", "08:00", "Kantor Pusat", true),
              const SizedBox(width: 15),
              _buildStatusCard("Check Out", "-- : --", "-", false),
            ],
          ),

          const SizedBox(height: 25),
          
          // Menu Pengajuan
          const Text("Ajukan Pengajuan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
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
          color: isDone ? Colors.grey[300] : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: isDone ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 5),
            Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(location, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            if (isDone)
              const Row(children: [Icon(Icons.check_box, size: 16, color: Colors.green), SizedBox(width: 5), Text("Selesai", style: TextStyle(fontSize: 12))])
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  child: const Text("Scan Sekarang", style: TextStyle(fontSize: 10, color: Colors.white)),
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
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: const Color(0xFF111827), size: 30),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}