import 'dart:convert';
import 'dart:typed_data';
import 'command_ids.dart';

/// Polosmart PBS 164 BLE Protokol Motoru
/// HryFine'ın `IssuedUtil.java`, `SettingIssuedUtils.java` ve `NotifyWriteUtils.java`
/// sınıflarının saf Dart portudur.
class Pbs164Protocol {
  /// Çerçevedeki protokol sürüm baytı (HryFine `IssuedUtil.PROTOCOL_VERSION`).
  /// Saatin 0x2A27 karakteristiğinden türetilir (ör. "10000" -> 0x10). Yanlış değer gönderilirse
  /// saat eski protokol kipine düşer: komutları ACK'ler ama kadran/DIY komutları uygulanmaz.
  static int protocolVersion = PbsCommandIds.protocolVersion;

  /// 0x2A27 metninden sürüm baytını çıkarır. HryFine: baştaki 'V' atılır, ilk '.'ya kadar alınır,
  /// tam sayıya çevrilip bayta kırpılır.
  static int versionFromRevisionString(String raw) {
    var s = raw.trim();
    if (s.startsWith('V') || s.startsWith('v')) s = s.substring(1);
    final dot = s.indexOf('.');
    if (dot >= 0) s = s.substring(0, dot);
    return (int.tryParse(s) ?? PbsCommandIds.protocolVersion) & 0xFF;
  }

  /// Ana paket kurucu: Başlık, uzunluk, komut ve checksum'ı oluşturur.
  static Uint8List buildPacket(int cmdId, int subCmdId, [List<int> payload = const []]) {
    final payloadLen = payload.length;
    final totalLen = payloadLen + 5;

    // 1. Ham bayt listesi
    final raw = <int>[
      PbsCommandIds.ackHeader,           // Byte 0: 0xDF
      (totalLen >> 8) & 0xFF,            // Byte 1: Length High
      totalLen & 0xFF,                   // Byte 2: Length Low
      cmdId,                             // Byte 3 (Geçici): Cmd ID
      protocolVersion,                   // Byte 4: Version (saatten okunan değer)
      subCmdId,                          // Byte 5: SubCmd / Key
      (payloadLen >> 8) & 0xFF,          // Byte 6: Data Length High
      payloadLen & 0xFF,                 // Byte 7: Data Length Low
      ...payload                         // Byte 8..N: Payload
    ];

    // 2. Checksum hesabı (Tüm ham baytların toplamının son 8 biti)
    int sum = 0;
    for (final b in raw) {
      sum = (sum + b) & 0xFF;
    }

    // 3. Checksum'ı 3. indekse enjekte et (NotifyWriteUtils.addSumCheck)
    final packet = Uint8List(raw.length + 1);
    packet[0] = raw[0];
    packet[1] = raw[1];
    packet[2] = raw[2];
    packet[3] = sum; // Checksum!
    for (int i = 3; i < raw.length; i++) {
      packet[i + 1] = raw[i];
    }

    return packet;
  }

  /// 20 baytlık MTU parçalama (BLE aktarımı için)
  static List<Uint8List> chunkPacket(Uint8List packet, {int chunkSize = 20}) {
    final chunks = <Uint8List>[];
    for (int i = 0; i < packet.length; i += chunkSize) {
      final end = (i + chunkSize < packet.length) ? i + chunkSize : packet.length;
      chunks.add(packet.sublist(i, end));
    }
    return chunks;
  }

  // ==========================================
  // EYLEM VE AYAR KOMUTLARI
  // ==========================================

  /// Saati Titret / Bul (0x02, 0x0B)
  static Uint8List vibrateWatch({bool on = true}) {
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subFindBracelet,
      [on ? 1 : 0],
    );
  }

  /// Tarih ve Saat Senkronizasyonu (0x02, 0x01)
  /// Bit-packing ile 4 bayta sıkıştırılır.
  static Uint8List syncTime(DateTime dt) {
    final year = dt.year - 2000;
    final month = dt.month;
    final day = dt.day;
    final hour = dt.hour;
    final min = dt.minute;
    final sec = dt.second;

    final payload = [
      ((year << 2) + ((month & 0xFF) >> 2)) & 0xFF,
      (((month & 3) << 6) + (day << 1) + (hour >> 4)) & 0xFF,
      (((hour & 15) << 4) + (min >> 2)) & 0xFF,
      (((min & 3) << 6) + sec) & 0xFF,
    ];

    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subSysTime,
      payload,
    );
  }

  /// Kamera Deklanşör Modu (0x02, 0x0C)
  static Uint8List triggerCamera({bool on = true}) {
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subSwitchPhoto,
      [on ? 1 : 0],
    );
  }

  /// Nabız Sensörü Kontrolü (0x02, 0x0D)
  static Uint8List setHeartRateSensor({bool enabled = true}) {
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subSwitchHeart,
      [enabled ? 1 : 0],
    );
  }

  /// Tansiyon Sensörü Kontrolü (0x02, 0x0E)
  static Uint8List setBloodPressureSensor({bool enabled = true}) {
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subSwitchBloodPressure,
      [enabled ? 1 : 0],
    );
  }

  /// SpO2 Kandaki Oksijen Sensörü (0x02, 0x1C)
  static Uint8List setBloodOxygenSensor({bool enabled = true}) {
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subSwitchBloodOxygen,
      [enabled ? 1 : 0],
    );
  }

  /// Vücut Sıcaklığı / Ateş Sensörü (0x02, 0x19)
  static Uint8List setTemperatureSensor({bool enabled = true}) {
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subSwitchTemperature,
      [enabled ? 1 : 0],
    );
  }

  /// Bilek Hareketiyle Ekran Açma (0x02, 0x09)
  static Uint8List setRaiseToWake({
    bool enabled = true,
    int startHour = 8,
    int startMinute = 0,
    int endHour = 22,
    int endMinute = 0,
  }) {
    final startTotal = (startHour * 60) + startMinute;
    final endTotal = (endHour * 60) + endMinute;

    final payload = [
      enabled ? 1 : 0,
      (startTotal >> 8) & 0xFF,
      startTotal & 0xFF,
      (endTotal >> 8) & 0xFF,
      endTotal & 0xFF,
    ];

    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subHandBright,
      payload,
    );
  }

  /// Kullanıcı Profili Gönderme (0x02, 0x04)
  /// [gender]: 1 Erkek, 0 Kadın
  static Uint8List setUserProfile({
    required int gender,
    required int age,
    required int heightCm,
    required int weightKg,
  }) {
    final payload = [
      ((gender << 7) + age) & 0xFF,
      (heightCm >> 1) & 0xFF,
      (((heightCm & 1) << 7) + (weightKg >> 3)) & 0xFF,
      ((weightKg & 7) << 5) & 0xFF,
    ];

    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subProfile,
      payload,
    );
  }

  /// Günlük Adım Hedefi (0x02, 0x03)
  static Uint8List setDailyStepTarget(int target) {
    final payload = [
      (target >> 24) & 0xFF,
      (target >> 16) & 0xFF,
      (target >> 8) & 0xFF,
      target & 0xFF,
    ];
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subSportTarget,
      payload,
    );
  }

  /// Cihaz Eşleştirme / Token Gönderme (0x03, 0x00)
  static Uint8List bindDevice(String userId) {
    final token = userId.padRight(8, '0').substring(0, 8);
    final bytes = ascii.encode(token);
    return buildPacket(PbsCommandIds.cmdBangleDevice, 0x00, bytes);
  }

  // ==========================================
  // BİLDİRİM VE ARAMA KOMUTLARI
  // ==========================================

  /// Saate WhatsApp / SMS / Uygulama Bildirimi Bas (0x02, 0x12)
  /// [appType]: 1=SMS, 8=WhatsApp, 2=WeChat, 4=Facebook, 5=Twitter, 10=Instagram
  static Uint8List pushNotification({
    int appType = 8, // Varsayılan WhatsApp
    required String title,
    required String body,
  }) {
    final fullText = title.isNotEmpty ? "$title\n$body" : body;
    var textBytes = utf8.encode(fullText);

    // Saat maksimum 196 bayt metin kabul eder
    if (textBytes.length > 196) {
      textBytes = textBytes.sublist(0, 196);
    }

    final payload = Uint8List(textBytes.length + 3);
    payload[0] = appType;
    payload[1] = 0;
    payload[2] = 0;
    payload.setRange(3, payload.length, textBytes);

    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subMessagePush,
      payload,
    );
  }

  /// Gelen Arama Bildirimi (0x02, 0x11)
  static Uint8List pushIncomingCall(String callerNameOrNumber) {
    final textBytes = utf8.encode(callerNameOrNumber);
    final payload = Uint8List(textBytes.length + 2);
    payload[0] = 1; // Arama tipi
    payload[1] = 0;
    payload.setRange(2, payload.length, textBytes);

    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subAndroidCall,
      payload,
    );
  }

  // ==========================================
  // SPOR VE GEÇMİŞ SENKRONİZASYON KOMUTLARI
  // ==========================================

  /// Canlı Adım Akışı Aç/Kapa (0x05, 0x06)
  static Uint8List setRealtimeSteps({bool enabled = true}) {
    return buildPacket(
      PbsCommandIds.cmdSportInfo,
      PbsCommandIds.sportRealTimeStepSwitch,
      [enabled ? 1 : 0],
    );
  }

  /// Bugünkü Adım ve Sağlık Özetini Çek (0x05, 0x0A)
  static Uint8List queryTodaySummary() {
    return buildPacket(
      PbsCommandIds.cmdSportInfo,
      PbsCommandIds.sportSyncTodayHistory,
    );
  }

  /// Tüm Geçmiş Adım ve Uyku Verisini Çek (0x05, 0x01)
  static Uint8List queryAllHistory() {
    return buildPacket(
      PbsCommandIds.cmdSportInfo,
      PbsCommandIds.sportSyncAllHistory,
    );
  }

  // ==========================================
  // DONANIM AYARLARI, ALARMLAR VE HATIRLATICILAR
  // ==========================================

  /// Saate Titreşimli Alarm Kur (0x02, 0x02)
  static Uint8List setAlarmClock({
    required int hour,
    required int minute,
    int serialId = 0,
    int repeatMask = 127, // 127 = Her gün, 0 = Bir kere
  }) {
    final now = DateTime.now();
    final year = now.year - 2000;
    final month = now.month;
    final day = now.day;

    final bArr = Uint8List(5);
    bArr[0] = ((year << 2) + (month >> 2)) & 0xFF;
    bArr[1] = (((month & 3) << 6) + (day << 1) + (hour >> 4)) & 0xFF;
    bArr[2] = (((hour & 15) << 4) + (minute >> 2)) & 0xFF;
    bArr[3] = (((minute & 3) << 6) + (serialId << 3)) & 0xFF;
    bArr[4] = repeatMask & 0xFF;

    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subAlarmClock,
      bArr,
    );
  }

  /// Hareketsizlik Uyarısı (0x02, 0x05)
  static Uint8List setSedentaryReminder({
    bool enabled = true,
    int intervalMinutes = 60,
    int startHour = 8,
    int endHour = 22,
  }) {
    final stepUnit = ((intervalMinutes - 30) ~/ 15).clamp(0, 15);
    final payload = [
      0, // lunchBreak
      enabled ? 1 : 0,
      0, // threshold high
      100, // threshold low
      stepUnit,
      startHour,
      endHour,
      127, // Her gün tekrar
    ];
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subSedentaryRemind,
      payload,
    );
  }

  /// Su İçme Hatırlatıcısı (0x02, 0x21)
  static Uint8List setDrinkWaterReminder({
    bool enabled = true,
    int intervalMinutes = 60,
    int startHour = 8,
    int endHour = 22,
  }) {
    final stepUnit = (intervalMinutes ~/ 15).clamp(1, 15);
    final payload = [
      0,
      enabled ? 1 : 0,
      stepUnit,
      startHour,
      endHour,
      127,
    ];
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subDrinkWater,
      payload,
    );
  }

  /// Rahatsız Etme Modu (0x02, 0x14)
  static Uint8List setDoNotDisturb({
    bool enabled = true,
    int startHour = 23,
    int endHour = 7,
  }) {
    final startTotal = startHour * 60;
    final endTotal = endHour * 60;
    final payload = [
      enabled ? 1 : 0,
      (startTotal >> 8) & 0xFF,
      startTotal & 0xFF,
      (endTotal >> 8) & 0xFF,
      endTotal & 0xFF,
    ];
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subDisturbMode,
      payload,
    );
  }

  /// Takış Kolu Ayarı: Sol / Sağ (0x02, 0x06)
  static Uint8List setWearingHand({bool leftHand = true}) {
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subWearingWay,
      [leftHand ? 1 : 2],
    );
  }

  /// 12 / 24 Saat Formatı Ayarı (0x02, 0x1A)
  static Uint8List setHourFormat({bool is24Hour = true}) {
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.cmdGetFunction,
      [!is24Hour ? 1 : 0],
    );
  }

  /// Saate Hava Durumu Gönder (0x02, 0x1D)
  static Uint8List setWeather({
    required int currentTemp,
    required int minTemp,
    required int maxTemp,
    int weatherCode = 0,
    String city = "Istanbul",
  }) {
    final now = DateTime.now();
    final cityBytes = utf8.encode(city);
    final payload = <int>[
      (now.year >> 8) & 0xFF,
      now.year & 0xFF,
      now.month & 0xFF,
      now.day & 0xFF,
      0,
      weatherCode & 0xFF,
      minTemp & 0xFF,
      maxTemp & 0xFF,
      cityBytes.length,
      ...cityBytes,
      currentTemp & 0xFF,
    ];
    return buildPacket(
      PbsCommandIds.cmdSettingOrder,
      PbsCommandIds.subSetWeather,
      payload,
    );
  }

  /// Saatten Gelen Paket Onayı (ACK) Gönder (0xFD)
  /// `AckPackageConfigUtils.java` eşleniğidir.
  static Uint8List configAck(int cmdId, int subCmdId, [int result = 1]) {
    final bArr = Uint8List(9);
    bArr[0] = PbsCommandIds.ackResponseHeader; // 0xFD
    bArr[1] = 0;
    bArr[2] = 5;
    bArr[3] = 0;
    bArr[4] = cmdId & 0xFF;
    bArr[5] = subCmdId & 0xFF;
    bArr[6] = 0;
    bArr[7] = 0;
    bArr[8] = result & 0xFF;

    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum = (sum + bArr[i]) & 0xFF;
    }
    bArr[3] = sum;
    return bArr;
  }

  // ==========================================
  // KADRAN STÜDYOSU VE EKRAN YÖNETİMİ
  // ==========================================

  /// Saatteki Tüm Yüklü Kadranları ve Aktif Kadranı Sorgula (0x0F, 0x01)
  /// Saat `0x0F, 0x02` yanıtı döner.
  static Uint8List queryWatchFaces() {
    return buildPacket(PbsCommandIds.cmdWatchFace, 0x01);
  }

  /// Saatteki Özelleştirilebilir Kadran Bilgilerini Sorgula (0x0F, 0x04)
  /// Saat `0x0F, 0x05` yanıtı döner (koordinatlar, renk ve widget kodları).
  static Uint8List queryCustomWatchFace() {
    return buildPacket(PbsCommandIds.cmdWatchFace, 0x04);
  }

  /// Özel Kadran Ayarlarını Saate Gönder (0x0F, 0x05)
  /// [timeX]: 0..240 (Yatay koordinat)
  /// [timeY]: 0..240 (Dikey koordinat)
  /// [colorRgb565]: 16-bit RGB565 renk kodu (örn: 0xFFFF beyaz, 0x073F cyan)
  /// [aboveWidget]: 0=Yok, 1=Tarih, 2=Uyku, 3=Nabız, 4=Adım
  /// [belowWidget]: 0=Yok, 1=Tarih, 2=Uyku, 3=Nabız, 4=Adım
  /// [bgUpdate]: 2 = Parametre güncellemesi (arkaplan OTA yüklemesi olmadan)
  ///
  /// [faceCode]: Saatin 0x0F/0x05 yanıtında bildirdiği kadran kodu (2 veya 8 bayt).
  /// HryFine `setCustomWatchFace` / `setCustomWatchFace8` eşleniğidir.
  /// [bgUpdate]: 0 = arka plan saatte güncel, 1 = yeni arka plan gönderilecek/bekliyor,
  ///             2 = saatin dahili arka planı kullanılsın.
  static Uint8List setCustomWatchFace({
    required int timeX,
    required int timeY,
    required int colorRgb565,
    required List<int> faceCode,
    int aboveWidget = 1,
    int belowWidget = 4,
    int bgUpdate = 2,
  }) {
    final payload = Uint8List(faceCode.length + 9);
    payload.setRange(0, faceCode.length, faceCode);
    var o = faceCode.length;
    payload[o++] = (timeX >> 8) & 0xFF;
    payload[o++] = timeX & 0xFF;
    payload[o++] = (timeY >> 8) & 0xFF;
    payload[o++] = timeY & 0xFF;
    payload[o++] = (colorRgb565 >> 8) & 0xFF;
    payload[o++] = colorRgb565 & 0xFF;
    payload[o++] = aboveWidget & 0xFF;
    payload[o++] = belowWidget & 0xFF;
    payload[o++] = bgUpdate & 0xFF;

    return buildPacket(
      PbsCommandIds.cmdWatchFace,
      0x05,
      payload,
    );
  }

  /// Saatin Özellik Tablosunu Sorgula (0x19, 0x00)
  /// Yanıt: 0xAA ile başlayan özellik baytları (kadran yetenekleri, çözünürlük vb.)
  static Uint8List queryFeatures() => buildPacket(PbsCommandIds.cmdGetFeature, 0x00);

  /// Saatin Dahili Kadranını Değiştir (0x0F, 0x03)
  /// [faceCode]: 2 baytlık kadran kodu (örn: [0x80, 0x00] vb.)
  static Uint8List switchInternalWatchFace(List<int> faceCode) {
    return buildPacket(
      PbsCommandIds.cmdWatchFace,
      0x03,
      faceCode,
    );
  }
}
