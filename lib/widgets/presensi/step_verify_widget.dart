import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../shared/theme.dart';

class StepVerifyWidget extends StatelessWidget {
  final XFile capturedPhoto;
  final Position currentPosition;
  final String? currentAddress;
  final Map<String, dynamic>? userData;
  final int? selectedModeId;
  final bool isCheckOut;
  final bool isLoading;
  final VoidCallback onSubmit;

  const StepVerifyWidget({
    super.key,
    required this.capturedPhoto,
    required this.currentPosition,
    required this.currentAddress,
    required this.userData,
    required this.selectedModeId,
    required this.isCheckOut,
    required this.isLoading,
    required this.onSubmit,
  });

  String _formatDateTime(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}/"
        "${dt.month.toString().padLeft(2, '0')}/"
        "${dt.year} "
        "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}";
  }

  String get _modeName {
    switch (selectedModeId) {
      case 1: return "WFO";
      case 2: return "WFH";
      default: return "WFA";
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final parts = _formatDateTime(now).split(" ");
    final tanggal = parts[0];
    final jam = parts[1];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Foto wajah
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      File(capturedPhoto.path),
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Info user
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text("Nama"),
                          subtitle: Text(userData?['nama_user'] ?? "-"),
                        ),
                        ListTile(
                          leading: const Icon(Icons.work),
                          title: const Text("Jabatan"),
                          subtitle: Text(userData?['jabatan'] ?? "-"),
                        ),
                        ListTile(
                          leading: const Icon(Icons.apartment),
                          title: const Text("Divisi"),
                          subtitle: Text(userData?['divisi'] ?? "-"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Lokasi
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading:
                          const Icon(Icons.location_on, color: Colors.red),
                      title: const Text("Lokasi"),
                      subtitle: Text(
                        "${currentPosition.latitude}, ${currentPosition.longitude}"
                        "\n${currentAddress ?? 'Mengambil alamat...'}",
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Mode kerja
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.work_outline,
                          color: AppColors.primary),
                      title: const Text("Mode Kerja"),
                      subtitle: Text(_modeName),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tanggal & jam
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: const Text("Tanggal"),
                          subtitle: Text(tanggal),
                        ),
                        ListTile(
                          leading: const Icon(Icons.access_time),
                          title: Text(
                              isCheckOut ? "Jam Check Out" : "Jam Check In"),
                          subtitle: Text(jam),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tombol submit
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "KIRIM PRESENSI SEKARANG",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}