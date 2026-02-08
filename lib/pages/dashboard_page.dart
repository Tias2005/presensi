import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../shared/theme.dart';
import 'profile_page.dart';
import 'calendar_page.dart'; 
import 'form_pengajuan_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;
  String _userName = "Memuat...";
  Map<String, dynamic>? _todayPresence;
  Map<String, dynamic>? _userStats;
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
      String userId = userData['id_user'].toString();
      
      setState(() {
        _userName = userData['nama_user'] ?? "Karyawan";
      });

      await Future.wait([
        _fetchTodayPresence(userId),
        _fetchUserStats(userId),
      ]);
    }
  }

  String _displayMessage = "";
  String _statusType = "work";

  Future<void> _fetchTodayPresence(String userId) async {
    try {
      final response = await http.get(Uri.parse("http://192.168.229.178:8000/api/presensi/today/$userId"));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _statusType = result['status'];
          _displayMessage = result['message'] ?? "";
          _todayPresence = result['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetch presensi: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserStats(String userId) async {
    final response = await http.get(Uri.parse("http://192.168.229.178:8000/api/user-stats/$userId"));
    if (response.statusCode == 200) {
      setState(() {
        _userStats = jsonDecode(response.body)['data'];
      });
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
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ]),
            child: Column(
              children: [
                const Text("Waktu Sekarang", style: TextStyle(color: AppColors.grey)),
                Text(currentTime,
                    style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 2)),
                Text(currentDate, style: const TextStyle(color: AppColors.grey)),
              ],
            ),
          ),

          const SizedBox(height: 25),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Status Presensi Hari Ini",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary)),
              IconButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarPage()));
                },
                icon: const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
                tooltip: "Lihat Kalender",
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_statusType == 'success')
            Row(
              children: [
                _buildStatusCard(
                    "Check In",
                    _todayPresence?['jam_masuk'] ?? "-- : --",
                    _todayPresence?['lokasi'] ?? "-",
                    _todayPresence?['jam_masuk'] != null),
                const SizedBox(width: 15),
                _buildStatusCard(
                    "Check Out",
                    _todayPresence?['jam_pulang'] ?? "-- : --",
                    _todayPresence?['lokasi'] ?? "-",
                    _todayPresence?['jam_pulang'] != null),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _statusType == 'holiday' 
                    ? Colors.red.withValues(alpha: 0.05) 
                    : Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: _statusType == 'holiday' ? Colors.red.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)
                )
              ),
              child: Column(
                children: [
                  Icon(
                    _statusType == 'holiday' ? Icons.celebration : Icons.event_busy,
                    color: _statusType == 'holiday' ? Colors.red : Colors.orange,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statusType == 'holiday' ? "HARI LIBUR" : "TIDAK ADA JADWAL",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _statusType == 'holiday' ? Colors.red : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _displayMessage.isNotEmpty ? _displayMessage : "Hari ini Anda tidak dijadwalkan untuk presensi.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 25),

          const Text("Ajukan Pengajuan",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.white, borderRadius: BorderRadius.circular(15)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                  _buildMenuItem(Icons.edit_note, "Izin", onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const FormPengajuanPage(tipe: "Izin", idKategori: 1)));
                  }),
                  _buildMenuItem(Icons.work_history, "Cuti", onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const FormPengajuanPage(tipe: "Cuti", idKategori: 2)));
                  }),
                  _buildMenuItem(Icons.more_time, "Lembur", onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const FormPengajuanPage(tipe: "Lembur", idKategori: 3)));
                  }),
              ],
            ),
          ),

          const SizedBox(height: 25),
          const Text("Statistik Bulan Ini",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
            color: AppColors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                _buildStatRow("Hadir", _userStats?['hadir'] ?? "0 hari"),
                const Divider(height: 20),
                _buildStatRow("Terlambat", _userStats?['terlambat'] ?? "0 kali"),
                const Divider(height: 20),
                _buildStatRow("Izin", _userStats?['izin'] ?? "0 hari"),
                const Divider(height: 20),
                _buildStatRow("Cuti", _userStats?['cuti'] ?? "0 hari"),
                const Divider(height: 20),
                _buildStatRow("Lembur", _userStats?['lembur'] ?? "0 jam"),
              ],
            ),
          ),
          const SizedBox(height: 20),

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

  Widget _buildMenuItem(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
      ],
    );
  }
}