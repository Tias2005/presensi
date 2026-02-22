import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../shared/theme.dart';
import 'notification_page.dart';
import 'profile_page.dart';
import 'calendar_page.dart'; 
import 'form_pengajuan_page.dart';
import 'presensi_page.dart'; 
import 'riwayat_page.dart';
import '../config.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _unreadCount = 0;
  int _currentIndex = 0;
  String _userName = "Memuat...";
  Map<String, dynamic>? _todayPresence;
  Map<String, dynamic>? _userStats;
  Map<String, dynamic>? _jamKerja;
  Map<String, dynamic>? _jatahCuti;
  Map<String, dynamic>? _lokasiSetting;
  List<dynamic> _hariKerja = [];
  bool _isLoading = true;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _loadInitialData();
    _startClock();
    _initForegroundFetch();
  }

  Future<void> _openNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');

    if (!mounted) return;

    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      String userId = userData['id_user'].toString();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationPage(userId: userId),
        ),
      );

      if (mounted) {
        _loadInitialData();
      }
    }
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
        _fetchUnreadCount(userId),
        _fetchJadwalInfo(),
      ]);
    }
  }

  Future<void> _requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    }
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  void _initForegroundFetch() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Notifikasi diterima di foreground: ${message.notification?.title}");
      
      if (mounted) {
        _loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    await _loadInitialData();
  }

  String _displayMessage = "";
  String _statusType = "work";

  Future<void> _fetchTodayPresence(String userId) async {
    try {
      final response = await http.get(Uri.parse("${AppConfig.apiUrl}/presensi/today/$userId"));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _statusType = result['status'];
            _displayMessage = result['message'] ?? "";
            _todayPresence = result['data'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetch presensi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserStats(String userId) async {
    final response = await http.get(Uri.parse("${AppConfig.apiUrl}/user-stats/$userId"));
    if (response.statusCode == 200) {
      if (mounted) {
        setState(() {
          _userStats = jsonDecode(response.body)['data'];
        });
      }
    }
  }

  Future<void> _fetchUnreadCount(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${AppConfig.apiUrl}/notifications/unread-count/$userId"),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        int count = data['unread_count'] ?? 0;

        if (mounted) {
          setState(() {
            _unreadCount = count;
          });
        }
      } else {
        debugPrint("Gagal ambil count: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetch unread: $e");
    }
  }

  Future<void> _fetchJadwalInfo() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse("${AppConfig.apiUrl}/jam-kerja")),
        http.get(Uri.parse("${AppConfig.apiUrl}/hari-kerja")),
        http.get(Uri.parse("${AppConfig.apiUrl}/jatah-cuti/global")),
        http.get(Uri.parse("${AppConfig.apiUrl}/lokasi-presensi")),
      ]);

      if (mounted) {
        setState(() {
          _jamKerja = jsonDecode(responses[0].body);
          _hariKerja = jsonDecode(responses[1].body);
          _jatahCuti = jsonDecode(responses[2].body)['data'];
          _lokasiSetting = jsonDecode(responses[3].body)['data'];
        });
      }
    } catch (e) {
      debugPrint("Error fetch jadwal: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasCheckedIn = _todayPresence?['jam_masuk'] != null;

  final List<Widget> pages = [
      _buildDashboardContent(hasCheckedIn),
      const RiwayatPage(),
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
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_none, color: AppColors.primary),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$_unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                  ],
                ),
                onPressed: _openNotification,
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

  Widget _buildDashboardContent(bool hasCheckedIn) {
  String currentTime = DateFormat('HH:mm').format(_now);
  String currentDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_now);

    return RefreshIndicator( onRefresh: _refreshData, color: AppColors.primary, child: SingleChildScrollView(
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
                    _todayPresence?['jam_masuk'] != null,
                    true 
                ),
                const SizedBox(width: 15),
                _buildStatusCard(
                    "Check Out",
                    _todayPresence?['jam_pulang'] ?? "-- : --",
                    _todayPresence?['lokasi'] ?? "-",
                    _todayPresence?['jam_pulang'] != null,
                    hasCheckedIn 
                ),
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

          if (_userStats != null) ...[
            const SizedBox(height: 25),
            const Text("Statistik Saya",
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
                  _buildStatRow("Total Kehadiran", "${_userStats?['total_hadir'] ?? 0} Hari"),
                  _buildStatRow("Total Terlambat", "${_userStats?['total_terlambat'] ?? 0} Kali"),
                ],
              ),
            ),
          ],

          const SizedBox(height: 25),
          const Text("Informasi Penjadwalan",
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection("Kebijakan Cuti", [
                  _buildStatRow("Jatah Cuti Tahunan", "${_jatahCuti?['jatah_tahunan_global'] ?? 0} Hari"),
                ]),
                const Divider(height: 30),
                _buildInfoSection("Pengaturan Jam Kerja", [
                  _buildStatRow("Jam Masuk Utama", _jamKerja?['jam_masuk'] ?? "--:--"),
                  _buildStatRow("Jam Pulang Utama", _jamKerja?['jam_pulang'] ?? "--:--"),
                  _buildStatRow("Mulai Absen Masuk", _jamKerja?['mulai_absen_masuk'] ?? "--:--"),
                  _buildStatRow("Batas Akhir Masuk", _jamKerja?['batas_akhir_masuk'] ?? "--:--"),
                  _buildStatRow("Mulai Absen Pulang", _jamKerja?['mulai_absen_pulang'] ?? "--:--"),
                  _buildStatRow("Batas Akhir Pulang", _jamKerja?['batas_akhir_pulang'] ?? "--:--"),
                ]),
                const Divider(height: 30),
                _buildInfoSection("Hari Kerja", [
                _buildStatRow("Status", "${_hariKerja.where((h) => h['is_hari_kerja'] == 1).length} Hari/Minggu"),                  _buildStatRow("Hari", _hariKerja.where((h) => h['is_hari_kerja'] == 1).map((h) {
                    List<String> namaHari = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"];
                    return namaHari[h['hari_ke']];
                  }).join(", ")),
                ]),
                const Divider(height: 30),
                _buildInfoSection("Radius Presensi", [
                  _buildStatRow("Radius WFO", "${_lokasiSetting?['radius_wfo'] ?? 0} Meter"),
                  _buildStatRow("Radius WFH", "${_lokasiSetting?['radius_wfh'] ?? 0} Meter"),
                ]),
              ],
            ),
          ),

        ],
      ),
    ),
    );
  }

  Widget _buildStatusCard(String title, String time, String location, bool isDone, bool isEnabled) {
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
                  onPressed: isEnabled ? () async {
                    final result = await Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const PresensiPage())
                    );
                    if (result == true) {
                      _loadInitialData();
                    }
                  } : null, 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEnabled ? AppColors.primary : Colors.grey[300],
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  child: Text(
                    "Scan Sekarang", 
                    style: TextStyle(
                      fontSize: 10, 
                      color: isEnabled ? AppColors.white : Colors.grey[600]
                    )
                  ),
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

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value, 
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 13)
            ),
          ),
        ],
      ),
    );
  }
}