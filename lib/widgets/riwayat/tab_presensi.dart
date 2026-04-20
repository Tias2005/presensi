import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TabPresensi extends StatelessWidget {
  final List riwayatHarian;
  final void Function(Map) onTapItem;

  const TabPresensi({
    super.key,
    required this.riwayatHarian,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    if (riwayatHarian.isEmpty) {
      return const Center(child: Text("Tidak ada data presensi"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: riwayatHarian.length,
      itemBuilder: (context, index) {
        final item = riwayatHarian[index];
        final tanggal = DateFormat('EEEE, dd MMM yyyy')
            .format(DateTime.parse(item['tanggal']));
        final isTepatWaktu = item['id_status_presensi'] == 1;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: () => onTapItem(item),
            title: Text(tanggal,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              "${item['kategori_kerja']['nama_kategori_kerja']} • Masuk: ${item['jam_masuk'] ?? '-'}",
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isTepatWaktu ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item['status_presensi']['nama_status_presensi'],
                style: TextStyle(
                  color: isTepatWaktu ? Colors.green : Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}