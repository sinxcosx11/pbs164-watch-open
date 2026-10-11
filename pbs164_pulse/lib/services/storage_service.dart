import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/health_models.dart';

/// Ölçüm Kaydı Modeli
class HealthRecordEntry {
  final String id;
  final String type; // 'heart', 'bp', 'spo2'
  final DateTime timestamp;
  final Map<String, dynamic> data;

  HealthRecordEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'data': data,
  };

  factory HealthRecordEntry.fromJson(Map<String, dynamic> json) => HealthRecordEntry(
    id: json['id'] as String,
    type: json['type'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    data: Map<String, dynamic>.from(json['data'] as Map),
  );
}

/// Kalıcı Yerel Sağlık Veritabanı Servisi (Offline JSON Storage)
class PbsHealthStorageService extends ChangeNotifier {
  static final PbsHealthStorageService _instance = PbsHealthStorageService._internal();
  factory PbsHealthStorageService() => _instance;
  PbsHealthStorageService._internal();

  final List<HealthRecordEntry> _records = [];
  bool _isLoaded = false;

  List<HealthRecordEntry> get allRecords => List.unmodifiable(_records);
  bool get isLoaded => _isLoaded;

  File get _storageFile {
    const androidPath = '/data/data/com.pbs164.pbs164_pulse/files/health_records.json';
    return File(androidPath);
  }

  /// Veritabanını Başlat ve Diskten Yükle
  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final file = _storageFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List decoded = jsonDecode(content);
          _records.clear();
          for (final item in decoded) {
            _records.add(HealthRecordEntry.fromJson(item));
          }
          // En yeni kayıt en başta
          _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }
      }
    } catch (e) {
      debugPrint("Sağlık veritabanı okuma hatası: $e");
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Diske Asenkron Kaydet
  Future<void> _persist() async {
    try {
      final file = _storageFile;
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      final jsonStr = jsonEncode(_records.map((r) => r.toJson()).toList());
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint("Sağlık veritabanı yazma hatası: $e");
    }
  }

  /// Yeni Nabız Kaydı Ekle
  Future<void> addHeartRate(HeartRateRecord record) async {
    // Son 3 saniye içinde aynı nabız kaydedildiyse tekrar etme (spam önleyici)
    if (_records.isNotEmpty &&
        _records.first.type == 'heart' &&
        _records.first.data['bpm'] == record.bpm &&
        DateTime.now().difference(_records.first.timestamp).inSeconds < 5) {
      return;
    }

    final entry = HealthRecordEntry(
      id: "hr_${DateTime.now().millisecondsSinceEpoch}",
      type: 'heart',
      timestamp: record.timestamp,
      data: {'bpm': record.bpm, 'zone': record.zone},
    );

    _records.insert(0, entry);
    notifyListeners();
    await _persist();
  }

  /// Yeni Tansiyon Kaydı Ekle
  Future<void> addBloodPressure(BloodPressureRecord record) async {
    final entry = HealthRecordEntry(
      id: "bp_${DateTime.now().millisecondsSinceEpoch}",
      type: 'bp',
      timestamp: record.timestamp,
      data: {
        'systolic': record.systolic,
        'diastolic': record.diastolic,
      },
    );

    _records.insert(0, entry);
    notifyListeners();
    await _persist();
  }

  /// Yeni Kandaki Oksijen Kaydı Ekle
  Future<void> addBloodOxygen(BloodOxygenRecord record) async {
    final entry = HealthRecordEntry(
      id: "spo2_${DateTime.now().millisecondsSinceEpoch}",
      type: 'spo2',
      timestamp: record.timestamp,
      data: {
        'percentage': record.percentage,
      },
    );

    _records.insert(0, entry);
    notifyListeners();
    await _persist();
  }

  /// Türüne Göre Kayıtları Çek
  List<HealthRecordEntry> getRecordsByType(String type) {
    return _records.where((r) => r.type == type).toList();
  }

  /// Bugünkü Kayıtları Çek
  List<HealthRecordEntry> getTodayRecords() {
    final now = DateTime.now();
    return _records.where((r) =>
      r.timestamp.year == now.year &&
      r.timestamp.month == now.month &&
      r.timestamp.day == now.day
    ).toList();
  }

  /// Kaydı Sil
  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
    await _persist();
  }

  /// Tüm Geçmişi Sıfırla
  Future<void> clearAll() async {
    _records.clear();
    notifyListeners();
    await _persist();
  }

  /// Tüm Sağlık Verilerini CSV Formatında İndirilenler Klasörüne Dışa Aktar
  Future<String> exportCsv() async {
    final sb = StringBuffer();
    sb.writeln("ID,Tur,Zaman,BPM,Buyuk_Tansiyon,Kucuk_Tansiyon,SpO2_Yuzde,Bolge");
    for (final r in _records) {
      final id = r.id;
      final type = r.type;
      final time = r.timestamp.toIso8601String();
      final bpm = r.data['bpm'] ?? '';
      final sys = r.data['systolic'] ?? '';
      final dia = r.data['diastolic'] ?? '';
      final spo2 = r.data['percentage'] ?? '';
      final zone = r.data['zone'] ?? '';
      sb.writeln("$id,$type,$time,$bpm,$sys,$dia,$spo2,$zone");
    }

    final downloadDir = Directory('/storage/emulated/0/Download');
    File targetFile;
    if (await downloadDir.exists()) {
      targetFile = File("${downloadDir.path}/PBS164_Saglik_Raporu_${DateTime.now().millisecondsSinceEpoch}.csv");
    } else {
      targetFile = File("${_storageFile.parent.path}/PBS164_Saglik_Raporu_${DateTime.now().millisecondsSinceEpoch}.csv");
    }
    await targetFile.writeAsString(sb.toString());
    return targetFile.path;
  }
}
