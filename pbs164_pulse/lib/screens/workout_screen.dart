import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/ble_service.dart';
import '../services/location_service.dart';
import '../core/theme.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<PbsLocationService>();
    final ble = context.watch<PbsBleService>();
    final session = loc.session;

    // Harita merkez noktası
    final center = (session != null && session.routePoints.isNotEmpty)
        ? session.routePoints.last
        : const LatLng(41.0082, 28.9784); // İstanbul varsayılan

    return Scaffold(
      appBar: AppBar(
        title: const Text("AÇIK HAVA ANTRENMANI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: Stack(
        children: [
          // 1. Canlı Açık Kaynak Harita (OpenStreetMap)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pbs164.pbs164_pulse',
              ),
              // Rota Çizgisi
              if (session != null && session.routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: session.routePoints,
                      color: PbsTheme.cyan,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              // Mevcut Konum İşaretçisi
              if (session != null && session.routePoints.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: session.routePoints.last,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: PbsTheme.neonPink,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(color: PbsTheme.neonPink.withOpacity(0.5), blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. Üst Bilgi Kartı (HUD Overlay)
          if (loc.isTracking && session != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: PbsTheme.bgDark.withOpacity(0.92),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHudItem("SÜRE", session.formattedDuration),
                      _buildHudItem("MESAFE", "${session.distanceKm.toStringAsFixed(2)} km"),
                      _buildHudItem("TEMPO", "${session.paceMinPerKm}/km"),
                      _buildHudItem("NABIZ", session.currentHeartRate > 0 ? "${session.currentHeartRate} BPM" : "--", color: PbsTheme.neonPink),
                    ],
                  ),
                ),
              ),
            ),

          // 3. Alt Başlat/Durdur Butonu
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: loc.isTracking ? PbsTheme.neonPink : PbsTheme.neonGreen,
                  foregroundColor: const Color(0xFF090D16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 8,
                ),
                icon: Icon(loc.isTracking ? Icons.stop : Icons.play_arrow, size: 28),
                label: Text(
                  loc.isTracking ? "Antrenmanı Bitir" : "Koşuyu / Yürüyüşü Başlat",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                onPressed: () async {
                  if (loc.isTracking) {
                    loc.stopWorkout();
                    if (ble.isConnected) ble.toggleHeartRate(false);
                  } else {
                    final ok = await loc.startWorkout();
                    if (ok && ble.isConnected) {
                      ble.toggleHeartRate(true);
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudItem(String label, String value, {Color color = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
