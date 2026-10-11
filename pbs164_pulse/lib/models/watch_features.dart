/// Saatin bildirdiği özellik tablosu (HryFine `NotifyWriteUtils.readFeatures` eşleniği).
/// 0x2A28 (DEVICE_FUNCTION_READ) karakteristiğinden veya `0x19` komut yanıtından gelir.
/// İlk bayt her zaman 0xAA'dır.
class WatchFeatures {
  final List<int> raw;
  final bool valid;

  // Kadran yetenekleri (bayt 2)
  final bool supportWatchFaceSet;
  final bool supportCustomize;
  final bool supportPush;
  final bool choosePaper;
  final int resolutionRatio;
  final int screenShape;

  // Gelişmiş kadran bayrakları (bayt 16-18)
  final bool isOta;
  final int codeFormat;
  final bool supportDiyOnlineWallpaper;
  final bool supportDiyDefaultReset;
  final bool is565Bmp;
  final bool is8Bytes;
  final bool binPreviewFlag;

  // Genel
  final bool isSdkDevice;
  final bool supportDeviceInfo;
  final bool isBlePairCode;

  const WatchFeatures({
    required this.raw,
    required this.valid,
    this.supportWatchFaceSet = false,
    this.supportCustomize = false,
    this.supportPush = false,
    this.choosePaper = true,
    this.resolutionRatio = 0,
    this.screenShape = 0,
    this.isOta = false,
    this.codeFormat = 0,
    this.supportDiyOnlineWallpaper = false,
    this.supportDiyDefaultReset = false,
    this.is565Bmp = false,
    this.is8Bytes = false,
    this.binPreviewFlag = true,
    this.isSdkDevice = false,
    this.supportDeviceInfo = false,
    this.isBlePairCode = false,
  });

  /// Kadran kodu uzunluğu: 8 baytlı cihazlarda 8, diğerlerinde 2.
  int get faceCodeLength => is8Bytes ? 8 : 2;

  /// Ekran çözünürlüğü (HryFine `getBufferLength` tablosu: genişlik x yükseklik).
  /// Tanınmayan kodlarda 240x240 varsayılır.
  (int, int) get screenSize {
    switch (resolutionRatio) {
      case 1:
        return (240, 320);
      case 2:
        return (80, 160);
      case 3:
        return (128, 128);
      case 4:
        return (240, 280);
      case 7:
        return (160, 80);
      case 8:
        return (128, 160);
      case 9:
        return (172, 320);
      case 10:
        return (240, 286);
      case 11:
        return (240, 284);
      case 12:
        return (240, 283);
      case 13:
        return (240, 297);
      case 14:
        return (240, 288);
      case 15:
        return (240, 292);
      case 16:
        return (240, 298);
      case 17:
        return (360, 360);
      case 19:
        return (200, 320);
      default:
        return (240, 240);
    }
  }

  static WatchFeatures parse(List<int> b) {
    if (b.isEmpty || b[0] != 0xAA) {
      return WatchFeatures(raw: List.unmodifiable(b), valid: false);
    }
    bool bit(int idx, int mask) => b.length > idx && (b[idx] & mask) == mask;

    var ratio = b.length >= 3 ? (b[2] & 0x0F) : 0;
    if (b.length >= 17 && (b[16] & 63) != 0) {
      ratio = (b[16] & 63) + 15;
    }
    final codeFormat = b.length >= 18 ? (b[17] & 0xFF) : 0;
    final has19 = b.length >= 19;

    return WatchFeatures(
      raw: List.unmodifiable(b),
      valid: true,
      supportWatchFaceSet: bit(2, 0x80),
      supportCustomize: bit(2, 0x40),
      supportPush: bit(2, 0x20),
      choosePaper: b.length >= 3 ? (b[2] & 0x10) != 0x10 : true,
      resolutionRatio: ratio,
      screenShape: b.length >= 4 ? (b[3] & 0x0F) : 0,
      isOta: bit(16, 0x40),
      codeFormat: codeFormat,
      supportDiyOnlineWallpaper: has19 && bit(18, 0x02),
      supportDiyDefaultReset: has19 && bit(18, 0x01),
      is565Bmp: has19 && codeFormat == 8 && bit(18, 0x80),
      is8Bytes: has19 && codeFormat == 8 && bit(18, 0x40),
      binPreviewFlag: has19 && codeFormat == 8 ? bit(18, 0x20) : true,
      isSdkDevice: bit(15, 0x10),
      supportDeviceInfo: bit(15, 0x20),
      isBlePairCode: bit(28, 0x08),
    );
  }

  String get hex => raw.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');

  /// Kullanıcıya gösterilecek özet.
  String summary() {
    if (!valid) return 'Özellik tablosu okunamadı';
    final s = screenSize;
    return 'Kadran seçimi: ${_yn(supportWatchFaceSet)}  |  Özel kadran: ${_yn(supportCustomize)}  |  '
        'Arka plan gönderimi (OTA): ${_yn(supportPush)}\n'
        'Çözünürlük kodu: $resolutionRatio (${s.$1}x${s.$2})  |  Şekil: $screenShape\n'
        'codeFormat: $codeFormat  |  565Bmp: ${_yn(is565Bmp)}  |  8 bayt kod: ${_yn(is8Bytes)}';
  }

  static String _yn(bool v) => v ? 'EVET' : 'hayır';
}
