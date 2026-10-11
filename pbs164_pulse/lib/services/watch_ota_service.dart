import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Saatin ayrı OTA GATT servisi (0xFF00: bildirim 0xFF01, yazma 0xFF02) üzerinden dosya gönderimi.
/// HryFine `OTAUtils` / `OTANotifyWriteUtils` / `CommandUtils` eşleniğidir ve gerçek bir HryFine
/// DIY kadran yüklemesinin HCI yakalamasıyla doğrulanmıştır (44 grup CRC'si ve dosya CRC'si birebir).
///
/// Çerçeveler:
///   kontrol: [0xD5, cmd, sub, op, 0, 0, lenH, lenL, payload..., toplam&0xFF]
///   veri:    [0xD6, ...parça]
/// Akış: START(op=1) -> saat 0x81 ile parametreleri bildirir -> her grup için veri çerçeveleri +
/// GROUP_CRC(op=2) -> saat 0x82 ile onaylar -> hepsi bitince FILE_CRC(op=3) -> saat 0x83.
class WatchOtaService {
  /// Ana komut: 2 = arka plan görseli (paper), alt komut: 1 = bekleme ekranı
  static const int cmdPaper = 2;
  static const int subPaperStandby = 1;

  static const int _dataHeader = 0xD5;
  static const int _errorHeader = 0xD6;
  static const int _opStart = 1;
  static const int _opGroupCrc = 2;
  static const int _opFileCrc = 3;

  final BluetoothDevice device;
  final BluetoothCharacteristic writeChar;
  final BluetoothCharacteristic notifyChar;
  final void Function(String) log;

  WatchOtaService({
    required this.device,
    required this.writeChar,
    required this.notifyChar,
    required this.log,
  });

  // Gelen çerçeve birleştirme
  final List<int> _rx = [];
  int _rxExpected = 0;
  StreamSubscription<List<int>>? _sub;
  Completer<Uint8List>? _waiter;
  int _waitOp = 0;

  /// CRC-8, polinom 0x31, MSB-önce, başlangıç 0 (HryFine `OTAUtils.sendData`).
  static int crc8(List<int> data, [int crc = 0]) {
    for (final b in data) {
      crc ^= b & 0xFF;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x80) != 0 ? ((crc << 1) ^ 0x31) & 0xFF : (crc << 1) & 0xFF;
      }
    }
    return crc & 0xFF;
  }

  /// Kontrol çerçevesi kurar (son bayt tüm baytların toplamı).
  static Uint8List controlFrame(int cmd, int sub, int op, [List<int> payload = const []]) {
    final f = Uint8List(9 + payload.length);
    f[0] = _dataHeader;
    f[1] = cmd;
    f[2] = sub;
    f[3] = op;
    f[6] = (payload.length >> 8) & 0xFF;
    f[7] = payload.length & 0xFF;
    f.setRange(8, 8 + payload.length, payload);
    var sum = 0;
    for (var i = 0; i < f.length - 1; i++) {
      sum += f[i];
    }
    f[f.length - 1] = sum & 0xFF;
    return f;
  }

  void _onNotify(List<int> data) {
    if (data.isEmpty) return;
    log("OTA RX [${data.length}B]: ${_hex(data)}");
    if (_rx.isEmpty) {
      if (data[0] == _errorHeader) {
        _fail("Saat OTA hatası bildirdi (0xD6)");
        return;
      }
      if (data[0] != _dataHeader || data.length < 8) return;
      _rxExpected = ((data[6] << 8) | data[7]) + 9;
    }
    _rx.addAll(data);
    if (_rx.length >= _rxExpected) {
      final frame = Uint8List.fromList(_rx.sublist(0, _rxExpected));
      _rx.clear();
      _rxExpected = 0;
      _onFrame(frame);
    }
  }

  void _onFrame(Uint8List f) {
    final op = f[3];
    final w = _waiter;
    if (w == null || w.isCompleted) return;
    // Yanıt op'u istek op'una 0x80 eklenmiş hâlidir.
    if (op == (_waitOp | 0x80)) {
      w.complete(f);
    }
  }

  void _fail(String msg) {
    final w = _waiter;
    if (w != null && !w.isCompleted) w.completeError(StateError(msg));
  }

  Future<Uint8List> _expect(int op, {Duration timeout = const Duration(seconds: 20)}) {
    _waiter = Completer<Uint8List>();
    _waitOp = op;
    return _waiter!.future.timeout(timeout, onTimeout: () {
      throw TimeoutException("Saat OTA yanıtı gelmedi (op=$op)");
    });
  }

  Future<void> _writeFrame(List<int> frame) async {
    await writeChar.write(frame, withoutResponse: true, allowLongWrite: false);
  }

  /// [data] dosyasını gönderir. [onProgress] 0..1 arası ilerleme verir.
  /// [prepare] / [restore]: UART bildirimlerini susturup geri açmak için çağıran taraf bağlar.
  Future<void> push({
    required Uint8List data,
    required Future<void> Function() prepare,
    required Future<void> Function() restore,
    void Function(double)? onProgress,
    int cmd = cmdPaper,
    int sub = subPaperStandby,
  }) async {
    try {
      await prepare();

      // MTU: HryFine 185 ister; çerçeve boyutu MTU-3.
      var mtu = device.mtuNow;
      if (mtu < 185) {
        try {
          mtu = await device.requestMtu(185);
        } catch (e) {
          log("MTU isteği başarısız: $e");
          mtu = device.mtuNow;
        }
      }
      log("OTA MTU=$mtu");
      if (mtu < 50) {
        throw StateError("MTU çok küçük ($mtu)");
      }

      await notifyChar.setNotifyValue(true);
      _sub = notifyChar.onValueReceived.listen(_onNotify);
      await Future.delayed(const Duration(milliseconds: 500));

      // 1) START
      final start = Uint8List.fromList([
        ((mtu - 3) >> 8) & 0xFF,
        (mtu - 3) & 0xFF,
        (data.length >> 24) & 0xFF,
        (data.length >> 16) & 0xFF,
        (data.length >> 8) & 0xFF,
        data.length & 0xFF,
      ]);
      final startReply = _expect(_opStart);
      await _writeFrame(controlFrame(cmd, sub, _opStart, start));
      final r = await startReply;
      if (r.length < 14) {
        throw StateError(r.length > 5 && r[5] == 13 ? "Görsel saatin sınırı için çok büyük" : "OTA başlatılamadı");
      }
      final deviceMtu = (r[8] << 8) | r[9];
      final sendInterval = ((r[10] << 8) | r[11]).clamp(5, 300);
      final groupSize = r[12] == 0 ? 1 : r[12];
      log("OTA parametreleri: çerçeve=$deviceMtu aralık=${sendInterval}ms grup=$groupSize");

      // 2) Veri: (deviceMtu-1) baytlık parçalar, groupSize'lık gruplar
      final chunk = deviceMtu - 1;
      final totalPackets = (data.length + chunk - 1) ~/ chunk;
      var sentPackets = 0;
      var fileCrc = 0;

      for (var base = 0; base < totalPackets; base += groupSize) {
        final end = (base + groupSize < totalPackets) ? base + groupSize : totalPackets;
        var groupCrc = 0;
        for (var p = base; p < end; p++) {
          final from = p * chunk;
          final to = (from + chunk < data.length) ? from + chunk : data.length;
          final piece = data.sublist(from, to);
          groupCrc = crc8(piece, groupCrc);
          fileCrc = crc8(piece, fileCrc);
          final frame = Uint8List(piece.length + 1);
          frame[0] = _errorHeader; // 0xD6: veri çerçevesi başlığı
          frame.setRange(1, frame.length, piece);
          await _writeFrame(frame);
          sentPackets++;
          onProgress?.call(sentPackets / totalPackets);
          await Future.delayed(Duration(milliseconds: sendInterval));
        }
        final ack = _expect(_opGroupCrc);
        await _writeFrame(controlFrame(cmd, sub, _opGroupCrc, [groupCrc]));
        final gr = await ack;
        if (gr[5] != 0) throw StateError("Grup CRC reddedildi (durum=${gr[5]})");
      }

      // 3) Dosya CRC'si
      final fin = _expect(_opFileCrc);
      await _writeFrame(controlFrame(cmd, sub, _opFileCrc, [fileCrc]));
      final fr = await fin;
      if (fr[5] != 0) throw StateError("Dosya CRC reddedildi (durum=${fr[5]})");
      log("OTA tamamlandı: ${data.length} bayt, $totalPackets paket");
      onProgress?.call(1.0);
    } finally {
      await _sub?.cancel();
      _sub = null;
      _waiter = null;
      try {
        await notifyChar.setNotifyValue(false);
      } catch (_) {}
      await restore();
    }
  }

  static String _hex(List<int> b) {
    final shown = b.length > 24 ? b.sublist(0, 24) : b;
    final s = shown.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
    return b.length > 24 ? "$s …" : s;
  }
}

@visibleForTesting
int otaCrc8(List<int> data) => WatchOtaService.crc8(data);
