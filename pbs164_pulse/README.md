# PBS 164 Pulse

Polosmart PBS 164 saat için Flutter tabanlı Android kontrol uygulaması.

## Özellikler

- BLE UART (`6E40...`) üzerinden saat kontrolü
- Sağlık ölçümleri (nabız, tansiyon, SpO2) ve adım/kalori senkronu
- Bildirim, kamera tetikleme, saati bul gibi hızlı komutlar
- DIY kadran düzenleme ve OTA (`FF00/FF01/FF02`) ile arka plan/kadran aktarımı
- Yerel Android köprüsü ile zil/vibrasyon ve PAR dönüştürme

## Gereksinimler

- Flutter SDK (3.x)
- Android SDK + lisanslar
- USB debugging açık Android telefon (gerçek BLE testleri için)

## Çalıştırma

```bash
flutter pub get
flutter run
```

## APK üretimi

Debug APK:

```bash
flutter build apk --debug
```

Release APK (bu projede şu an debug signing ile üretilir):

```bash
flutter build apk --release
```

Çıktılar:

- `build\app\outputs\flutter-apk\app-debug.apk`
- `build\app\outputs\flutter-apk\app-release.apk`

## Notlar

- OTA servisleri Android tarafında tam UUID ile eşleşir (`0000ff00/01/02-...`).
- BLE bildirim birleştirme akışı, tek pakette birden fazla çerçeve geldiğinde de güvenli şekilde ayrıştırılır.
