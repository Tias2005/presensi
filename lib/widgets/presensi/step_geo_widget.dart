import 'dart:convert';
// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/theme.dart';
import '../../widgets/app_dialog.dart';
import '../../helpers/permission_helper.dart';

class StepGeoWidget extends StatefulWidget {
  final int modeId;
  final Map<String, dynamic> config;
  final Function(Position) onResult;

  const StepGeoWidget({
    super.key,
    required this.modeId,
    required this.config,
    required this.onResult,
  });

  @override
  State<StepGeoWidget> createState() => _StepGeoWidgetState();
}

class _StepGeoWidgetState extends State<StepGeoWidget> {
  Position? _pos;
  bool _isValid = false;
  double _dist = 0;
  bool _loadingLocation = false;
  LatLng? _targetLocation;

  Future<List<Position>> _collectSamples(
    LocationSettings settings, {
    int count = 4,
    Duration interval = const Duration(milliseconds: 600),
  }) async {
    final samples = <Position>[];
    for (int i = 0; i < count; i++) {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      samples.add(p);
      if (i < count - 1) await Future.delayed(interval);
    }
    return samples;
  }

    String? _detectFakeGps(List<Position> samples) {
      final hasMock = samples.any((p) => p.isMocked);
      if (hasMock) {
        return "Terdeteksi Fake GPS.";
      }

      final badAccuracy = samples.every((p) => p.accuracy > 100);
      if (badAccuracy) {
        return "Sinyal GPS lemah. Pindah ke area terbuka.";
      }

      return null;
    }

  Future<void> _checkLocation() async {
    setState(() => _loadingLocation = true);

    final allowed = await PermissionHelper.requestLocation(context: context);
    if (!allowed) {
      setState(() => _loadingLocation = false);
      return;
    }

    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      );

      final samples = await _collectSamples(locationSettings);

      final fakeReason = _detectFakeGps(samples);
      if (fakeReason != null) {
        if (mounted) {
          setState(() => _loadingLocation = false);
          AppDialog.show(
            context,
            message: "⚠️ Fake GPS Terdeteksi\n\n$fakeReason",
          );
        }
        return;
      }

      final finePosition = samples.reduce(
        (a, b) => a.accuracy <= b.accuracy ? a : b,
      );

      double targetLat;
      double targetLng;
      double limit;

      if (widget.modeId == 1) {
        // WFO — koordinat kantor
        targetLat =
            double.parse(widget.config['latitude_kantor'].toString());
        targetLng =
            double.parse(widget.config['longitude_kantor'].toString());
        limit = double.parse(widget.config['radius_wfo'].toString());
      } else {
        // WFH — koordinat rumah dari user data
        final prefs = await SharedPreferences.getInstance();
        final user = jsonDecode(prefs.getString('user_data') ?? '{}');
        targetLat =
            double.parse(user['latitude_rumah']?.toString() ?? '0');
        targetLng =
            double.parse(user['longitude_rumah']?.toString() ?? '0');
        limit = double.parse(widget.config['radius_wfh'].toString());
      }

      _targetLocation = LatLng(targetLat, targetLng);

      final double d = Geolocator.distanceBetween(
        finePosition.latitude,
        finePosition.longitude,
        targetLat,
        targetLng,
      );

      if (mounted) {
        setState(() {
          _pos = finePosition;
          _dist = d;
          _isValid = widget.modeId == 3 ? true : (d <= limit);
          _loadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingLocation = false);
        AppDialog.show(context, message: "Gagal mendapatkan lokasi: $e");
      }
    }
  }

  double get _radiusLimit => widget.modeId == 1
      ? double.parse(widget.config['radius_wfo'].toString())
      : double.parse(widget.config['radius_wfh'].toString());

  String get _targetLabel => widget.modeId == 1 ? 'Kantor' : 'Rumah';

  String get _buttonLabel {
    if (_pos == null) return "LACAK LOKASI";
    if (widget.modeId == 3) return "LANJUT VERIFIKASI";
    return _isValid ? "LANJUT VERIFIKASI" : "DI LUAR RADIUS";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _pos == null
              ? const Center(
                  child: Text("Klik tombol untuk melacak lokasi"),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter:
                        LatLng(_pos!.latitude, _pos!.longitude),
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.presensi',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(_pos!.latitude, _pos!.longitude),
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                      if (_targetLocation != null)
                        Marker(
                          point: _targetLocation!,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                    ]),
                    if (widget.modeId != 3 && _targetLocation != null)
                      CircleLayer(circles: [
                        CircleMarker(
                          point: _targetLocation!,
                          radius: _radiusLimit,
                          useRadiusInMeter: true,
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderColor: Colors.blue,
                          borderStrokeWidth: 2,
                        ),
                      ]),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            children: [
              if (_pos != null) ...[
                Text(
                  "Jarak ke $_targetLabel: ${_dist.toStringAsFixed(0)} meter",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),

              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loadingLocation
                      ? null
                      : (_pos == null
                          ? _checkLocation
                          : (_isValid
                              ? () => widget.onResult(_pos!)
                              : null)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValid || _pos == null
                        ? AppColors.primary
                        : Colors.grey,
                  ),
                  child: _loadingLocation
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Memverifikasi lokasi...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                            : Text(
                          _buttonLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}