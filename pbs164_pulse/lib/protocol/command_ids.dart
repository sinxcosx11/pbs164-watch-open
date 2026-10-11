/// Polosmart PBS 164 (HryFine) Protokol Sabitleri
/// Resmi HryFine APK'sından (com.lianhezhuli.hyfit) çıkarılmıştır.
class PbsCommandIds {
  // Paket Başlıkları
  static const int ackHeader = 0xDF;         // Telefon -> Saat (223)
  static const int ackResponseHeader = 0xFD; // Saat -> Telefon (253)
  static const int protocolVersion = 0x01;

  // Ana Komut Kodları (CommandID.java)
  static const int cmdOta = 1;
  static const int cmdSettingOrder = 2;       // Ayarlar ve Tetikleyiciler
  static const int cmdBangleDevice = 3;       // Cihazı Eşle / Bağla
  static const int cmdUnbandleDevice = 4;     // Bağlantıyı Kopar
  static const int cmdSportInfo = 5;          // Adım, Kalori, Uyku Senkronu
  static const int cmdResetDevice = 6;
  static const int cmdFactoryTest = 7;
  static const int cmdAlarmClock = 8;
  static const int cmdDeviceSetting = 9;
  static const int cmdFlashRead = 10;
  static const int cmdDeviceTest = 11;
  static const int cmdDeviceControl = 12;     // Kamera ve Buton Tetikleme
  static const int cmdRestoreFactory = 13;
  static const int cmdBtDualMode = 14;        // BT 3.0 Classic Audio MAC
  static const int cmdWatchFace = 15;         // Kadran Yükleme
  static const int cmdMedicationReminder = 16;
  static const int cmdDrinkReminder = 17;
  static const int cmdNewMessageRemind = 18;
  static const int cmdOtaNew = 19;
  static const int cmdSedentaryRemind = 20;
  static const int cmdGetFeature = 25;
  static const int cmdGetFunction = 26;
  static const int cmdBlePairCode = 31;
  static const int cmdProductIdCode = 32;
  static const int cmdFirmwareQuery = 0xF0;   // 240
  static const int cmdDeviceInfo = 0xF3;      // 243

  // Ayar ve Kontrol Alt Komutları (SettingIssuedUtils.java)
  static const int subSysTime = 1;              // Saat Eşitleme
  static const int subAlarmClock = 2;          // Alarm Kurma
  static const int subSportTarget = 3;         // Günlük Adım Hedefi
  static const int subProfile = 4;             // Cinsiyet, Yaş, Boy, Kilo
  static const int subSedentaryRemind = 5;     // Hareketsizlik Uyarısı
  static const int subWearingWay = 6;          // Sol / Sağ Kol
  static const int subNotifyRemind = 7;        // Bildirim Ayarları
  static const int subDeviceBasis = 8;         // Güç Tasarrufu
  static const int subHandBright = 9;          // Bilek Hareketiyle Ekran Açma
  static const int subMatching = 10;           // Eşleme Aç/Kapa
  static const int subFindBracelet = 11;       // Saati Titret / Bul
  static const int subSwitchPhoto = 12;        // Kamera Deklanşörü
  static const int subSwitchHeart = 13;        // Nabız Sensörü (Aç/Kapa)
  static const int subSwitchBloodPressure = 14;// Tansiyon Sensörü
  static const int subSleepMonitoring = 15;    // Uyku Takibi
  static const int subAndroidCall = 17;        // Gelen Arama Bildirimi
  static const int subMessagePush = 18;        // WhatsApp / SMS / Uygulama Bildirimi
  static const int subSetWeather = 19;         // Hava Durumu
  static const int subDisturbMode = 20;        // Rahatsız Etmeyin
  static const int subSetLanguage = 21;        // Dil Seçimi
  static const int subHeartAuto = 22;          // Otomatik Nabız Takibi
  static const int subSwitchTemperature = 25;  // Vücut Isısı
  static const int subSwitchBloodOxygen = 28;  // SpO2 (Kandaki Oksijen)
  static const int subTemperatureUnit = 30;    // °C / °F
  static const int subDrinkWater = 33;         // Su İçme Hatırlatıcı

  // Spor ve Sağlık Geçmişi Alt Komutları (SportIssuedUtil.java)
  static const int sportSyncAllHistory = 1;
  static const int sportSyncStepHistory = 2;
  static const int sportSyncSleepHistory = 3;
  static const int sportSyncHeartHistory = 4;
  static const int sportSyncBloodHistory = 5;
  static const int sportRealTimeStepSwitch = 6; // Canlı Anlık Adım Akışı
  static const int sportSyncTodayHistory = 10;  // Bugünkü Özet
}

/// GATT UUID Sabitleri (BleConstants.java)
class PbsGattUuids {
  static const String uartService = "6e400001-b5a3-f393-e0a9-e50e24dcca9f";
  static const String uartWrite   = "6e400002-b5a3-f393-e0a9-e50e24dcca9f";
  static const String uartNotify  = "6e400003-b5a3-f393-e0a9-e50e24dcca9f";

  static const String batteryService = "0000180f-0000-1000-8000-00805f9b34fb";
  static const String batteryLevel   = "00002a19-0000-1000-8000-00805f9b34fb";

  static const String deviceInfoService = "0000180a-0000-1000-8000-00805f9b34fb";
}
