import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../shared/theme.dart';
import '../config.dart';
import 'notification_page.dart';
import 'profile_page.dart';
import 'presensi_page.dart';
import 'riwayat_page.dart';
import '../widgets/dashboard/dashboard_appbar.dart';
import '../widgets/dashboard/dashboard_content.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _unreadCount = 0;
  int _currentIndex = 0;
  String _userName = "Memuat...";
  String _displayMessage = "";
  String _statusType = "work";
  Map<String, dynamic>? _todayPresence;
  Map<String, dynamic>? _jamKerja;
  Map<String, dynamic>? _jatahCuti;
  Map<String, dynamic>? _lokasiSetting;
  List<dynamic> _hariKerja = [];
  int? _sisaCuti;
  bool _isLoading = true;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _loadInitialData();
    _startClock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _requestNotificationPermission() async {
    await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString == null) return;

    final userData = jsonDecode(userDataString);
    final String userId = userData['id_user'].toString();
    setState(() => _userName = userData['nama_user'] ?? "Karyawan");

    await Future.wait([
      _fetchTodayPresence(userId),
      _fetchUnreadCount(userId),
      _fetchJadwalInfo(),
      _fetchSisaCuti(userId),
    ]);
  }

  Future<void> _fetchTodayPresence(String userId) async {
    try {
      final response = await http
          .get(Uri.parse("${AppConfig.apiUrl}/presensi/today/$userId"));
      if (response.statusCode == 200 && mounted) {
        final result = jsonDecode(response.body);
        setState(() {
          _statusType = result['status'];
          _displayMessage = result['message'] ?? "";
          _todayPresence = result['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUnreadCount(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.get(
        Uri.parse("${AppConfig.apiUrl}/notifications/unread-count/$userId"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );
      if (response.statusCode == 200 && mounted) {
        setState(() =>
            _unreadCount = jsonDecode(response.body)['unread_count'] ?? 0);
      }
    } catch (e) {
      debugPrint("Error count: $e");
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

  Future<void> _fetchSisaCuti(String userId) async {
    try {
      final response = await http
          .get(Uri.parse("${AppConfig.apiUrl}/jatah-cuti/karyawan/$userId"));
      if (response.statusCode == 200 && mounted) {
        setState(() =>
            _sisaCuti = jsonDecode(response.body)['data']['sisa'] ?? 0);
      }
    } catch (e) {
      debugPrint("Error sisa cuti: $e");
    }
  }

  Future<void> _openNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString == null || !mounted) return;

    final String userId = jsonDecode(userDataString)['id_user'].toString();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotificationPage(userId: userId)),
    );
    if (mounted) await _fetchUnreadCount(userId);
  }

  Future<void> _goToPresensi() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PresensiPage()),
    );
    if (result == true) _loadInitialData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCheckedIn = _todayPresence?['jam_masuk'] != null;

    final List<Widget> pages = [
      DashboardContent(
        now: _now,
        hasCheckedIn: hasCheckedIn,
        statusType: _statusType,
        displayMessage: _displayMessage,
        todayPresence: _todayPresence,
        jamKerja: _jamKerja,
        jatahCuti: _jatahCuti,
        lokasiSetting: _lokasiSetting,
        hariKerja: _hariKerja,
        sisaCuti: _sisaCuti,
        onScan: _goToPresensi,
        onRefresh: _refreshData,
      ),
      const RiwayatPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _currentIndex == 0
          ? DashboardAppBar(
              userName: _userName,
              unreadCount: _unreadCount,
              onNotificationTap: _openNotification,
            )
          : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: "Beranda"),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: "Riwayat"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: "Profil"),
        ],
      ),
    );
  }
}