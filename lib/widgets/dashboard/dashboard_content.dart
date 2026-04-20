import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../pages/calendar_page.dart';
import '../../widgets/app_refresh_wrapper.dart';
import 'time_card.dart';
import 'status_section.dart';
import 'menu_pengajuan.dart';
import 'schedule_info_card.dart';

class DashboardContent extends StatelessWidget {
  final DateTime now;
  final bool hasCheckedIn;
  final String statusType;
  final String displayMessage;
  final Map<String, dynamic>? todayPresence;
  final Map<String, dynamic>? jamKerja;
  final Map<String, dynamic>? jatahCuti;
  final Map<String, dynamic>? lokasiSetting;
  final List<dynamic> hariKerja;
  final int? sisaCuti;
  final VoidCallback onScan;
  final Future<void> Function() onRefresh;

  const DashboardContent({
    super.key,
    required this.now,
    required this.hasCheckedIn,
    required this.statusType,
    required this.displayMessage,
    required this.todayPresence,
    required this.jamKerja,
    required this.jatahCuti,
    required this.lokasiSetting,
    required this.hariKerja,
    required this.sisaCuti,
    required this.onScan,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AppRefreshWrapper(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TimeCard(now: now),

            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Status Presensi Hari Ini",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CalendarPage()),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined,
                      color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            StatusSection(
              statusType: statusType,
              todayPresence: todayPresence,
              message: displayMessage,
              hasCheckedIn: hasCheckedIn,
              onScan: onScan,
            ),

            const SizedBox(height: 25),

            const Text(
              "Ajukan Pengajuan",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 15),
            const MenuPengajuan(),

            const SizedBox(height: 25),

            const Text(
              "Informasi Penjadwalan",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 15),

            ScheduleInfoCard(
              jamKerja: jamKerja,
              jatahCuti: jatahCuti,
              lokasiSetting: lokasiSetting,
              hariKerja: hariKerja,
              sisaCuti: sisaCuti,
            ),
          ],
        ),
      ),
    );
  }
}