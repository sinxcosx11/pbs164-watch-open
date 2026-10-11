import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../protocol/command_ids.dart';
import '../protocol/pbs164_protocol.dart';
import '../protocol/response_parser.dart';
import '../models/health_models.dart';
import '../models/watch_face_models.dart';
import '../models/watch_features.dart';
import 'storage_service.dart';
import 'watch_ota_service.dart';
import 'native_bridge.dart';

/// PBS 164 Bluetooth Low Energy Bağlantı ve Durum Yöneticisi
/// [PbsBleService.applyDiyFace] sonucu.
class DiyApplyResult {
  final bool ok;
  final String message;
  const DiyApplyResult(this.ok, this.message);
}

class PbsBleService extends ChangeNotifier {
  /// Eşleme (bind) kimliği. Saat kullanıcı verisini (kadran listesi, DIY kadran) bu kimliğe göre
  /// tutuyor görünüyor; farklı kimlikle bağlanmak onları sıfırlayabilir. HryFine ile aynı saatte
  /// birlikte çalışabilmek için, kullanıcının kendi saat bağlantısından yakalanan HryFine
  /// kimliği kullanılır.
  static const String userToken = "0ca66f83";

  final PbsHealthStorageService _storage = PbsHealthStorageService();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  BluetoothCharacteristic? _batteryCharacteristic;

  bool _isScanning = false;
  bool _isConnected = false;
  int _batteryLevel = 100;

  // Anlık Ölçüm Durumları
  bool _isMeasuringHeart = false;
  bool _isMeasuringBp = false;
  bool _isMeasuringSpo2 = false;

  // Sürekli Canlı Tutma Zamanlayıcıları (Keep-Alive Timers)
  Timer? _heartKeepAliveTimer;
  Timer? _bpKeepAliveTimer;
  Timer? _spo2KeepAliveTimer;

  // Son Kayıtlar
  HeartRateRecord? _lastHeartRate;
  BloodPressureRecord? _lastBloodPressure;
  BloodOxygenRecord? _lastBloodOxygen;
  StepRecord? _lastSteps;

  // Saatin özellik tablosu (kadran yetenekleri, çözünürlük, kod formatı)
  WatchFeatures? _features;
  BluetoothCharacteristic? _featureCharacteristic;
  BluetoothCharacteristic? _versionCharacteristic;
  BluetoothCharacteristic? _otaWriteCharacteristic;
  BluetoothCharacteristic? _otaNotifyCharacteristic;
  bool _otaBusy = false;
  bool get isOtaBusy => _otaBusy;

  // Kadran Durumları (Watch Face State)
  WatchFaceListRecord? _watchFaces;
  CustomWatchFaceRecord? _customWatchFace;
  WatchFaceAck? _lastWatchFaceAck;

  // Teşhis ve Ham BLE Paket Logları
  final List<String> _diagnosticLogs = [];
  final List<int> _rxBuffer = [];
  int _expectedRxLen = 0;

  // Akış Kontrolcüleri (Streams)
  final _heartRateController = StreamController<HeartRateRecord>.broadcast();
  final _stepController = StreamController<StepRecord>.broadcast();
  final _bloodPressureController = StreamController<BloodPressureRecord>.broadcast();
  final _bloodOxygenController = StreamController<BloodOxygenRecord>.broadcast();
  final _deviceTriggerController = StreamController<DeviceTriggerType>.broadcast();
  final _watchFaceAckController = StreamController<WatchFaceAck>.broadcast();
  final _bgRequestController = StreamController<WatchFaceBgRequest>.broadcast();

  // Dışa Açık Akışlar
  Stream<HeartRateRecord> get heartRateStream => _heartRateController.stream;
  Stream<StepRecord> get stepStream => _stepController.stream;
  Stream<BloodPressureRecord> get bloodPressureStream => _bloodPressureController.stream;
  Stream<BloodOxygenRecord> get bloodOxygenStream => _bloodOxygenController.stream;
  Stream<DeviceTriggerType> get deviceTriggerStream => _deviceTriggerController.stream;
  Stream<WatchFaceAck> get watchFaceAckStream => _watchFaceAckController.stream;

  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  int get batteryLevel => _batteryLevel;
  BluetoothDevice? get device => _connectedDevice;

  WatchFeatures? get features => _features;
  WatchFaceListRecord? get watchFaces => _watchFaces;
  CustomWatchFaceRecord? get customWatchFace => _customWatchFace;
  WatchFaceAck? get lastWatchFaceAck => _lastWatchFaceAck;
  List<String> get diagnosticLogs => List.unmodifiable(_diagnosticLogs);

  bool get isMeasuringHeart => _isMeasuringHeart;
  bool get isMeasuringBp => _isMeasuringBp;
  bool get isMeasuringSpo2 => _isMeasuringSpo2;

  HeartRateRecord? get lastHeartRate => _lastHeartRate;
  BloodPressureRecord? get lastBloodPressure => _lastBloodPressure;
  BloodOxygenRecord? get lastBloodOxygen => _lastBloodOxygen;
  StepRecord? get lastSteps => _lastSteps;
  PbsHealthStorageService get storage => _storage;

  // Hareketli Ortalama Yumuşatma Filtresi (Moving Average)
  final List<int> _bpmWindow = [];
  bool _enableSmoothing = true;

  bool get enableSmoothing => _enableSmoothing;
  set enableSmoothing(bool val) {
    _enableSmoothing = val;
    notifyListeners();
  }

  int get smoothedBpm {
    if (_bpmWindow.isEmpty) return _lastHeartRate?.bpm ?? 0;
    final sum = _bpmWindow.reduce((a, b) => a + b);
    return (sum / _bpmWindow.length).round();
  }

  StreamSubscription? _scanSub;
  StreamSubscription? _notifySub;

  PbsBleService() {
    _storage.init();
  }

  /// Cihaz Tarama
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}

    try {
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        _addDiagnosticLog("Bluetooth kapalı! Açılması talep ediliyor...");
        await FlutterBluePlus.turnOn();
        await FlutterBluePlus.adapterState
            .where((s) => s == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 3), onTimeout: () => BluetoothAdapterState.off);
      }
    } catch (e) {
      _addDiagnosticLog("Bluetooth durumu kontrol hatası: $e");
    }

    _isScanning = true;
    notifyListeners();

    try {
      // Android 12+ için GPS konumu gerektirmeyen tarama
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );
    } catch (e) {
      _addDiagnosticLog("Tarama (fineLocation:false) uyarısı: $e, fineLocation:true deneniyor...");
      try {
        await FlutterBluePlus.startScan(
          timeout: timeout,
          androidUsesFineLocation: true,
        );
      } catch (e2) {
        _addDiagnosticLog("Tarama başlatma hatası: $e2");
        _isScanning = false;
        notifyListeners();
        return;
      }
    }

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.isScanning.listen((scanning) {
      _isScanning = scanning;
      notifyListeners();
    });
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  /// Saate Bağlan
  Future<bool> connect(BluetoothDevice targetDevice) async {
    try {
      await stopScan();
      _connectedDevice = targetDevice;
      notifyListeners();

      await targetDevice.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 15),
      );

      // Servisleri Keşfet
      final services = await targetDevice.discoverServices();
      for (final service in services) {
        final sUuid = service.uuid.toString().toLowerCase();

        // 1. Nordic UART Servisi
        if (sUuid == PbsGattUuids.uartService.toLowerCase()) {
          for (final char in service.characteristics) {
            final cUuid = char.uuid.toString().toLowerCase();
            if (cUuid == PbsGattUuids.uartWrite.toLowerCase()) {
              _writeCharacteristic = char;
            } else if (cUuid == PbsGattUuids.uartNotify.toLowerCase()) {
              _notifyCharacteristic = char;
              await _setupNotifications(char);
            }
          }
        }

        // 2. Pil Servisi
        if (sUuid == PbsGattUuids.batteryService.toLowerCase() || sUuid.contains("180f")) {
          for (final char in service.characteristics) {
            if (char.uuid.toString().toLowerCase().contains("2a19")) {
              _batteryCharacteristic = char;
              await _readBatteryLevel();
            }
          }
        }

        // 3. Cihaz Bilgisi Servisi: 0x2A28 = özellik tablosu, 0x2A27 = protokol sürümü
        if (sUuid.contains("180a")) {
          for (final char in service.characteristics) {
            final cu = char.uuid.toString().toLowerCase();
            if (cu.contains("2a28")) _featureCharacteristic = char;
            if (cu.contains("2a27")) _versionCharacteristic = char;
          }
        }

        // 4. OTA servisi (0xFF00): arka plan görseli gönderimi için
        if (sUuid == "ff00") {
          for (final char in service.characteristics) {
            final cu = char.uuid.toString().toLowerCase();
            if (cu == "ff02") _otaWriteCharacteristic = char;
            if (cu == "ff01") _otaNotifyCharacteristic = char;
          }
        }

        _addDiagnosticLog("GATT servis: $sUuid -> ${service.characteristics.map((c) => c.uuid.toString().toLowerCase()).join(', ')}");
      }

      if (_writeCharacteristic != null) {
        _isConnected = true;
        notifyListeners();

        // Protokol sürüm baytını saatten oku (HryFine ilk iş bunu yapar).
        await _readProtocolVersion();

        // Bağlantı sonrası ilk el sıkışma:
        await sendPacket(Pbs164Protocol.bindDevice(userToken));
        await Future.delayed(const Duration(milliseconds: 150));

        await sendPacket(Pbs164Protocol.syncTime(DateTime.now()));
        await Future.delayed(const Duration(milliseconds: 150));

        // Özellik tablosunu oku (kadran yetenekleri bunsuz bilinemez)
        await refreshFeatures();
        await Future.delayed(const Duration(milliseconds: 150));

        // Gerçek zamanlı adım akışını aç
        await sendPacket(Pbs164Protocol.setRealtimeSteps(enabled: true));
        await Future.delayed(const Duration(milliseconds: 150));

        await sendPacket(Pbs164Protocol.queryTodaySummary());
        await Future.delayed(const Duration(milliseconds: 150));

        // Kadran bilgilerini otomatik sorgula
        await queryWatchFaces();
        await Future.delayed(const Duration(milliseconds: 150));
        await queryCustomWatchFace();

        return true;
      }

      return false;
    } catch (e) {
      debugPrint("BLE Bağlantı Hatası: $e");
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  /// Bağlantıyı Kes
  Future<void> disconnect() async {
    _stopAllKeepAlives();
    _notifySub?.cancel();
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }
    _isConnected = false;
    _connectedDevice = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _rxBuffer.clear();
    notifyListeners();
  }

  void _stopAllKeepAlives() {
    _heartKeepAliveTimer?.cancel();
    _bpKeepAliveTimer?.cancel();
    _spo2KeepAliveTimer?.cancel();
    _isMeasuringHeart = false;
    _isMeasuringBp = false;
    _isMeasuringSpo2 = false;
  }

  void _addDiagnosticLog(String entry) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}";
    debugPrint("PBSLOG $entry");
    _diagnosticLogs.insert(0, "[$timeStr] $entry");
    if (_diagnosticLogs.length > 80) {
      _diagnosticLogs.removeLast();
    }
    notifyListeners();
  }

  void clearDiagnosticLogs() {
    _diagnosticLogs.clear();
    notifyListeners();
  }

  /// Saatten Gelen Bildirimleri Dinleme (RX)
  Future<void> _setupNotifications(BluetoothCharacteristic char) async {
    await char.setNotifyValue(true);
    _notifySub?.cancel();
    _notifySub = char.lastValueStream.listen((data) {
      if (data.isEmpty) return;
      _handleIncomingBytes(Uint8List.fromList(data));
    });
  }

  void _handleIncomingBytes(Uint8List chunk) {
    final hex = chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    debugPrint("BLE RX RAW [${chunk.length}B]: $hex");
    _addDiagnosticLog("RX [${chunk.length}B]: $hex");

    if (_rxBuffer.isEmpty) {
      if (chunk[0] == PbsCommandIds.ackResponseHeader) {
        _dispatchParsedPacket(chunk);
        return;
      }

      if (chunk[0] == PbsCommandIds.ackHeader) {
        _rxBuffer.addAll(chunk);
        if (chunk.length >= 3) {
          _expectedRxLen = ((chunk[1] << 8) | chunk[2]) + 4;
        } else {
          _expectedRxLen = chunk.length;
        }

        if (_rxBuffer.length >= _expectedRxLen) {
          final fullPacket = Uint8List.fromList(_rxBuffer);
          _rxBuffer.clear();
          _dispatchParsedPacket(fullPacket);
        }
        return;
      }

      _dispatchParsedPacket(chunk);
    } else {
      _rxBuffer.addAll(chunk);
      if (_rxBuffer.length >= _expectedRxLen) {
        final fullPacket = Uint8List.fromList(_rxBuffer);
        _rxBuffer.clear();
        _dispatchParsedPacket(fullPacket);
      }
    }
  }

  void _dispatchParsedPacket(Uint8List packet) {
    // 0xDF veri paketine saat için ACK onayı yanıtla (HryFine protokol kuralı)
    if (packet[0] == PbsCommandIds.ackHeader && packet.length >= 7) {
      final cmdId = packet[4];
      final subCmdId = packet[6];
      sendPacket(Pbs164Protocol.configAck(cmdId, subCmdId, 1));
    }

    final parsed = PbsResponseParser.parsePacket(
      packet,
      is8Bytes: _features?.is8Bytes ?? false,
      resolutionRatio: _features?.resolutionRatio ?? 0,
    );
    if (parsed == null) return;

    if (parsed is WatchFeatures) {
      _applyFeatures(parsed, source: "0x19");
    } else if (parsed is WatchFaceListRecord) {
      _watchFaces = parsed;
      _addDiagnosticLog(
          "Kadran Listesi Geldi: ${parsed.dialCount} adet (Aktif: ${parsed.activeCodeHex}, Yüklü: ${parsed.installedCodesHex})");
      notifyListeners();
    } else if (parsed is CustomWatchFaceRecord) {
      _customWatchFace = parsed;
      _addDiagnosticLog(
          "Özel Kadran Detayı: Kod=${parsed.faceCodeHex}, X=${parsed.timeX}, Y=${parsed.timeY}, Renk=0x${parsed.colorRgb565.toRadixString(16)}");
      notifyListeners();
    } else if (parsed is WatchFaceBgRequest) {
      _bgRequestController.add(parsed);
      _addDiagnosticLog("Saat arka plan istiyor (0x0F/0x06)");
    } else if (parsed is WatchFaceAck) {
      _lastWatchFaceAck = parsed;
      _watchFaceAckController.add(parsed);
      _addDiagnosticLog(
          "Saat Kadran Onayı (ACK): Cmd=${parsed.cmdId}, Sub=${parsed.subCmdId}, Durum=${parsed.success ? 'BAŞARILI' : 'BAŞARISIZ'}");
      notifyListeners();
    } else if (parsed is HeartRateRecord) {
      _bpmWindow.add(parsed.bpm);
      if (_bpmWindow.length > 5) _bpmWindow.removeAt(0);

      final activeRecord = _enableSmoothing
          ? HeartRateRecord(bpm: smoothedBpm, timestamp: parsed.timestamp)
          : parsed;

      _lastHeartRate = activeRecord;
      _heartRateController.add(activeRecord);
      _storage.addHeartRate(activeRecord);
      notifyListeners();
    } else if (parsed is StepRecord) {
      _lastSteps = parsed;
      _stepController.add(parsed);
      notifyListeners();
    } else if (parsed is BloodPressureRecord) {
      _lastBloodPressure = parsed;
      _bloodPressureController.add(parsed);
      _storage.addBloodPressure(parsed);
      notifyListeners();
    } else if (parsed is BloodOxygenRecord) {
      _lastBloodOxygen = parsed;
      _bloodOxygenController.add(parsed);
      _storage.addBloodOxygen(parsed);
      notifyListeners();
    } else if (parsed is DeviceTriggerType) {
      _deviceTriggerController.add(parsed);
      if (parsed == DeviceTriggerType.findPhone) {
        PbsNativeBridge.ringPhone();
      }
    }
  }

  /// Pil Seviyesi Okuma
  Future<void> _readBatteryLevel() async {
    if (_batteryCharacteristic != null) {
      try {
        final val = await _batteryCharacteristic!.read();
        if (val.isNotEmpty) {
          _batteryLevel = val[0];
          notifyListeners();
        }
      } catch (e) {
        debugPrint("Pil okuma hatası: $e");
      }
    }
  }

  /// Ham BLE Paketi Gönderme (TX)
  Future<void> sendPacket(Uint8List packet) async {
    if (_writeCharacteristic == null || !_isConnected || _otaBusy) return;

    try {
      final hex = packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      debugPrint("BLE TX [${packet.length}B]: $hex");
      _addDiagnosticLog("TX [${packet.length}B]: $hex");

      final chunks = Pbs164Protocol.chunkPacket(packet);
      for (final chunk in chunks) {
        await _writeCharacteristic!.write(chunk, withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 15));
      }
    } catch (e) {
      debugPrint("Paket gönderme hatası: $e");
      _addDiagnosticLog("TX HATA: $e");
    }
  }

  // ==========================================
  // HIZLI EYLEM VE KESİNTİSİZ BİYOMETRİK ÖLÇÜM
  // ==========================================

  Future<void> vibrate() async {
    await sendPacket(Pbs164Protocol.vibrateWatch(on: true));
  }

  Future<void> syncTimeNow() async {
    await sendPacket(Pbs164Protocol.syncTime(DateTime.now()));
  }

  Future<void> triggerCamera() async {
    await sendPacket(Pbs164Protocol.triggerCamera(on: true));
  }

  /// Nabız Sensörü Ölçümü Başlat / Durdur (Kullanıcı durdurana kadar kesintisiz canlı akış)
  Future<void> toggleHeartRate([bool? enable]) async {
    final nextState = enable ?? !_isMeasuringHeart;
    _isMeasuringHeart = nextState;
    _heartKeepAliveTimer?.cancel();
    notifyListeners();

    if (nextState) {
      // 1. İlk başlatma komutu
      await sendPacket(Pbs164Protocol.setHeartRateSensor(enabled: true));
      // 2. Saatin 20 saniye sonra uykuya geçmesini önlemek için her 12 saniyede bir can simidi pinglemesi
      _heartKeepAliveTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
        if (!_isMeasuringHeart || !_isConnected) {
          timer.cancel();
          return;
        }
        sendPacket(Pbs164Protocol.setHeartRateSensor(enabled: true));
      });
    } else {
      await sendPacket(Pbs164Protocol.setHeartRateSensor(enabled: false));
    }
  }

  /// Tansiyon Ölçümü Başlat / Durdur (Kullanıcı durdurana kadar canlı mod)
  Future<void> toggleBloodPressure([bool? enable]) async {
    final nextState = enable ?? !_isMeasuringBp;
    _isMeasuringBp = nextState;
    _bpKeepAliveTimer?.cancel();
    notifyListeners();

    if (nextState) {
      await sendPacket(Pbs164Protocol.setBloodPressureSensor(enabled: true));
      _bpKeepAliveTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (!_isMeasuringBp || !_isConnected) {
          timer.cancel();
          return;
        }
        sendPacket(Pbs164Protocol.setBloodPressureSensor(enabled: true));
      });
    } else {
      await sendPacket(Pbs164Protocol.setBloodPressureSensor(enabled: false));
    }
  }

  /// Kandaki Oksijen (SpO2) Ölçümü Başlat / Durdur (Kullanıcı durdurana kadar canlı mod)
  Future<void> toggleBloodOxygen([bool? enable]) async {
    final nextState = enable ?? !_isMeasuringSpo2;
    _isMeasuringSpo2 = nextState;
    _spo2KeepAliveTimer?.cancel();
    notifyListeners();

    if (nextState) {
      await sendPacket(Pbs164Protocol.setBloodOxygenSensor(enabled: true));
      _spo2KeepAliveTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (!_isMeasuringSpo2 || !_isConnected) {
          timer.cancel();
          return;
        }
        sendPacket(Pbs164Protocol.setBloodOxygenSensor(enabled: true));
      });
    } else {
      await sendPacket(Pbs164Protocol.setBloodOxygenSensor(enabled: false));
    }
  }

  /// Tüm Adım, Kalori ve Geçmiş Verilerini Yenile
  Future<void> refreshAllData() async {
    if (!_isConnected) return;
    await _readBatteryLevel();
    await sendPacket(Pbs164Protocol.setRealtimeSteps(enabled: true));
    await Future.delayed(const Duration(milliseconds: 100));
    await sendPacket(Pbs164Protocol.queryTodaySummary());
    await Future.delayed(const Duration(milliseconds: 100));
    await sendPacket(Pbs164Protocol.queryAllHistory());
  }

  Future<void> pushNotification(String title, String body) async {
    await sendPacket(Pbs164Protocol.pushNotification(title: title, body: body));
  }

  /// Saati Titret (Find Watch)
  Future<void> vibrateWatch({bool on = true}) async {
    await sendPacket(Pbs164Protocol.vibrateWatch(on: on));
  }

  /// Bilek Hareketiyle Ekran Açma
  Future<void> setRaiseToWake(bool enabled, {int startHour = 8, int startMinute = 0, int endHour = 22, int endMinute = 0}) async {
    await sendPacket(Pbs164Protocol.setRaiseToWake(
      enabled: enabled,
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
    ));
  }

  /// Saate Alarm Kur
  Future<void> setAlarmClock({required int hour, required int minute, int repeatMask = 127}) async {
    await sendPacket(Pbs164Protocol.setAlarmClock(hour: hour, minute: minute, repeatMask: repeatMask));
  }

  /// Hareketsizlik Uyarısı
  Future<void> setSedentaryReminder(bool enabled, {int intervalMinutes = 60}) async {
    await sendPacket(Pbs164Protocol.setSedentaryReminder(enabled: enabled, intervalMinutes: intervalMinutes));
  }

  /// Su İçme Hatırlatıcısı
  Future<void> setDrinkWaterReminder(bool enabled, {int intervalMinutes = 60}) async {
    await sendPacket(Pbs164Protocol.setDrinkWaterReminder(enabled: enabled, intervalMinutes: intervalMinutes));
  }

  /// Rahatsız Etme Modu
  Future<void> setDoNotDisturb(bool enabled, {int startHour = 23, int endHour = 7}) async {
    await sendPacket(Pbs164Protocol.setDoNotDisturb(enabled: enabled, startHour: startHour, endHour: endHour));
  }

  /// Takış Kolu Ayarı (Sol / Sağ)
  Future<void> setWearingHand(bool leftHand) async {
    await sendPacket(Pbs164Protocol.setWearingHand(leftHand: leftHand));
  }

  /// 12/24 Saat Formatı
  Future<void> setHourFormat(bool is24Hour) async {
    await sendPacket(Pbs164Protocol.setHourFormat(is24Hour: is24Hour));
  }

  /// Hava Durumu Gönderme
  Future<void> pushWeather({required int currentTemp, required int minTemp, required int maxTemp, String city = "Istanbul"}) async {
    await sendPacket(Pbs164Protocol.setWeather(currentTemp: currentTemp, minTemp: minTemp, maxTemp: maxTemp, city: city));
  }

  // ==========================================
  // KADRAN YÖNETİMİ (WATCH FACE COMMANDS)
  // ==========================================

  Future<void> _readProtocolVersion() async {
    Pbs164Protocol.protocolVersion = PbsCommandIds.protocolVersion;
    final char = _versionCharacteristic;
    if (char == null) {
      _addDiagnosticLog("0x2A27 bulunamadı, protokol sürümü varsayılan: ${Pbs164Protocol.protocolVersion}");
      return;
    }
    try {
      final data = await char.read();
      final text = String.fromCharCodes(data);
      Pbs164Protocol.protocolVersion = Pbs164Protocol.versionFromRevisionString(text);
      _addDiagnosticLog("0x2A27='$text' -> protokol sürümü 0x${Pbs164Protocol.protocolVersion.toRadixString(16)}");
    } catch (e) {
      _addDiagnosticLog("0x2A27 okuma hatası: $e");
    }
  }

  /// Özellik tablosunu hem 0x19 komutuyla hem de 0x2A28 okumasıyla alır.
  Future<void> refreshFeatures() async {
    await sendPacket(Pbs164Protocol.queryFeatures());
    final char = _featureCharacteristic;
    if (char == null) return;
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      final data = await char.read();
      _applyFeatures(WatchFeatures.parse(data), source: "2A28");
    } catch (e) {
      _addDiagnosticLog("2A28 okuma hatası: $e");
    }
  }

  void _applyFeatures(WatchFeatures f, {required String source}) {
    _features = f;
    _addDiagnosticLog("ÖZELLİK ($source) [${f.raw.length}B]: ${f.hex}");
    _addDiagnosticLog(f.summary().replaceAll('\n', ' | '));
    notifyListeners();
  }

  /// Saatteki Tüm Yüklü Kadranları Sorgula (0x0F, 0x01)
  Future<void> queryWatchFaces() async {
    await sendPacket(Pbs164Protocol.queryWatchFaces());
  }

  /// Saatteki Özel Kadran Parametrelerini Sorgula (0x0F, 0x04)
  Future<void> queryCustomWatchFace() async {
    await sendPacket(Pbs164Protocol.queryCustomWatchFace());
  }

  /// Dahili Kadran Değiştir (0x0F, 0x03)
  Future<void> switchInternalWatchFace(List<int> faceCode) async {
    await sendPacket(Pbs164Protocol.switchInternalWatchFace(faceCode));
  }

  /// Saatin DIY (özel) kadran kaydını (0x0F/0x04) okur ve yanıtını bekler.
  Future<CustomWatchFaceRecord?> readCustomWatchFace({Duration timeout = const Duration(seconds: 4)}) async {
    _customWatchFace = null;
    await queryCustomWatchFace();
    final deadline = DateTime.now().add(timeout);
    while (_customWatchFace == null && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return _customWatchFace;
  }

  /// DIY kadranı uygular (HryFine `WatchFaceEditActivity` akışı):
  ///  1) saatin bildirdiği kadran kodunu oku
  ///  2) 0x0F/0x05 ile metin parametrelerini yaz (yeni arka plan varsa bgUpdate=1)
  ///  3) saat 0x0F/0x06 ile isterse, PAR arka planı OTA servisiyle gönder
  /// [par]: PAR biçimli yeni arka plan; null ise arka plan değişmez.
  /// [defaultBackground]: true ise saatin dahili arka planına dön (bgUpdate=2).
  Future<DiyApplyResult> applyDiyFace({
    required int timeX,
    required int timeY,
    required int colorRgb565,
    required int aboveWidget,
    required int belowWidget,
    Uint8List? par,
    bool defaultBackground = false,
    void Function(String stage, double progress)? onProgress,
  }) async {
    if (!_isConnected) return const DiyApplyResult(false, "Saat bağlı değil");
    if (_otaBusy) return const DiyApplyResult(false, "Başka bir gönderim sürüyor");

    onProgress?.call("Kadran bilgisi okunuyor", 0);
    final record = await readCustomWatchFace();
    if (record == null) return const DiyApplyResult(false, "Saatten özel kadran kaydı okunamadı");

    final int bgUpdate;
    if (par != null) {
      bgUpdate = 1;
    } else if (defaultBackground) {
      bgUpdate = 2;
    } else {
      bgUpdate = record.bgUpdate == 1 ? 2 : record.bgUpdate;
    }

    // Yanıtları göndermeden önce dinlemeye başla (saat 0x0F/0x06'yı ACK'ten önce yollayabilir)
    final ackFuture = _watchFaceAckController.stream
        .firstWhere((a) => a.cmdId == PbsCommandIds.cmdWatchFace && a.subCmdId == 5)
        .timeout(const Duration(seconds: 6));
    final bgFuture = _bgRequestController.stream.first.timeout(const Duration(seconds: 10));
    // Kullanılmayan future'ların işlenmeyen hata üretmemesi için
    ackFuture.ignore();
    bgFuture.ignore();

    onProgress?.call("Kadran ayarları gönderiliyor", 0.02);
    await sendPacket(Pbs164Protocol.setCustomWatchFace(
      faceCode: record.faceCodeBytes,
      timeX: timeX,
      timeY: timeY,
      colorRgb565: colorRgb565,
      aboveWidget: aboveWidget,
      belowWidget: belowWidget,
      bgUpdate: bgUpdate,
    ));

    try {
      final ack = await ackFuture;
      if (!ack.success) return const DiyApplyResult(false, "Saat kadran ayarını reddetti");
    } on TimeoutException {
      return const DiyApplyResult(false, "Saat kadran ayarını onaylamadı");
    }

    if (par != null) {
      final writeChar = _otaWriteCharacteristic;
      final notifyChar = _otaNotifyCharacteristic;
      final dev = _connectedDevice;
      if (writeChar == null || notifyChar == null || dev == null) {
        return const DiyApplyResult(false, "Saatin OTA servisi (0xFF00) bulunamadı");
      }
      try {
        onProgress?.call("Saatin arka plan isteği bekleniyor", 0.05);
        await bgFuture;
      } on TimeoutException {
        return const DiyApplyResult(false, "Saat arka plan göndermemizi istemedi (0x0F/0x06 gelmedi)");
      }

      // HryFine bu noktada birkaç sn bekleyip OTA'ya geçiyor
      await Future.delayed(const Duration(seconds: 1));
      final ota = WatchOtaService(
        device: dev,
        writeChar: writeChar,
        notifyChar: notifyChar,
        log: _addDiagnosticLog,
      );
      try {
        await ota.push(
          data: par,
          prepare: () async {
            _otaBusy = true;
            notifyListeners();
            await _notifyCharacteristic?.setNotifyValue(false);
            await Future.delayed(const Duration(seconds: 1));
          },
          restore: () async {
            await Future.delayed(const Duration(milliseconds: 500));
            try {
              await _notifyCharacteristic?.setNotifyValue(true);
            } catch (e) {
              _addDiagnosticLog("UART bildirimi yeniden açılamadı: $e");
            }
            await Future.delayed(const Duration(seconds: 1));
            _otaBusy = false;
            notifyListeners();
          },
          onProgress: (p) => onProgress?.call("Arka plan gönderiliyor", 0.1 + 0.88 * p),
        );
      } catch (e) {
        _otaBusy = false;
        notifyListeners();
        return DiyApplyResult(false, "Arka plan gönderimi başarısız: $e");
      }
    }

    // Saatin son durumunu yeniden oku
    await Future.delayed(const Duration(milliseconds: 800));
    await queryWatchFaces();
    await Future.delayed(const Duration(milliseconds: 300));
    await readCustomWatchFace();
    onProgress?.call("Tamamlandı", 1);
    return const DiyApplyResult(true, "Kadran saate uygulandı");
  }

  /// Tam kadran dosyasını (WF biçimi) OTA ile saate gönderir (HryFine "çevrimiçi kadran" yolu:
  /// `cmd=5, sub=1`). Dosyanın başlığındaki kimlik, kadranın kodunu belirler; saat gönderilen kadrana
  /// itme slotuna (listede 6. sıra) yazıp hemen aktif eder.
  Future<DiyApplyResult> pushDialFile(
    Uint8List file, {
    void Function(String stage, double progress)? onProgress,
  }) async {
    if (!_isConnected) return const DiyApplyResult(false, "Saat bağlı değil");
    if (_otaBusy) return const DiyApplyResult(false, "Başka bir gönderim sürüyor");
    final writeChar = _otaWriteCharacteristic;
    final notifyChar = _otaNotifyCharacteristic;
    final dev = _connectedDevice;
    if (writeChar == null || notifyChar == null || dev == null) {
      return const DiyApplyResult(false, "Saatin OTA servisi (0xFF00) bulunamadı");
    }
    final ota = WatchOtaService(device: dev, writeChar: writeChar, notifyChar: notifyChar, log: _addDiagnosticLog);
    try {
      await ota.push(
        data: file,
        cmd: 5,
        sub: 1,
        prepare: () async {
          _otaBusy = true;
          notifyListeners();
          await _notifyCharacteristic?.setNotifyValue(false);
          await Future.delayed(const Duration(seconds: 1));
        },
        restore: () async {
          await Future.delayed(const Duration(milliseconds: 500));
          try {
            await _notifyCharacteristic?.setNotifyValue(true);
          } catch (e) {
            _addDiagnosticLog("UART bildirimi yeniden açılamadı: $e");
          }
          await Future.delayed(const Duration(seconds: 1));
          _otaBusy = false;
          notifyListeners();
        },
        onProgress: (p) => onProgress?.call("Kadran gönderiliyor", p),
      );
    } catch (e) {
      _otaBusy = false;
      notifyListeners();
      return DiyApplyResult(false, "Kadran gönderimi başarısız: $e");
    }
    await Future.delayed(const Duration(milliseconds: 1500));
    await queryWatchFaces();
    return const DiyApplyResult(true, "Kadran gönderildi");
  }

  @override
  void dispose() {
    _stopAllKeepAlives();
    _scanSub?.cancel();
    _notifySub?.cancel();
    _heartRateController.close();
    _stepController.close();
    _bloodPressureController.close();
    _bloodOxygenController.close();
    _deviceTriggerController.close();
    _watchFaceAckController.close();
    _bgRequestController.close();
    super.dispose();
  }
}
