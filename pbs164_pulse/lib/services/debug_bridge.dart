import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../protocol/pbs164_protocol.dart';
import 'ble_service.dart';
import 'native_bridge.dart';

/// Geliştirme aracı: uygulamanın harici dosya klasöründeki `cmd.txt` dosyasını
/// izler ve içindeki komutları saate gönderir (adb push ile tetiklenir).
/// Yalnızca debug derlemelerde çalışır; sonuçlar logcat'te `PBSLOG` olarak görünür.
///
/// Komutlar (satır başına bir tane, `#` yorum):
///   hex <bayt dizisi>            tam çerçeveyi olduğu gibi gönder
///   pkt <cmd> <sub> [payload]    checksum'lı paket kur ve gönder (cmd/sub ondalık veya 0x..)
///   q features|faces|custom      sorgular
///   setcustom <kod> <x> <y> <renk> <üst> <alt> <bg>
///   switch <kod>                 0x0F/0x03
///   sleep <ms>
///   log <metin>
class PbsDebugBridge {
  static const _dir = '/data/user/0/com.pbs164.pbs164_pulse/files';
  static Timer? _timer;
  static bool _busy = false;

  static void start(PbsBleService ble) {
    if (!kDebugMode || _timer != null) return;
    try {
      Directory(_dir).createSync(recursive: true);
    } catch (e) {
      debugPrint('PBSLOG debug köprüsü klasörü açılamadı: $e');
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) => _poll(ble));
    debugPrint('PBSLOG debug köprüsü hazır: $_dir/cmd.txt');
  }

  static Future<void> _poll(PbsBleService ble) async {
    if (_busy) return;
    final file = File('$_dir/cmd.txt');
    if (!file.existsSync()) return;
    _busy = true;
    try {
      final lines = file.readAsLinesSync();
      file.deleteSync();
      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        await _run(ble, line);
      }
    } catch (e) {
      debugPrint('PBSLOG debug komut hatası: $e');
    } finally {
      _busy = false;
    }
  }

  static int _int(String s) => s.toLowerCase().startsWith('0x') ? int.parse(s.substring(2), radix: 16) : int.parse(s);

  static List<int> _hex(String s) {
    final clean = s.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    return [for (var i = 0; i + 1 < clean.length; i += 2) int.parse(clean.substring(i, i + 2), radix: 16)];
  }

  static Future<void> _run(PbsBleService ble, String line) async {
    final p = line.split(RegExp(r'\s+'));
    debugPrint('PBSLOG >> $line');
    switch (p[0]) {
      case 'hex':
        await ble.sendPacket(Uint8List.fromList(_hex(p.sublist(1).join())));
        break;
      case 'pkt':
        await ble.sendPacket(Pbs164Protocol.buildPacket(_int(p[1]), _int(p[2]), p.length > 3 ? _hex(p.sublist(3).join()) : const []));
        break;
      case 'q':
        if (p[1] == 'features') await ble.refreshFeatures();
        if (p[1] == 'faces') await ble.queryWatchFaces();
        if (p[1] == 'custom') await ble.queryCustomWatchFace();
        break;
      case 'setcustom':
        await ble.sendPacket(Pbs164Protocol.setCustomWatchFace(
          faceCode: _hex(p[1]),
          timeX: _int(p[2]),
          timeY: _int(p[3]),
          colorRgb565: _int(p[4]),
          aboveWidget: _int(p[5]),
          belowWidget: _int(p[6]),
          bgUpdate: _int(p[7]),
        ));
        break;
      case 'diy':
        // diy <x> <y> <renk> <üst> <alt> [görsel yolu (uygulama klasörüne göre)]
        Uint8List? par;
        if (p.length > 6) {
          final img = File('$_dir/${p[6]}').readAsBytesSync();
          final f = ble.features;
          final size = f?.screenSize ?? (240, 298);
          final maxBytes = ble.watchFaces?.paperSize ?? 0;
          debugPrint('PBSLOG PAR dönüştürülüyor: ${img.length}B ${size.$1}x${size.$2} sınır=$maxBytes');
          final r = await PbsNativeBridge.makePar(img, width: size.$1, height: size.$2, maxBytes: maxBytes);
          par = r.par;
          debugPrint('PBSLOG PAR hazır: ${par.length}B kalite=${r.quality} başlık=${par.sublist(0, 16).map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');
          File('$_dir/last.par').writeAsBytesSync(par);
        }
        final res = await ble.applyDiyFace(
          timeX: _int(p[1]),
          timeY: _int(p[2]),
          colorRgb565: _int(p[3]),
          aboveWidget: _int(p[4]),
          belowWidget: _int(p[5]),
          par: par,
          onProgress: (s, v) => debugPrint('PBSLOG DIY ${(v * 100).toStringAsFixed(0)}% $s'),
        );
        debugPrint('PBSLOG DIY SONUÇ ok=${res.ok} ${res.message}');
        break;
      case 'par':
        // par <png> <w> <h> [a b c]  -> <png>.par üretir (BLE gerekmez)
        final src = File('$_dir/${p[1]}').readAsBytesSync();
        final pw = _int(p[2]);
        final ph = _int(p[3]);
        final fa = p.length > 4 && p[4] == '1';
        final fb = p.length > 5 && p[5] == '1';
        final fc = p.length > 6 && p[6] == '1';
        final pr = await PbsNativeBridge.makePar(src, width: pw, height: ph, a: fa, b: fb, c: fc, exact: true);
        File('$_dir/${p[1]}.${fa ? 1 : 0}${fb ? 1 : 0}${fc ? 1 : 0}.par').writeAsBytesSync(pr.par);
        debugPrint('PBSLOG PAR ${p[1]} ${pw}x$ph flags=${fa ? 1 : 0}${fb ? 1 : 0}${fc ? 1 : 0} -> ${pr.par.length}B');
        break;
      case 'dial':
        // dial <dosya>  (uygulama klasöründeki WF kadran dosyasını OTA ile gönderir)
        final bytes = File('$_dir/${p[1]}').readAsBytesSync();
        debugPrint('PBSLOG KADRAN gönderiliyor: ${p[1]} ${bytes.length}B');
        final r = await ble.pushDialFile(bytes, onProgress: (st, v) => debugPrint('PBSLOG DIAL ${(v * 100).toStringAsFixed(0)}% $st'));
        debugPrint('PBSLOG DIAL SONUÇ ok=${r.ok} ${r.message}');
        break;
      case 'switch':
        await ble.switchInternalWatchFace(_hex(p[1]));
        break;
      case 'sleep':
        await Future.delayed(Duration(milliseconds: _int(p[1])));
        break;
      case 'log':
        debugPrint('PBSLOG ${p.sublist(1).join(' ')}');
        break;
      default:
        debugPrint('PBSLOG bilinmeyen debug komutu: ${p[0]}');
    }
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
