import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/theme.dart';

class TimeCard extends StatelessWidget {
  final DateTime now;

  const TimeCard({super.key, required this.now});

  @override
  Widget build(BuildContext context) {
    String currentTime = DateFormat('HH:mm').format(now);
    String currentDate =
        DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);

    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          const Text("Waktu Sekarang",
              style: TextStyle(color: AppColors.grey)),
          Text(
            currentTime,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: 2,
            ),
          ),
          Text(currentDate,
              style: const TextStyle(color: AppColors.grey)),
        ],
      ),
    );
  }
}