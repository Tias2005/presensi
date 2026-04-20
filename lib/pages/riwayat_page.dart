import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/theme.dart';
import '../config.dart';
import '../widgets/app_refresh_wrapper.dart';
import '../widgets/riwayat/ringkasan_card.dart';
import '../widgets/riwayat/filter_export_bar.dart';
import '../widgets/riwayat/tab_presensi.dart';
import '../widgets/riwayat/tab_pengajuan.dart';
import '../widgets/riwayat/detail_presensi_dialog.dart';
import '../widgets/riwayat/detail_pengajuan_dialog.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  bool _isLoading = true;
  Map<String, dynamic> _ringkasan = {};
  List _riwayatHarian = [];
  List _riwayatPengajuan = [];
  String _selectedBulan = DateTime.now().month.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    _fetchRiwayat();
  }

  Future<void> _fetchRiwayat() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/riwayat-user?bulan=$_selectedBulan'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _ringkasan = data['ringkasan'];
          _riwayatHarian = data['riwayat_harian'];
          _riwayatPengajuan = data['riwayat_pengajuan'] ?? [];
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportExcel() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    await launchUrl(
      Uri.parse('${AppConfig.apiUrl}/export-riwayat-mobile?token=$token'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text("Riwayat",
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : AppRefreshWrapper(
                onRefresh: _fetchRiwayat,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            RingkasanCard(ringkasan: _ringkasan),
                            const SizedBox(height: 20),
                            FilterExportBar(
                              selectedBulan: _selectedBulan,
                              onBulanChanged: (v) {
                                setState(() => _selectedBulan = v);
                                _fetchRiwayat();
                              },
                              onExport: _exportExcel,
                            ),
                          ],
                        ),
                      ),

                      Container(
                        color: Colors.white,
                        child: TabBar(
                          labelColor: AppColors.primary,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: AppColors.primary,
                          tabs: const [
                            Tab(text: "Presensi"),
                            Tab(text: "Pengajuan"),
                          ],
                        ),
                      ),

                      SizedBox(
                        height: 500,
                        child: TabBarView(
                          children: [
                            TabPresensi(
                              riwayatHarian: _riwayatHarian,
                              onTapItem: (item) =>
                                  DetailPresensiDialog.show(context, item),
                            ),
                            TabPengajuan(
                              riwayatPengajuan: _riwayatPengajuan,
                              onTapItem: (item) =>
                                  DetailPengajuanDialog.show(context, item),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}