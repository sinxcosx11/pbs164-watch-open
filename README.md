# ⚡ PBS 164 Pulse

> **Polosmart PBS 164 ve Benzeri Akıllı Saatler İçin Açık Kaynaklı, Reklamsız, Modern Eşlikçi Uygulaması.**

[![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://android.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![No Ads](https://img.shields.io/badge/Ads-0%25%20Zero%20Ads-success)](#)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Local-green)](#)

---

> ### ⚠️ YASAL UYARI & FERAGATNAME (DISCLAIMER)
> **Bu proje bağımsız bir açık kaynak ve hobi çalışmasıdır.**  
> **Bu projenin Polosmart, Shenzhen Lianhe Zhuli Teknoloji (HryFine) veya bu markaların üreticileri/dağıtıcıları ile hiçbir ticari, kurumsal veya resmi bağı, sponsorluğu ya da desteği BULUNMAMAKTADIR.**
> 
> "Polosmart" ve ilgili tüm marka/ürün isimleri ilgili hak sahiplerinin tescilli ticari markalarıdır. Bu isimler bu projede yalnızca cihaz donanımıyla yazılım uyumluluğunu belirtmek amacıyla adil kullanım (fair use) kapsamında anılmıştır.
> 
> Bu depodaki tüm kodlar topluluk tarafından sıfırdan yazılmıştır; üçüncü taraf tescilli kütüphane, kaynak kodu veya lisanssız ikili dosya barındırmaz.

---

## 🎯 Bu Proje Neden Doğdu? (Motivasyonumuz)

Piyasadaki bütçe dostu akıllı saatlerin (Polosmart PBS 164 vb.) donanımı optik nabız sensörü, ivmeölçer, titreşim motoru ve renkli ekranıyla günlük kullanım için oldukça yeterlidir.

Ancak saatin varsayılan fabrika uygulaması olan **HryFine**:
- ❌ Uygulama her açıldığında kullanıcıyı boğan **tam ekran bahis, kumar ve alışveriş reklamları**,
- ❌ 2010'lardan kalma, hantal, sürekli kasan ve göz yoran kalitesiz arayüz,
- ❌ Arka planda sürekli çalışan gereksiz veri toplama ve telemetri servisleri,
- ❌ Saatin nabız ölçümünü 15-20 saniye sonra kapatan bağlantı kopuklukları,
- ❌ Bozuk çeviriler ve neredeyse sıfır kişiselleştirme sunuyordu.

> **"Donanım gayet yeterliyken neden berbat bir arayüze ve reklam istilasına katlanmak zorunda kalalım?"**  
> Bu soruyla yola çıktık; saatin standart BLE (Bluetooth Low Energy) komutlarını analiz ederek tamamen sıfırdan, modern ve siberpunk estetiğine sahip, **reklamsız, hızlı ve %100 açık kaynaklı** kendi eşlikçi uygulamamızı geliştirdik.

---

## ✨ Öne Çıkan Özellikler

### 🧘 Stres Radarı & Haptik Biyolojik Nefes Seansı (Biofeedback)
- **Canlı HRV (Kalp Hızı Değişkenliği) & RMSSD:** Saatin optik nabız sensöründen canlı R-R aralıkları kestirilir; otonom sinir sisteminin stres durumu gerçek zamanlı olarak radarda analiz edilir.
- **Gözü Kapalı Haptik Bilek Rehberliği:** Seans boyunca saatin titreşim motoru (`ble.vibrateWatch()`) ve telefon dokunsal geri bildirimi nefes fazlarıyla senkronize çalışır. **Gözlerinizi kapatıp ekrana hiç bakmadan**, sadece bileğinizdeki titreşimlerle seansı tamamlayabilirsiniz.
- **3 Klinik Nefes Protokolü:**
  - 🥋 **Kutu Nefesi (4-4-4-4):** Özel kuvvetler stres kontrolü ve anlık kortizol baskılama.
  - 🌙 **4-7-8 Derin Rahatlama:** Hızlı parasempatik sinir sistemi aktivasyonu ve derin gevşeme.
  - 🌊 **Rezonans Koheransı (5.5s):** Kalp ritmi ve solunumu senkronize eden maksimum HRV modu.
- **Seans Sonu Biyo-Geri Bildirim Raporu:** Nabız düşüşü (BPM), stres azalma yüzdesi ve koherans raporu.

### ⌚ Canlı Kadran Stüdyosu (Watch Face Studio)
- Saat metninin ekrandaki **X / Y koordinatlarını piksel hassasiyetinde ayarlama**.
- **RGB565 Renk Paleti:** Canlı renk seçici ile saat ve gösterge renklerini dilediğiniz tonda özelleştirme.
- Ekran üst ve alt widget'larını (Adım, Nabız, Kalori, Tarih) seçebilme.

### 💓 Kesintisiz Biyometrik Ölçüm & Sağlık Analizi
- **Akıllı Can Simidi (PPG Keep-Alive):** Saatin uykuya dalmasını engelleyen periyodik can simidi protokolü ile kesintisiz nabız akışı.
- **Tansiyon & SpO2:** Canlı tansiyon ve kandaki oksijen ölçümü.
- **Tıbbi Geçmiş & CSV Dışa Aktarma:** Ölçülen tüm biyometrik verileri cihazda saklar ve tek tıkla hekiminizle paylaşabileceğiniz `.csv` dosyası olarak dışa aktarır.

### 🏃 GPS Destekli Antrenman & Rota Takibi
- OpenStreetMap tabanlı çevrimdışı önbellekli harita desteği.
- Anlık hız, tempo, kalori ve canlı GPS rotası kaydı.

### 📳 Hızlı Cihaz Komutları & Yardımcılar
- **Bilek Titreşimi (Saati Bul):** Saati tek tıkla titretme.
- **Zaman Senkronizasyonu:** Telefon saatini tek tıkla saate aktarma.
- **Uzaktan Kamera Deklanşörü:** Saatin sarsıntı sensörüyle telefon kamerasını tetikleme.

---

## 🔒 %100 Gizlilik ve Sıfır Reklam

Bu uygulama **tamamen yerel ve gizlilik odaklıdır**:
- 🚫 **Sıfır Reklam:** Asla reklam içermez.
- 🚫 **Sıfır Sunucu:** Hiçbir dış sunucuya veri göndermez.
- 🚫 **Sıfır Telemetri:** Analitik veya kullanıcı takibi yapmaz.
- 🛡️ Sağlık verileriniz sadece kendi telefonunuzun güvenli yerel hafızasında saklanır.

---

## 🚀 Projeyi Çalıştırma & Derleme

### Gereksinimler
- [Flutter SDK](https://flutter.dev) (v3.24 veya üzeri)
- [Android SDK](https://developer.android.com/studio) (Android 7.0+ / API 24+)

### Adımlar

1. Depoyu klonlayın:
```bash
git clone https://github.com/sinxcosx11/pbs164-watch-open.git
cd pbs164-watch-open/pbs164_pulse
```

2. Bağımlılıkları yükleyin:
```bash
flutter pub get
```

3. Cihazınızda çalıştırın:
```bash
flutter run
```

4. APK derleyin:
```bash
flutter build apk --target-platform android-arm64
```

---

## 📜 Lisans

Bu proje [MIT Lisansı](LICENSE) kapsamında açık kaynak olarak yayınlanmıştır.
