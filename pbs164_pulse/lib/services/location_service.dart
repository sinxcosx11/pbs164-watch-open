import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class WorkoutSession {
  final List<LatLng> routePoints = [];
  double totalDistanceMeters = 0.0;
  int durationSeconds = 0;
  double currentSpeedKmh = 0.0;
  double averageSpeedKmh = 0.0;
  int currentHeartRate = 0;
  int totalSteps = 0;

  double get distanceKm => totalDistanceMeters / 1000.0;

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  String get paceMinPerKm {
    if (distanceKm <= 0.05) return "--:--";
    final paceSec = (durationSeconds / distanceKm).round();
    final m = paceSec ~/ 60;
    final s = paceSec % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }
}

/// Telefon GPS ve Connected Antrenman Servisi
class PbsLocationService extends ChangeNotifier {
  bool _isTracking = false;
  WorkoutSession? _currentSession;
  StreamSubscription<Position>? _positionSub;
  Timer? _timer;

  bool get isTracking => _isTracking;
  WorkoutSession? get session => _currentSession;

  /// Antrenmanı Başlat
  Future<bool> startWorkout() async {
    final hasPerm = await _checkPermissions();
    if (!hasPerm) return false;

    _isTracking = true;
    _currentSession = WorkoutSession();
    notifyListeners();

    // Saniye sayacı
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_currentSession != null && _isTracking) {
        _currentSession!.durationSeconds++;
        notifyListeners();
      }
    });

    // Canlı GPS Dinleyici
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // 3 metrede bir güncelle
    );

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      if (_currentSession == null) return;

      final newPoint = LatLng(pos.latitude, pos.longitude);
      if (_currentSession!.routePoints.isNotEmpty) {
        final last = _currentSession!.routePoints.last;
        final d = Geolocator.distanceBetween(
          last.latitude, last.longitude,
          newPoint.latitude, newPoint.longitude,
        );
        _currentSession!.totalDistanceMeters += d;
      }
      _currentSession!.routePoints.add(newPoint);
      _currentSession!.currentSpeedKmh = pos.speed * 3.6; // m/s -> km/h
      notifyListeners();
    });

    return true;
  }

  /// Antrenmanı Bitir
  void stopWorkout() {
    _isTracking = false;
    _timer?.cancel();
    _positionSub?.cancel();
    notifyListeners();
  }

  /// Saatten gelen nabız ve adımı oturuma ekle
  void updateHeartRate(int bpm) {
    if (_currentSession != null && _isTracking) {
      _currentSession!.currentHeartRate = bpm;
      notifyListeners();
    }
  }

  void updateSteps(int steps) {
    if (_currentSession != null && _isTracking) {
      _currentSession!.totalSteps = steps;
      notifyListeners();
    }
  }

  Future<bool> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}
