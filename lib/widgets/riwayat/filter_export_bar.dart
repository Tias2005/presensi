import 'package:flutter/material.dart';
import '../../shared/theme.dart';

class FilterExportBar extends StatelessWidget {
  final String selectedBulan;
  final ValueChanged<String> onBulanChanged;
  final VoidCallback onExport;

  static const List<String> _namaBulan = [
    "Januari", "Februari", "Maret", "April", "Mei", "Juni",
    "Juli", "Agustus", "September", "Oktober", "November", "Desember",
  ];

  const FilterExportBar({
    super.key,
    required this.selectedBulan,
    required this.onBulanChanged,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedBulan,
                isExpanded: true,
                items: List.generate(12, (index) {
                  final val = (index + 1).toString().padLeft(2, '0');
                  return DropdownMenuItem(
                      value: val, child: Text(_namaBulan[index]));
                }),
                onChanged: (v) {
                  if (v != null) onBulanChanged(v);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.file_download_outlined),
          label: const Text("Export"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}