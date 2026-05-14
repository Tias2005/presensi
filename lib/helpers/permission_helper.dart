import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum AppPermission { camera, location, microphone }

class PermissionHelper {
  static Future<bool> request(
    AppPermission type, {
    BuildContext? context,

    String? dialogTitle,
    String? dialogMessage,

    VoidCallback? onDismiss,
  }) async {
    final permission = _toPermission(type);
    var status = await permission.status;

    if (status.isGranted) return true;

    if (status.isDenied) {
      status = await permission.request();
      if (status.isGranted) return true;
    }

    if (status.isPermanentlyDenied || status.isDenied) {
      if (context != null && context.mounted) {
        await _showSettingsDialog(
          context,
          title: dialogTitle ?? _defaultTitle(type),
          message: dialogMessage ?? _defaultMessage(type),
          onDismiss: onDismiss,
        );
      }
    }

    return false;
  }

  static Future<bool> requestCamera({
    BuildContext? context,
    String? dialogTitle,
    String? dialogMessage,
    VoidCallback? onDismiss,
  }) =>
      request(
        AppPermission.camera,
        context: context,
        dialogTitle: dialogTitle,
        dialogMessage: dialogMessage,
        onDismiss: onDismiss,
      );

  static Future<bool> requestLocation({
    BuildContext? context,
    String? dialogTitle,
    String? dialogMessage,
    VoidCallback? onDismiss,
  }) =>
      request(
        AppPermission.location,
        context: context,
        dialogTitle: dialogTitle,
        dialogMessage: dialogMessage,
        onDismiss: onDismiss,
      );

  static Future<bool> requestMicrophone({
    BuildContext? context,
    String? dialogTitle,
    String? dialogMessage,
    VoidCallback? onDismiss,
  }) =>
      request(
        AppPermission.microphone,
        context: context,
        dialogTitle: dialogTitle,
        dialogMessage: dialogMessage,
        onDismiss: onDismiss,
      );

  static Future<bool> isGranted(AppPermission type) async {
    return await _toPermission(type).isGranted;
  }

  static Permission _toPermission(AppPermission type) {
    switch (type) {
      case AppPermission.camera:
        return Permission.camera;
      case AppPermission.location:
        return Permission.location;
      case AppPermission.microphone:
        return Permission.microphone;
    }
  }

  static String _defaultTitle(AppPermission type) {
    switch (type) {
      case AppPermission.camera:
        return "Izin Kamera Dibutuhkan";
      case AppPermission.location:
        return "Izin Lokasi Dibutuhkan";
      case AppPermission.microphone:
        return "Izin Mikrofon Dibutuhkan";
    }
  }

  static String _defaultMessage(AppPermission type) {
    switch (type) {
      case AppPermission.camera:
        return "Aplikasi memerlukan akses kamera. "
            "Silakan aktifkan di:\n\n"
            "Pengaturan › Aplikasi › Presensi › Izin › Kamera";
      case AppPermission.location:
        return "Aplikasi memerlukan akses lokasi. "
            "Silakan aktifkan di:\n\n"
            "Pengaturan › Aplikasi › Presensi › Izin › Posisi";
      case AppPermission.microphone:
        return "Aplikasi memerlukan akses mikrofon. "
            "Silakan aktifkan di:\n\n"
            "Pengaturan › Aplikasi › Presensi › Izin › Mikrofon";
    }
  }

  static Future<void> _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) async {
    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDismiss?.call();
            },
            child: const Text("Nanti Saja", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Buka Pengaturan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}