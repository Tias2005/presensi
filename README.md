# Presensi Mobile

Aplikasi mobile presensi karyawan berbasis Flutter yang memanfaatkan Face Recognition, Liveness Detection, dan Geolocation sebagai validasi kehadiran. Aplikasi ini merupakan bagian dari sistem presensi karyawan pada penelitian tugas akhir.

## Fitur

- Login pengguna
- Registrasi wajah menggunakan Face Recognition
- Liveness Detection (blink, smile, head movement)
- Presensi Check In & Check Out
- Validasi lokasi menggunakan Geolocation
- Riwayat presensi
- Kalender presensi
- Notifikasi menggunakan Firebase Cloud Messaging (FCM)

## Teknologi

- Flutter
- Dart
- Laravel REST API
- Google ML Kit Face Detection
- TensorFlow Lite (MobileFaceNet)
- Firebase Cloud Messaging
- Flutter Map
- Geolocator
- Shared Preferences

## Instalasi

Clone repository

```bash
git clone https://github.com/Tias2005/presensi.git
cd presensi
```

Install dependency

```bash
flutter pub get
```

Jalankan aplikasi

```bash
flutter run
```

## Struktur Proyek

```
lib/
assets/
├── models/
├── logo/
android/
ios/
```

## Catatan

Aplikasi ini membutuhkan backend Laravel sebagai REST API serta konfigurasi Firebase untuk fitur push notification.