import 'package:flutter/material.dart';
import '../../config.dart';

class DetailPresensiDialog extends StatelessWidget {
  final Map detail;

  const DetailPresensiDialog({super.key, required this.detail});

  static void show(BuildContext context, Map detail) {
    showDialog(
      context: context,
      builder: (_) => DetailPresensiDialog(detail: detail),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("Detail Presensi",
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _fotoSection(
                      "Foto Check In",
                      detail['foto_masuk'],
                      "Tidak ada foto masuk",
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _fotoSection(
                      "Foto Check Out",
                      detail['foto_pulang'],
                      "Belum ada foto pulang",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _row("Nama", detail['user']?['nama_user']),
              _row("Divisi", detail['user']?['divisi']?['nama_divisi']),
              _row("Jabatan", detail['user']?['jabatan']?['nama_jabatan']),
              const SizedBox(height: 10),

              _row("Waktu Masuk", detail['jam_masuk']),
              _row("Waktu Pulang", detail['jam_pulang']),
              _row("Lokasi Masuk", detail['lokasi_masuk']),
              _row("Lokasi Pulang", detail['lokasi_pulang']),
              _row(
                "Kategori",
                detail['kategori_kerja']?['nama_kategori_kerja'] ??
                    (detail['id_kategori_kerja'] == 1 ? 'WFO' : 'WFA'),
              ),
              _row(
                "Status",
                detail['status_presensi']?['nama_status_presensi'] ??
                    (detail['id_status_presensi'] == 1
                        ? 'Tepat Waktu'
                        : 'Terlambat'),
              ),
            ],
          ),
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

  Widget _fotoSection(String label, String? fotoPath, String emptyText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (fotoPath != null && fotoPath.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              "${AppConfig.storageUrl}$fotoPath",
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _fotoPlaceholder(const CircularProgressIndicator());
              },
              errorBuilder: (context, error, stack) =>
                  _fotoPlaceholder(Text("Foto tidak bisa dimuat",
                      style: TextStyle(color: Colors.grey[600]))),
            ),
          )
        else
          _fotoPlaceholder(Text(emptyText,
              style: TextStyle(color: Colors.grey[600]))),
      ],
    );
  }

  Widget _fotoPlaceholder(Widget child) {
    return Container(
      height: 150,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
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