import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Android Yerel Köprü Servisi (MethodChannel)
class PbsNativeBridge {
  static const MethodChannel _channel = MethodChannel('com.pbs164.pulse/native');

  /// Sesli Asistan Başlat (google, gemini, chatgpt)
  static Future<bool> launchAssistant(String type) async {
    try {
      final res = await _channel.invokeMethod<bool>('launchAssistant', {'type': type});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Telefonun Bluetooth Ayarlarını Aç (BT 3.0 Çağrı / Ses Eşleştirmesi İçin)
  static Future<void> openBluetoothSettings() async {
    try {
      await _channel.invokeMethod('openBluetoothSettings');
    } catch (_) {}
  }

  /// Telefonu Bul Tetikleyicisi (Saatten Basıldığında Telefonu Çaldır & Titret)
  static Future<void> ringPhone() async {
    try {
      await _channel.invokeMethod('ringPhone');
    } catch (_) {}
  }

  /// Görseli (PNG/JPEG baytları) saatin PAR arka plan biçimine çevirir.
  /// [maxBytes] saatin kabul ettiği azami dosya boyutudur (0 = sınırsız); aşılırsa kalite düşürülür.
  /// Dönüş: {par: Uint8List, quality: int}
  static Future<({Uint8List par, int quality})> makePar(
    Uint8List image, {
    required int width,
    required int height,
    int maxBytes = 0,
    bool a = false,
    bool b = false,
    bool c = false,
    bool exact = false,
  }) async {
    final res = await _channel.invokeMethod<Map>('makePar', {
      'image': image,
      'width': width,
      'height': height,
      'maxBytes': maxBytes,
      'a': a,
      'b': b,
      'c': c,
      'exact': exact,
    });
    return (par: res!['par'] as Uint8List, quality: res['quality'] as int);
  }

  /// Telefon Çalmasını Durdur
  static Future<void> stopRingPhone() async {
    try {
      await _channel.invokeMethod('stopRingPhone');
    } catch (_) {}
  }
}
