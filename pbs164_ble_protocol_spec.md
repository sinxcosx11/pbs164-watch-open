# ⌚ Polosmart PBS 164 (HryFine) — BLE Protokol Spesifikasyonu

Cihaz: `PBS164`, üretici yazılımı `SE32LB_HS9 Ultra2_YLDZ[PBS164]_SStyle1_240x296_HryFine`.
Bu belge HryFine (`com.lianhezhuli.hyfit`) APK'sının tersine mühendisliği **ve gerçek bir HryFine ↔ saat
oturumunun HCI snoop yakalaması** ile doğrulanmıştır. ✅ = gerçek cihazda test edildi.

---

## 1. GATT

| Servis / Karakteristik | UUID | Görev |
|---|---|---|
| UART servisi | `6E400001-B5A3-F393-E0A9-E50E24DCCA9F` | Ana komut kanalı |
| ├ TX (telefon→saat) | `6E400002-…` | Write Without Response, 20 baytlık parçalar |
| └ RX (saat→telefon) | `6E400003-…` | Notify |
| **OTA servisi** | `0000FF00-0000-1000-8000-00805F9B34FB` | Dosya gönderimi (arka plan, kadran) |
| ├ OTA yazma | `0000FF02-…` | Write Without Response |
| └ OTA bildirim | `0000FF01-…` | Notify |
| Cihaz bilgisi | `0x180A` | `0x2A27` = **protokol sürümü** ("10000"), `0x2A28` = **özellik tablosu** |
| Pil | `0x180F` / `0x2A19` | |

---

## 2. UART çerçevesi

```
Byte 0 : 0xDF  (telefon→saat veri)   |  0xFD (ACK)
Byte 1-2 : (payload_len + 5) big-endian
Byte 3 : toplama sağlaması (çerçevedeki TÜM baytların toplamı & 0xFF, bu bayt 0 sayılır)
Byte 4 : komut (cmd)
Byte 5 : PROTOKOL SÜRÜMÜ  ← sabit 0x01 DEĞİL!
Byte 6 : alt komut (sub)
Byte 7-8 : payload uzunluğu
Byte 9.. : payload
```

### ⚠️ Protokol sürümü baytı (en kritik bulgu)
HryFine, bağlanınca `0x2A27` okur. Değer `"10000"` → `V`/`v` önekı atılır, ilk `.`'ya kadar alınır,
tamsayıya çevrilip **bayta kırpılır**: `10000 & 0xFF = 0x10`. Tüm komutlar `0x10` ile gönderilir.
`0x01` gönderilirse saat **eski uyumluluk kipine** düşer: komutları ACK'ler ama kadran/DIY
komutlarını uygulamaz, kayıtları 11 baytlık/2 baytlık biçimde ve 16-bit değerleri ters bayt
sırasıyla döndürür. ✅

### Saatten gelen çerçeveler
Saat verisi `0xDF` ile gelir; telefon her `0xDF` çerçevesine `0xFD` ACK ile yanıt verir:
`FD 00 05 <sum> <cmd> <sub> 00 00 01`. Saatin ACK'i: `FD 00 05 <sum> <cmd> <sub> 00 <x> 01` (son bayt 1 = başarı).

### Eşleme (bind) kimliği
`cmd 0x03, sub 0x00, payload = 8 karakter ASCII`. Saat kullanıcı verisini (kadran listesi, DIY kadran)
bu kimliğe göre tutuyor: **farklı kimlikle bağlanmak DIY kadranı ve listeyi sıfırlar** ✅.
HryFine'ın kimliği kendi oturum yakalamasından alınıp uygulamada sabitlendi (`PbsBleService.userToken`).

### HryFine bağlantı sırası
1. `0x2A27` oku → sürüm baytı  
2. `0xF0` doğrulama (8 rastgele karakter, sürüm 0x01 ile) → ACK  
3. `0x19/0x00` özellik tablosu (+ `0x2A28` okuması)  
4. `0x13/0x01` cihaz OTA bilgisi, `0xF3/0x00` cihaz bilgisi  
5. `0x03` bind, ardından ayarlar (`0x02` altkomutları: 0x0A, 0x01 saat, 0x04 profil, 0x24 isim, 0x03 hedef…)  
6. `0x09/0x00` ayar bilgisi, `0x0F/0x01` kadran listesi, `0x0F/0x04` DIY kaydı

---

## 3. Özellik tablosu (0x19 yanıtı / 0x2A28) — `0xAA` ile başlar

| Bayt | Bit | Anlam |
|---|---|---|
| 2 | 0x80 / 0x40 / 0x20 | kadran seçimi / **özel kadran** / **OTA ile arka plan** |
| 2 | düşük 4 bit | çözünürlük kodu (16 bitlik alan 16'dan büyükse bayt 16 kullanılır) |
| 3 | düşük 4 bit | ekran şekli (1 = yuvarlak köşeli dikdörtgen) |
| 16 | düşük 6 bit | çözünürlük = değer + 15 (**1 → 16 → 240×298**) |
| 17 | – | `codeFormat` (bu saatte 8) |
| 18 | 0x80 / 0x40 / 0x20 | `is565Bmp` (PAR arka plan) / `is8Bytes` (8 baytlık kadran kodu) / önizleme bayrağı |
| 18 | 0x02 / 0x01 | çevrimiçi duvar kâğıdı / DIY varsayılana dön desteği |

Bu saatin tablosu: `aa cf e0 81 9f ff fc 3c 00 00 00 00 00 00 10 66 41 08 cf 10 …`

---

## 4. Kadran komutları (cmd `0x0F`) — 8 baytlık kodlar ✅

| Alt komut | Yön | Payload | Açıklama |
|---|---|---|---|
| `01` | →saat | – | Kadran listesini iste |
| `09` | saat→ | `sayı(1) aktif(8) kod[]×8 paperBoyut(4) dialBoyut(4)` | Liste yanıtı. Bu saatte `paper=0x19000` (100 KB), `dial=0xD000` |
| `03` | →saat | kod(8) | Kadran seç (listedeki kodlar). **Bu saatte ACK alınıyor ama ekran değişmiyor — araştırılıyor** |
| `04` | →saat | – | DIY kaydını iste |
| `05` | ↔ | kod(8) X(2) Y(2) renk(2) üst(1) alt(1) bgUpdate(1) | DIY kaydı yaz/oku (17 bayt). Renk RGB565 big-endian |
| `06` | saat→ | `01` | "Arka planı gönder" (bgUpdate=1 yazıldıktan sonra saat ister) |

* **bgUpdate:** `0` arka plan güncel · `1` yeni arka plan gönderilecek · `2` saatin dahili arka planı.
* **Üst/alt widget kodları:** 0 kapalı, 1 tarih, 2 uyku, 3 nabız, 4 adım.
* **Konum sınırları** (HryFine, 240×298): X ≤ 140, Y ≤ 198. Saat bloğu ≈ 100×(56 + 22·widget) px.
* DIY kodu: saatin 0F05 yanıtındaki koddur. Yanlış kodla yazmak **ACK alır ama yok sayılır**. ✅
  (Kodun son iki baytı yanıtlar arasında yer değiştirebiliyor: `8f c0` ↔ `c0 8f`; ikisi de aynı kadran.)
* DIY kaydedilince saat DIY kadrana kendisi geçer (ayrı `0F03` gerekmez).

### DIY kaydetme akışı (HryFine ile birebir) ✅
1. `0F05` ile ayarları yaz (yeni arka plan varsa `bgUpdate=1`) → saat `0F06 [01]` + ACK gönderir
2. UART bildirimini kapat, OTA `FF01` bildirimini aç, MTU 185–256
3. OTA gönderimi (aşağıda), `main=2, sub=1` (arka plan)
4. UART bildirimini geri aç; `0F01`/`0F04` ile durumu oku

---

## 5. OTA protokolü (servis `0xFF00`) ✅

Kontrol çerçevesi: `D5 <cmd> <sub> <op> 00 00 <lenH> <lenL> <payload…> <sum>` (sum = önceki tüm baytların toplamı & 0xFF)
Veri çerçevesi: `D6 <parça…>`. Arka plan için `cmd=2, sub=1`.

| Adım | Telefon | Saat |
|---|---|---|
| Başlat | `op=01`, payload = `(MTU-3)(2) dosyaUzunluğu(4)` | `op=81`, payload = `çerçeveBoyutu(2) aralık_ms(2) grupSayısı(1) zamanAşımı(1)` |
| Veri | `D6` + `(çerçeve-1)` baytlık parçalar, grup başına N tane (bu saatte 10, 20 ms aralık) | – |
| Grup CRC | `op=02`, payload = CRC8(grubun veri baytları) | `op=82`, durum bayt[5]=0 |
| Dosya CRC | `op=03`, payload = CRC8(tüm dosya) | `op=83`, durum bayt[5]=0 |

* **CRC8:** polinom `0x31`, MSB-önce, başlangıç `0`, yansıtma yok. Dosya CRC'si tüm gruplar boyunca birikir.
* Watch ilk yanıtı ~2.5 sn'de verebilir. Hata: `D6` başlıklı bildirim.
* Doğrulama: yakalanan gönderimde 44 grup CRC'sinin tamamı ve dosya CRC'si (0x5A, 78130 bayt) birebir eşleşti.

---

## 6. PAR arka plan biçimi

Dosya `50 41` ("PA") ile başlar: `50 41 00 00 <genişlik LE(2)> <yükseklik LE(2)> …` (240×298 → `f0 00 2a 01`).
Dönüştürme HryFine'daki `libabpartool.so` ile yapılır (`ParTool.rawToPar(argb, w, h, false, false, false)`,
girdi piksel başına A,R,G,B bayt). Çıktı saatin `paperBoyut` sınırını (100 KB) aşarsa kaynak
JPEG kalitesi 5'er düşürülerek yeniden denenir (HryFine ile aynı).

---

## 7. Diğer komutlar (cmd `0x02`, sürüm `0x10`)

| Sub | İşlev | Payload |
|---|---|---|
| `01` | Saat/tarih | 4 bayt bit-paketli (yıl-2000, ay, gün, saat, dk, sn) |
| `03` | Adım hedefi | 4 bayt int |
| `04` | Profil | cinsiyet/yaş/boy/kilo |
| `0B` | Saati bul | `[01]` |
| `0C` | Kamera | `[01]/[00]` |
| `0D/0E/1C/19` | Nabız / tansiyon / SpO2 / sıcaklık ölçümü | `[01]/[00]` |
| `11` / `12` | Arama / bildirim | UTF-8 |
| `15` | Saat dili | `[kod]` |
| `1D` | Hava durumu | |

`cmd 0x05` spor verisi: sub `01` tüm geçmiş, `0A` bugün, `06` canlı adım anahtarı.

---

## 8. Bilinen kısıtlar / açık sorular
* DIY modunda **yazı tipi, boyutu ve tarih biçimi donanımda sabit** ("1010" gibi ayraçsız gün+ay).
  Özel yazı tipi için tam kadran dosyası gerekiyor (OTA `cmd=5, sub=1`, HryFine'ın "çevrimiçi kadran" yolu;
  dosyada `[16]` ve `[17]` baytlarıyla 20 baytlık giriş tablosu var — biçim henüz çözülmedi).
* Yerleşik kadran geçişi (`0F03`) ACK alsa da etkisiz kalıyor; HryFine'ın gerçek komutu yakalanmadı.
