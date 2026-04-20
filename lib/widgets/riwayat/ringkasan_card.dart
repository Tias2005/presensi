import 'package:flutter/material.dart';
import '../../shared/theme.dart';

class RingkasanCard extends StatelessWidget {
  final Map<String, dynamic> ringkasan;

  const RingkasanCard({super.key, required this.ringkasan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text("Ringkasan Bulan Ini",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.5,
            children: [
              _item("Hadir", "${ringkasan['hadir'] ?? 0} Hari", Colors.green),
              _item("Terlambat", "${ringkasan['terlambat'] ?? 0} Hari", Colors.orange),
              _item("Izin", "${ringkasan['izin'] ?? 0} Hari", Colors.lightBlue),
              _item("Cuti", "${ringkasan['cuti'] ?? 0} Hari", Colors.redAccent),
              _item("Lembur", "${ringkasan['lembur'] ?? 0} Jam", Colors.purple),
              _item("WFO", "${ringkasan['wfo'] ?? 0} Kali", Colors.teal),
              _item("WFH", "${ringkasan['wfh'] ?? 0} Kali", Colors.indigo),
              _item("WFA", "${ringkasan['wfa'] ?? 0} Kali", Colors.cyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _item(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}