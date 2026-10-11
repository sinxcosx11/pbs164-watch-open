import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'native_bridge.dart';

class FontPreset {
  final String id;
  final String name;
  final String? fontFamily;
  final FontWeight weight;
  final double scale;
  final String previewSample;

  const FontPreset({
    required this.id,
    required this.name,
    required this.fontFamily,
    required this.weight,
    required this.scale,
    required this.previewSample,
  });
}

class WfFontService {
  static const List<FontPreset> presets = [
    FontPreset(
      id: 'modern',
      name: 'Modern Bold',
      fontFamily: null,
      weight: FontWeight.w800,
      scale: 0.88,
      previewSample: '12:45',
    ),
    FontPreset(
      id: 'ink',
      name: 'El Yazısı / Ink',
      fontFamily: 'cursive',
      weight: FontWeight.w700,
      scale: 0.95,
      previewSample: '12:45',
    ),
    FontPreset(
      id: 'digital',
      name: 'Retro Dijital',
      fontFamily: 'monospace',
      weight: FontWeight.w700,
      scale: 0.86,
      previewSample: '12:45',
    ),
    FontPreset(
      id: 'serif',
      name: 'Klasik Serif',
      fontFamily: 'serif',
      weight: FontWeight.w700,
      scale: 0.90,
      previewSample: '12:45',
    ),
    FontPreset(
      id: 'minimal',
      name: 'Minimal Clean',
      fontFamily: null,
      weight: FontWeight.w400,
      scale: 0.82,
      previewSample: '12:45',
    ),
  ];

  static FontPreset getPreset(String id) {
    return presets.firstWhere((p) => p.id == id, orElse: () => presets[0]);
  }

  /// 0-9 rakamlarını içeren 38x560 piksellik şeffaf şerit PAR dosyasını üretir.
  static Future<Uint8List> generateDigitStripPar({
    required Color color,
    required String fontId,
    int cellW = 38,
    int cellH = 56,
  }) async {
    final preset = getPreset(fontId);
    final totalH = cellH * 10;

    TextPainter painterFor(int k) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$k',
          style: TextStyle(
            color: color,
            fontSize: cellH * preset.scale,
            fontWeight: preset.weight,
            fontFamily: preset.fontFamily,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      tp.layout();
      return tp;
    }

    // 1) Her rakamın GERÇEK mürekkep sınırlarını piksellerden ölç (font kutusuna güvenme).
    const pad = 24;
    final mw = cellW + pad * 2;
    final mh = cellH + pad * 2;
    final inkL = List<double>.filled(10, 0);
    final inkR = List<double>.filled(10, 0);
    var minTop = 1e9;
    var maxBottom = -1e9;
    for (var k = 0; k < 10; k++) {
      final tp = painterFor(k);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec, Rect.fromLTWH(0, 0, mw.toDouble(), mh.toDouble()));
      final ox = (mw - tp.width) / 2;
      final oy = (mh - tp.height) / 2;
      tp.paint(c, Offset(ox, oy));
      final pic = rec.endRecording();
      final img = await pic.toImage(mw, mh);
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      pic.dispose();
      img.dispose();
      var l = mw, r = -1, t = mh, b = -1;
      if (bd != null) {
        for (var y = 0; y < mh; y++) {
          for (var x = 0; x < mw; x++) {
            if (bd.getUint8((y * mw + x) * 4 + 3) > 40) {
              if (x < l) l = x;
              if (x > r) r = x;
              if (y < t) t = y;
              if (y > b) b = y;
            }
          }
        }
      }
      if (r < 0) {
        l = mw ~/ 2;
        r = l;
        t = mh ~/ 2;
        b = t;
      }
      // Ölçüm tuvalindeki ink sınırlarını, glif çizim ofsetine göre kaydet (tp'ye göre bağıl).
      inkL[k] = l - ox;
      inkR[k] = r + 1 - ox;
      if (t - oy < minTop) minTop = t - oy;
      if (b + 1 - oy > maxBottom) maxBottom = b + 1 - oy;
      // Dikey: tüm rakamlar için ortak ink merkezi kullanılacak.
    }
    final inkCenterY = (minTop + maxBottom) / 2;

    // 2) Şeridi çiz: yatayda her rakam kendi ink merkezine, dikeyde ortak ink merkezine göre hücre ortasına.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, cellW.toDouble(), totalH.toDouble()));
    for (var k = 0; k < 10; k++) {
      final tp = painterFor(k);
      final x = cellW / 2 - (inkL[k] + inkR[k]) / 2;
      final y = k * cellH + cellH / 2 - inkCenterY;
      tp.paint(canvas, Offset(x, y));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(cellW, totalH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();

    if (byteData == null) {
      throw StateError('Rakam şeridi PNG üretilemedi');
    }

    final pngBytes = byteData.buffer.asUint8List();
    final res = await PbsNativeBridge.makePar(
      pngBytes,
      width: cellW,
      height: totalH,
      a: true,
      exact: true,
    );
    return res.par;
  }
}
