import 'package:flutter/material.dart';
import 'status_card.dart';
// import '../../shared/theme.dart';

class StatusSection extends StatelessWidget {
  final String statusType;
  final Map<String, dynamic>? todayPresence;
  final String message;
  final bool hasCheckedIn;
  final VoidCallback onScan;

  const StatusSection({
    super.key,
    required this.statusType,
    required this.todayPresence,
    required this.message,
    required this.hasCheckedIn,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    if (statusType == 'success') {
      return Row(
        children: [
          StatusCard(
            title: "Check In",
            time: todayPresence?['jam_masuk'] ?? "-- : --",
            location: todayPresence?['lokasi'] ?? "-",
            isDone: todayPresence?['jam_masuk'] != null,
            isEnabled: true,
            onTap: onScan,
          ),
          const SizedBox(width: 15),
          StatusCard(
            title: "Check Out",
            time: todayPresence?['jam_pulang'] ?? "-- : --",
            location: todayPresence?['lokasi'] ?? "-",
            isDone: todayPresence?['jam_pulang'] != null,
            isEnabled: hasCheckedIn,
            onTap: onScan,
          ),
        ],
      );
    }

    if (statusType == 'leave') {
      return _leaveCard();
    }

    return _emptyCard();
  }

  Widget _leaveCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available,
              color: Colors.blue, size: 40),
          const SizedBox(height: 10),
          const Text("SEDANG PENGAJUAN",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 5),
          Text(
            message.isNotEmpty
                ? message
                : "Anda tidak perlu presensi hari ini",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    bool isHoliday = statusType == 'holiday';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHoliday
            ? Colors.red.withValues(alpha: 0.05)
            : Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(
            isHoliday ? Icons.celebration : Icons.event_busy,
            color: isHoliday ? Colors.red : Colors.orange,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            isHoliday ? "HARI LIBUR" : "TIDAK ADA JADWAL",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isHoliday ? Colors.red : Colors.orange,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message.isNotEmpty
                ? message
                : "Tidak ada jadwal presensi hari ini",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}