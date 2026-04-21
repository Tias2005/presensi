import 'package:flutter/material.dart';
import '../../shared/theme.dart';

class SisaCutiInfo extends StatelessWidget {
  final int? sisaCuti;

  const SisaCutiInfo({super.key, required this.sisaCuti});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Text(
            "Sisa Jatah Cuti: ${sisaCuti ?? '-'} Hari",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}