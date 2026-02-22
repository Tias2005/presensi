import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/theme.dart';
import '../config.dart';
import 'package:url_launcher/url_launcher.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  bool _isLoading = true;
  Map<String, dynamic> _ringkasan = {};
  List _riwayatHarian = [];
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
    final url = Uri.parse('${AppConfig.apiUrl}/export-riwayat-user?bulan=$_selectedBulan&token=$token');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: const FlexibleSpaceBar(
              title: Text("Riwayat Presensi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              centerTitle: false,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRingkasanCard(),
                  const SizedBox(height: 20),
                  _buildFilterAndExport(),
                  const SizedBox(height: 10),
                  _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _buildListRiwayat(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRingkasanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Ringkasan Bulan Ini", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, 
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: [
              _itemRingkasan("Hadir", "${_ringkasan['hadir'] ?? 0}", Colors.green),
              _itemRingkasan("Terlambat", "${_ringkasan['terlambat'] ?? 0}", Colors.orange),
              _itemRingkasan("Izin", "${_ringkasan['izin'] ?? 0}", Colors.lightBlue),
              _itemRingkasan("Cuti", "${_ringkasan['cuti'] ?? 0}", Colors.redAccent),
              _itemRingkasan("Lembur", "${_ringkasan['lembur'] ?? 0} Jam", Colors.purple),
              _itemRingkasan("WFO", "${_ringkasan['wfo'] ?? 0}", Colors.teal),
              _itemRingkasan("WFH", "${_ringkasan['wfh'] ?? 0}", Colors.indigo),
              _itemRingkasan("WFA", "${_ringkasan['wfa'] ?? 0}", Colors.cyan),
            ],
          )
        ],
      ),
    );
  }

  Widget _itemRingkasan(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterAndExport() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBulan,
                items: List.generate(12, (index) {
                  String val = (index + 1).toString().padLeft(2, '0');
                  return DropdownMenuItem(value: val, child: Text("Bulan $val"));
                }),
                onChanged: (v) {
                  setState(() => _selectedBulan = v!);
                  _fetchRiwayat();
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _exportExcel,
          icon: const Icon(Icons.download, size: 18),
          label: const Text("Export"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.primary)),
          ),
        )
      ],
    );
  }

  Widget _buildListRiwayat() {
    if (_riwayatHarian.isEmpty) return const Center(child: Padding(padding: EdgeInsets.only(top: 50), child: Text("Tidak ada data presensi")));
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _riwayatHarian.length,
      itemBuilder: (context, index) {
        final item = _riwayatHarian[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(item['tanggal'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${item['kategori_kerja']['nama_kategori_kerja']} - ${item['jam_masuk']}"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item['id_status_presensi'] == 1 ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(8)
              ),
              child: Text(
                item['status_presensi']['nama_status_presensi'],
                style: TextStyle(color: item['id_status_presensi'] == 1 ? Colors.green : Colors.red, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }
}