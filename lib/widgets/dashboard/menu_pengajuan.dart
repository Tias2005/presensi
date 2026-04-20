import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../pages/form_pengajuan_page.dart';

class MenuPengajuan extends StatelessWidget {
  const MenuPengajuan({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(context, Icons.edit_note, "Izin", 1),
          _item(context, Icons.work_history, "Cuti", 2),
          _item(context, Icons.more_time, "Lembur", 3),
        ],
      ),
    );
  }

  Widget _item(
      BuildContext context, IconData icon, String label, int id) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FormPengajuanPage(tipe: label, idKategori: id),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}