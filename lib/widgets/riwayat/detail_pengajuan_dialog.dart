import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config.dart';

class DetailPengajuanDialog extends StatelessWidget {
  final Map detail;

  const DetailPengajuanDialog({super.key, required this.detail});

  static void show(BuildContext context, Map detail) {
    showDialog(
      context: context,
      builder: (_) => DetailPengajuanDialog(detail: detail),
    );
  }

  bool get _isLembur =>
      (detail['kategori']['nama_pengajuan'] ?? '')
          .toLowerCase()
          .contains('lembur');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("Detail Pengajuan",
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row("Nama", detail['user']['nama_user']),
            _row("Divisi", detail['user']['divisi']['nama_divisi']),
            _row("Jabatan", detail['user']['jabatan']['nama_jabatan']),
            _row("Tipe", detail['kategori']['nama_pengajuan']),
            const SizedBox(height: 10),

            if (_isLembur) ...[
              _row("Tanggal Lembur", detail['tanggal_mulai'].split(" ")[0]),
              _row("Jam Mulai", detail['jam_mulai'] ?? '--:--'),
              _row("Jam Selesai", detail['jam_selesai'] ?? '--:--'),
            ] else ...[
              _row("Tanggal Mulai", detail['tanggal_mulai'].split(" ")[0]),
              _row("Tanggal Selesai", detail['tanggal_selesai'].split(" ")[0]),
            ],
            const SizedBox(height: 10),

            const Text("Alasan",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(detail['alasan'] ?? "-"),
            const SizedBox(height: 15),

            if (detail['lampiran'] != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text("Download Lampiran"),
                onPressed: () async {
                  final url = Uri.parse(
                    '${AppConfig.apiUrl}/pengajuan/download/${detail['id_pengajuan']}',
                  );
                  await launchUrl(url,
                      mode: LaunchMode.externalApplication);
                },
              )
            else
              const Text("Tidak ada lampiran",
                  style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Tutup"),
        ),
      ],
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text("$label:",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value?.toString() ?? "-")),
        ],
      ),
    );
  }
}