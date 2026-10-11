/// Sağlık ve Telemetri Veri Modelleri

class HeartRateRecord {
  final int bpm;
  final DateTime timestamp;

  HeartRateRecord({required this.bpm, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  String get zone {
    if (bpm < 100) return "Dinlenme / Isınma";
    if (bpm < 130) return "Yağ Yakımı";
    if (bpm < 160) return "Kardiyo";
    return "Maksimum / Zirve";
  }
}

class BloodPressureRecord {
  final int systolic;  // Büyük tansiyon (örn: 120)
  final int diastolic; // Küçük tansiyon (örn: 80)
  final DateTime timestamp;

  BloodPressureRecord({
    required this.systolic,
    required this.diastolic,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class BloodOxygenRecord {
  final int percentage; // SpO2 (%)
  final DateTime timestamp;

  BloodOxygenRecord({required this.percentage, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class TemperatureRecord {
  final double celsius;
  final DateTime timestamp;

  TemperatureRecord({required this.celsius, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class StepRecord {
  final int steps;
  final double calories; // kcal
  final double distanceMeters;
  final DateTime timestamp;

  StepRecord({
    required this.steps,
    required this.calories,
    required this.distanceMeters,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get distanceKm => distanceMeters / 1000.0;
}

class SleepRecord {
  final int totalMinutes;
  final int deepMinutes;
  final int lightMinutes;
  final DateTime date;

  SleepRecord({
    required this.totalMinutes,
    required this.deepMinutes,
    required this.lightMinutes,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  String get formattedDuration {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return "${h}s ${m}dk";
  }
}

enum DeviceTriggerType {
  findPhone,      // Saatte "Telefonu Bul"a basıldı
  cameraShutter,  // Saatte kamera ikonuna dokunuldu
  touchWake,
}
