import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'ble_service.dart';

/// Nefes Tekniği Modelleri
enum BreathingPattern {
  box,       // 4-4-4-4 Kutu Nefesi (Donanma/Özel Kuvvetler Stres Azaltma)
  relax478,  // 4-7-8 Derin Rahatlama & Uyku
  resonance, // 5.5 - 5.5 Rezonans & Kalp Koheransı
}

extension BreathingPatternExt on BreathingPattern {
  String get title {
    switch (this) {
      case BreathingPattern.box:
        return 'Kutu Nefesi (4-4-4-4)';
      case BreathingPattern.relax478:
        return '4-7-8 Derin Rahatlama';
      case BreathingPattern.resonance:
        return 'Rezonans Koheransı (5.5s)';
    }
  }

  String get description {
    switch (this) {
      case BreathingPattern.box:
        return 'Odaklanma ve anlık akut stresi hızla yatıştırmak için.';
      case BreathingPattern.relax478:
        return 'Parasempatik sinir sistemini tetikler, derin gevşeme sağlar.';
      case BreathingPattern.resonance:
        return 'Kalp ritmi ile solunumu senkronize eder (Maksimum HRV).';
    }
  }

  int get inhaleSeconds {
    switch (this) {
      case BreathingPattern.box: return 4;
      case BreathingPattern.relax478: return 4;
      case BreathingPattern.resonance: return 5;
    }
  }

  int get hold1Seconds {
    switch (this) {
      case BreathingPattern.box: return 4;
      case BreathingPattern.relax478: return 7;
      case BreathingPattern.resonance: return 0;
    }
  }

  int get exhaleSeconds {
    switch (this) {
      case BreathingPattern.box: return 4;
      case BreathingPattern.relax478: return 8;
      case BreathingPattern.resonance: return 6;
    }
  }

  int get hold2Seconds {
    switch (this) {
      case BreathingPattern.box: return 4;
      case BreathingPattern.relax478: return 0;
      case BreathingPattern.resonance: return 0;
    }
  }

  int get totalCycleSeconds => inhaleSeconds + hold1Seconds + exhaleSeconds + hold2Seconds;
}

/// Nefes Döngüsü Fazı
enum BreathingPhase { inhale, holdIn, exhale, holdOut, ready }

class BiofeedbackService extends ChangeNotifier {
  final PbsBleService ble;

  // Canlı Ölçüm & Stres
  int _currentBpm = 72;
  final List<int> _bpmHistory = [];
  final List<double> _rrIntervals = []; // ms cinsinden yaklaşık R-R aralıkları
  DateTime? _lastBeatTime;

  double _stressScore = 35.0; // 0 (Zen/Sakin) - 100 (Aşırı Stres)
  double _hrvScore = 55.0;     // Tahmini HRV RMSSD (ms)

  // Nefes Seansı Durumu
  bool _isSessionActive = false;
  BreathingPattern _pattern = BreathingPattern.box;
  BreathingPhase _currentPhase = BreathingPhase.ready;
  int _sessionDurationSeconds = 180; // 3 dakika varsayılan
  int _sessionElapsedSeconds = 0;
  int _phaseElapsedSeconds = 0;

  int _startBpm = 0;
  double _startStress = 0.0;

  Timer? _sessionTimer;
  StreamSubscription? _hrSub;

  int get currentBpm => _currentBpm;
  double get stressScore => _stressScore;
  double get hrvScore => _hrvScore;
  bool get isSessionActive => _isSessionActive;
  BreathingPattern get pattern => _pattern;
  BreathingPhase get currentPhase => _currentPhase;
  int get phaseElapsedSeconds => _phaseElapsedSeconds;
  int get currentPhaseSeconds => _getPhaseDurationSeconds(_currentPhase);
  int get phaseRemainingSeconds => math.max(1, currentPhaseSeconds - _phaseElapsedSeconds);
  int get sessionElapsedSeconds => _sessionElapsedSeconds;
  int get sessionDurationSeconds => _sessionDurationSeconds;
  int get startBpm => _startBpm;
  double get startStress => _startStress;

  BiofeedbackService(this.ble) {
    _initHrListener();
  }

  void _initHrListener() {
    _hrSub = ble.heartRateStream.listen((rec) {
      _processHeartBeat(rec.bpm);
    });
    if (ble.lastHeartRate != null) {
      _processHeartBeat(ble.lastHeartRate!.bpm);
    }
  }

  void setPattern(BreathingPattern p) {
    if (_isSessionActive) return;
    _pattern = p;
    notifyListeners();
  }

  void setDuration(int seconds) {
    if (_isSessionActive) return;
    _sessionDurationSeconds = seconds;
    notifyListeners();
  }

  /// Yeni gelen nabız verisini analiz eder ve Stres & HRV skorunu türetir
  void _processHeartBeat(int bpm) {
    if (bpm <= 35 || bpm > 220) return;
    _currentBpm = bpm;
    _bpmHistory.add(bpm);
    if (_bpmHistory.length > 50) _bpmHistory.removeAt(0);

    final now = DateTime.now();
    if (_lastBeatTime != null) {
      final diffMs = now.difference(_lastBeatTime!).inMilliseconds.toDouble();
      final estimatedRr = 60000.0 / bpm;
      final blendedRr = (estimatedRr * 0.7) + (diffMs.clamp(300, 1500) * 0.3);
      _rrIntervals.add(blendedRr);
      if (_rrIntervals.length > 30) _rrIntervals.removeAt(0);
    }
    _lastBeatTime = now;

    _calculateStressAndHrv();
    notifyListeners();
  }

  /// HRV (RMSSD) ve Stres Skoru Matematiksel Modeli
  void _calculateStressAndHrv() {
    if (_rrIntervals.length < 3) {
      final bpmStress = ((_currentBpm - 55) / 50.0).clamp(0.0, 1.0) * 100.0;
      _stressScore = (_stressScore * 0.7) + (bpmStress * 0.3);
      _hrvScore = (100.0 - _stressScore).clamp(20.0, 85.0);
      return;
    }

    double sumSquaredDiffs = 0;
    for (var i = 0; i < _rrIntervals.length - 1; i++) {
      final diff = _rrIntervals[i + 1] - _rrIntervals[i];
      sumSquaredDiffs += diff * diff;
    }
    final rmssd = math.sqrt(sumSquaredDiffs / (_rrIntervals.length - 1));
    _hrvScore = rmssd.clamp(15.0, 110.0);

    final bpmFactor = ((_currentBpm - 60) / 45.0).clamp(0.0, 1.0);
    final hrvFactor = (1.0 - ((_hrvScore - 20) / 70.0)).clamp(0.0, 1.0);

    final rawStress = (bpmFactor * 55.0) + (hrvFactor * 45.0);
    _stressScore = (_stressScore * 0.75) + (rawStress * 0.25).clamp(5.0, 95.0);
  }

  /// Nefes Seansını Başlat
  Future<void> startSession() async {
    if (_isSessionActive) return;
    _isSessionActive = true;
    _sessionElapsedSeconds = 0;
    _phaseElapsedSeconds = 0;
    _startBpm = _currentBpm;
    _startStress = _stressScore;
    _currentPhase = BreathingPhase.inhale;

    if (ble.isConnected) {
      await ble.toggleHeartRate(true);
    }

    HapticFeedback.heavyImpact();
    _triggerWatchVibration();

    _runBreathingLoop();
    notifyListeners();
  }

  void _runBreathingLoop() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isSessionActive) {
        timer.cancel();
        return;
      }
      _sessionElapsedSeconds++;
      _phaseElapsedSeconds++;

      final phaseTotalSec = _getPhaseDurationSeconds(_currentPhase);
      if (_phaseElapsedSeconds >= phaseTotalSec) {
        _phaseElapsedSeconds = 0;
        _advancePhase();
      }

      if (_sessionElapsedSeconds >= _sessionDurationSeconds) {
        stopSession();
        return;
      }
      notifyListeners();
    });
  }

  void _advancePhase() {
    switch (_currentPhase) {
      case BreathingPhase.ready:
      case BreathingPhase.holdOut:
        _currentPhase = BreathingPhase.inhale;
        HapticFeedback.mediumImpact();
        _triggerWatchVibration();
        break;
      case BreathingPhase.inhale:
        if (_pattern.hold1Seconds > 0) {
          _currentPhase = BreathingPhase.holdIn;
          HapticFeedback.lightImpact();
        } else {
          _currentPhase = BreathingPhase.exhale;
          HapticFeedback.mediumImpact();
          _triggerWatchVibration();
        }
        break;
      case BreathingPhase.holdIn:
        _currentPhase = BreathingPhase.exhale;
        HapticFeedback.mediumImpact();
        _triggerWatchVibration();
        break;
      case BreathingPhase.exhale:
        if (_pattern.hold2Seconds > 0) {
          _currentPhase = BreathingPhase.holdOut;
          HapticFeedback.lightImpact();
        } else {
          _currentPhase = BreathingPhase.inhale;
          HapticFeedback.mediumImpact();
          _triggerWatchVibration();
        }
        break;
    }
  }

  int _getPhaseDurationSeconds(BreathingPhase phase) {
    switch (phase) {
      case BreathingPhase.inhale:
        return _pattern.inhaleSeconds;
      case BreathingPhase.holdIn:
        return _pattern.hold1Seconds;
      case BreathingPhase.exhale:
        return _pattern.exhaleSeconds;
      case BreathingPhase.holdOut:
        return _pattern.hold2Seconds;
      case BreathingPhase.ready:
        return 1;
    }
  }

  void _triggerWatchVibration() {
    if (ble.isConnected) {
      ble.vibrateWatch();
    }
  }

  /// Nefes Seansını Durdur
  void stopSession() {
    _isSessionActive = false;
    _currentPhase = BreathingPhase.ready;
    _phaseElapsedSeconds = 0;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    if (ble.isConnected) {
      ble.toggleHeartRate(false);
    }
    HapticFeedback.heavyImpact();
    notifyListeners();
  }

  @override
  void dispose() {
    _hrSub?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }
}
