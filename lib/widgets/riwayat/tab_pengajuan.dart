import 'package:flutter/material.dart';

class TabPengajuan extends StatelessWidget {
  final List riwayatPengajuan;
  final void Function(Map) onTapItem;

  const TabPengajuan({
    super.key,
    required this.riwayatPengajuan,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    if (riwayatPengajuan.isEmpty) {
      return const Center(child: Text("Belum ada riwayat pengajuan"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: riwayatPengajuan.length,
      itemBuilder: (context, index) {
        final item = riwayatPengajuan[index];
        final status = item['status_pengajuan'];
        final Color statusColor = status == "Disetujui"
            ? Colors.green
            : (status == "Ditolak" ? Colors.red : Colors.orange);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: () => onTapItem(item),
            title: Text(
              item['kategori']['nama_pengajuan'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("Tanggal: ${item['tanggal_mulai']}"),
            trailing: Text(
              status,
              style: TextStyle(
                  color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}