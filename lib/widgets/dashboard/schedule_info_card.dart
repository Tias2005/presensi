import 'package:flutter/material.dart';
import '../../shared/theme.dart';

class ScheduleInfoCard extends StatelessWidget {
  final Map<String, dynamic>? jamKerja;
  final Map<String, dynamic>? jatahCuti;
  final Map<String, dynamic>? lokasiSetting;
  final List<dynamic> hariKerja;
  final int? sisaCuti;

  const ScheduleInfoCard({
    super.key,
    required this.jamKerja,
    required this.jatahCuti,
    required this.lokasiSetting,
    required this.hariKerja,
    required this.sisaCuti,
  });

  List<dynamic> get _activeWorkDays => hariKerja.where((h) {
        final val = h['is_hari_kerja'];
        return val == true || val == 1 || val == "1" || val == "true";
      }).toList();

  String _jamStr(String key) =>
      (jamKerja?[key] ?? "--:--").toString().padRight(5).substring(0, 5);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection("Kebijakan Cuti", [
            _buildRow("Jatah Cuti Tahunan",
                "${jatahCuti?['jatah_tahunan_global'] ?? 0} Hari"),
            _buildRow("Sisa Jatah Cuti", "${sisaCuti ?? 0} Hari"),
          ]),
          const Divider(height: 30),
          _buildSection("Pengaturan Jam Kerja", [
            _buildRow("Mulai Absen Masuk", _jamStr('mulai_absen_masuk')),
            _buildRow("Batas Akhir Masuk", _jamStr('akhir_absen_masuk')),
            _buildRow("Mulai Absen Pulang", _jamStr('mulai_absen_pulang')),
            _buildRow("Batas Akhir Pulang", _jamStr('akhir_absen_pulang')),
          ]),
          const Divider(height: 30),
          _buildSection("Hari Kerja", [
            _buildRow("Status", "${_activeWorkDays.length} Hari/Minggu"),
            _buildRow(
                "Hari", _activeWorkDays.map((h) => h['nama_hari']).join(", ")),
          ]),
          const Divider(height: 30),
          _buildSection("Radius Presensi", [
            _buildRow("Radius WFO", "${lokasiSetting?['radius_wfo'] ?? 0} Meter"),
            _buildRow("Radius WFH", "${lokasiSetting?['radius_wfh'] ?? 0} Meter"),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87)),
        const SizedBox(height: 10),
        ...rows,
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.grey, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}