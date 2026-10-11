import 'dart:ui';

/// 16-bit RGB565 renk dönüşümleri (saatin yazı rengi biçimi).
class Rgb565 {
  static int fromColor(Color c) {
    final v = c.toARGB32();
    final r = (v >> 16) & 0xFF;
    final g = (v >> 8) & 0xFF;
    final b = v & 0xFF;
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
  }

  static Color toColor(int v) {
    final r = (v >> 11) & 0x1F;
    final g = (v >> 5) & 0x3F;
    final b = v & 0x1F;
    return Color.fromARGB(255, (r * 255) ~/ 31, (g * 255) ~/ 63, (b * 255) ~/ 31);
  }

  /// Saatin gerçekte göstereceği (kuantize edilmiş) renk.
  static Color quantize(Color c) => toColor(fromColor(c));
}
