import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import '../protocol/wf_dial.dart';

enum WfTimeLayout {
  singleLine, // Yan yana tek satır (HH : MM)
  stacked,    // Üst üste iki satır (HH / MM)
}

class WfDialBuilder {
  static const _offscreenX = 250;
  static const _offscreenY = 350;
  static const _cellHalfW = 19;
  static const _cellHalfH = 28;

  /// Şablonu assets içerisinden yükler.
  static Future<Uint8List> loadBaseTemplate() async {
    final bd = await rootBundle.load('assets/templates/tmpl_base.bin');
    return bd.buffer.asUint8List();
  }

  /// Özel kadran WF dosyasını oluşturur.
  static Uint8List buildCustomDial({
    required Uint8List baseTemplate,
    required Uint8List backgroundPar,
    required Uint8List digitStripPar,
    WfTimeLayout layout = WfTimeLayout.singleLine,
    int timeX = 48,
    int timeY = 130,
    bool minimalist = true,
  }) {
    final dial = WfDial.parse(baseTemplate);

    // Her gönderimde saatin yeni kadran olarak algılaması için benzersiz ID
    final rng = Random();
    final newId = Uint8List(8);
    newId[0] = 0x00;
    newId[1] = 0x00;
    newId[2] = 0x01;
    newId[3] = 0x01;
    newId[4] = 0x00;
    newId[5] = 0x00;
    newId[6] = rng.nextInt(255);
    newId[7] = (DateTime.now().millisecondsSinceEpoch & 0xFF);
    dial.id = newId;

    // Rakamların konum haritası
    final Map<int, (int, int)> digitPositions;
    if (layout == WfTimeLayout.singleLine) {
      // Tek satır: timeX ve timeY sol-üst başlangıçtır
      // 08(H1: timeX), 09(H2: timeX+38 -> biter: timeX+76)
      // İki nokta: timeX+88 (genişlik 8 -> biter: timeX+96)
      // 0a(M1: timeX+110) -> İki nokta ile M1 arası 14px temiz boşluk!
      // 0b(M2: timeX+148) -> Toplam blok genişliği: 186px, Yükseklik: 56px
      digitPositions = {
        0x08: (timeX, timeY),
        0x09: (timeX + 38, timeY),
        0x0a: (timeX + 110, timeY),
        0x0b: (timeX + 148, timeY),
      };
    } else {
      // Üst üste: saat üstte, dakika altta
      // Toplam blok genişliği: 80px, Yükseklik: 118px (56 + 6 + 56)
      digitPositions = {
        0x08: (timeX, timeY),
        0x09: (timeX + 42, timeY),
        0x0a: (timeX, timeY + 62),
        0x0b: (timeX + 42, timeY + 62),
      };
    }

    final offscreenIds = {0x4e, 0x46, 0x49, 0x41, 0x40, 0x01};

    final newRecords = <WfRecord>[];
    for (final r in dial.records) {
      if (r.id == 0x10) {
        // Arka plan görseli
        newRecords.add(WfRecord(Uint8List.fromList(r.raw), [backgroundPar]));
      } else if (digitPositions.containsKey(r.id)) {
        // HH ve MM rakamları
        final (nx, ny) = digitPositions[r.id]!;
        // Saat kayıtlarının (x,y) değerleri sol-üst değil MERKEZ noktasıdır (arka plan kaydı da 120,149 =
        // ekran merkezi). Arayüzdeki sol-üst koordinatı hücre yarı boyutu (38x56 -> 19,28) kadar kaydırıyoruz.
        final rec = r.copyWith(x: nx + _cellHalfW, y: ny + _cellHalfH);
        // Paylaşımlı veri yapısı: 0x08, 0x09, 0x0a boş, sadece 0x0b görsel şeridini taşır!
        rec.images = (r.id == 0x0b) ? [digitStripPar] : [];
        newRecords.add(rec);
      } else if (minimalist && offscreenIds.contains(r.id)) {
        // İstenmeyen öğeler: tablodan silinmez (crash önlenir), ekran dışına taşınır!
        final rec = r.copyWith(x: _offscreenX, y: _offscreenY);
        newRecords.add(rec);
      } else {
        // Diğer kayıtlar orijinal haliyle korunur
        newRecords.add(WfRecord(Uint8List.fromList(r.raw), List.from(r.images)));
      }
    }

    dial.records = newRecords;
    return dial.build();
  }
}
