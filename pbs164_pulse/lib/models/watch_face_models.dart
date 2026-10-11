/// PBS 164 Kadran (Watch Face) ve Protokol Modelleri
/// HryFine'ın `WatchFaceBean`, `CustomizeWatchFaceBean` ve `handleAck` Dart eşleniğidir.

class WatchFaceListRecord {
  final int dialCount;
  final String activeCodeHex;
  final List<int> activeCodeBytes;
  final List<String> installedCodesHex;
  final List<List<int>> installedCodesBytes;

  /// Arka plan görseli (paper) ve kadran dosyası için saatin kabul ettiği azami bayt.
  /// Saat bildirmediyse 0.
  final int paperSize;
  final int dialSize;

  WatchFaceListRecord({
    required this.dialCount,
    required this.activeCodeHex,
    required this.activeCodeBytes,
    required this.installedCodesHex,
    required this.installedCodesBytes,
    this.paperSize = 0,
    this.dialSize = 0,
  });

  @override
  String toString() =>
      "WatchFaceListRecord(count: $dialCount, active: $activeCodeHex, dials: $installedCodesHex)";
}

class CustomWatchFaceRecord {
  final String faceCodeHex;
  final List<int> faceCodeBytes;
  final int timeX;
  final int timeY;
  final int colorRgb565;
  final int aboveWidget;
  final int belowWidget;
  final int bgUpdate;

  CustomWatchFaceRecord({
    required this.faceCodeHex,
    required this.faceCodeBytes,
    required this.timeX,
    required this.timeY,
    required this.colorRgb565,
    required this.aboveWidget,
    required this.belowWidget,
    required this.bgUpdate,
  });

  @override
  String toString() =>
      "CustomWatchFaceRecord(code: $faceCodeHex, x: $timeX, y: $timeY, color: 0x${colorRgb565.toRadixString(16)}, above: $aboveWidget, below: $belowWidget, bgUpdate: $bgUpdate)";
}

/// Saatin 0x0F/0x06 bildirimi: yeni DIY arka planı hazır, OTA ile göndermeye başla.
/// (HryFine `ACTION_CUSTOM_WATCH_FACE_UPDATE` tetikleyicisi)
class WatchFaceBgRequest {
  final DateTime timestamp = DateTime.now();
}

class WatchFaceAck {
  final int cmdId; // 15
  final int subCmdId; // 3 (switch dial) veya 5 (set custom dial)
  final bool success;
  final DateTime timestamp;

  WatchFaceAck({
    required this.cmdId,
    required this.subCmdId,
    required this.success,
  }) : timestamp = DateTime.now();

  @override
  String toString() =>
      "WatchFaceAck(cmd: $cmdId, sub: $subCmdId, success: $success)";
}
