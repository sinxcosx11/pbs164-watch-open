import 'dart:typed_data';
import '../models/health_models.dart';
import '../models/watch_face_models.dart';
import '../models/watch_features.dart';
import 'command_ids.dart';

/// Saatten gelen BLE paketlerini (0xFD ve 0xDF) çözümleyen motor.
/// `HealthUtils.java` ve `NotifyWriteUtils.java` mantığına dayanır.
class PbsResponseParser {
  /// Gelen ham baytları analiz edip uygun modeli veya tetikleyiciyi döndürür.
  ///
  /// [is8Bytes]: Saat 8 baytlık kadran kodu kullanıyorsa (özellik tablosundan) true.
  /// [resolutionRatio]: Kadran dosyası boyutlarını tahmin etmek için kullanılır.
  static dynamic parsePacket(Uint8List packet, {bool is8Bytes = false, int resolutionRatio = 0}) {
    if (packet.length < 5) return null;

    final header = packet[0];
    if (header != PbsCommandIds.ackHeader && header != PbsCommandIds.ackResponseHeader) {
      return null;
    }

    // 0. SAATTEN GELEN ACK (ONAY) PAKETİ (0xFD)
    // Paket formatı: [0xFD, LenH, LenL, Sum, CmdID, SubCmdID, StatusH, StatusL, Success(1)]
    if (header == PbsCommandIds.ackResponseHeader && packet.length >= 9) {
      final ackCmd = packet[4];
      final ackSub = packet[5];
      final isSuccess = packet[8] == 1;

      if (ackCmd == PbsCommandIds.cmdWatchFace) {
        return WatchFaceAck(
          cmdId: ackCmd,
          subCmdId: ackSub,
          success: isSuccess,
        );
      }
    }

    // 0xDF veya standart veri paketi
    // Paket yapısı: [Header, LenH, LenL, Checksum, CmdID, Version, SubCmd, DataLenH, DataLenL, Payload...]
    if (packet.length < 9) return null;

    final cmdId = packet[4];
    final subCmdId = packet[6];
    final payload = packet.length > 9 ? packet.sublist(9) : Uint8List(0);

    // 0.5 ÖZELLİK TABLOSU (Cmd 25): ilk bayt 0xAA
    if (cmdId == PbsCommandIds.cmdGetFeature && payload.isNotEmpty && payload[0] == 0xAA) {
      return WatchFeatures.parse(payload);
    }

    // 1. KADRAN VERİLERİ (Cmd 15)
    if (cmdId == PbsCommandIds.cmdWatchFace) {
      final codeLen = is8Bytes ? 8 : 2;
      String hexOf(List<int> l) => l.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

      // 1.0 Saat "arka planı gönder" diyor (Sub 6, ilk veri baytı 1)
      if (subCmdId == 6 && payload.isNotEmpty && payload[0] == 1) {
        return WatchFaceBgRequest();
      }

      // 1.1 Yüklü Kadran Listesi ve Aktif Kadran (Sub 2 veya Sub 9)
      if ((subCmdId == 2 || subCmdId == 9) && payload.isNotEmpty) {
        final dialCount = payload[0];
        var activeBytes = payload.length >= 1 + codeLen
            ? payload.sublist(1, 1 + codeLen)
            : (is8Bytes ? List<int>.filled(8, 0) : <int>[0x00, 0x80]);

        final installedHex = <String>[];
        final installedBytes = <List<int>>[];

        for (int i = 0; i < dialCount; i++) {
          final start = 1 + codeLen + (i * codeLen);
          final end = start + codeLen;
          if (end <= payload.length) {
            final code = payload.sublist(start, end);
            installedBytes.add(code);
            installedHex.add(hexOf(code));
          }
        }

        // HryFine: aktif kod listede yoksa 2 baytlı cihazlarda baytları ters çevirir.
        if (subCmdId == 9 && !is8Bytes && installedHex.isNotEmpty && !installedHex.contains(hexOf(activeBytes)) && payload.length >= 3) {
          activeBytes = [payload[2], payload[1]];
        }

        // Dosya boyutu sınırları (paper/dial)
        int u32(int off) => (payload[off] << 24) | (payload[off + 1] << 16) | (payload[off + 2] << 8) | payload[off + 3];
        var paperSize = 0;
        var dialSize = 0;
        if (subCmdId == 9 && payload.length >= 8) {
          paperSize = u32(payload.length - 8);
          dialSize = u32(payload.length - 4);
        } else if (resolutionRatio == 1) {
          dialSize = 266240;
          paperSize = 118784;
        } else if (resolutionRatio == 2) {
          dialSize = 90112;
          paperSize = 32768;
        } else if (resolutionRatio >= 16 && payload.length >= 8) {
          paperSize = u32(payload.length - 8);
          dialSize = u32(payload.length - 4);
        }

        return WatchFaceListRecord(
          dialCount: dialCount,
          activeCodeHex: hexOf(activeBytes),
          activeCodeBytes: activeBytes,
          installedCodesHex: installedHex,
          installedCodesBytes: installedBytes,
          paperSize: paperSize,
          dialSize: dialSize,
        );
      }

      // 1.2 Özelleştirilebilir Kadran Bilgisi (Sub 5)
      if (subCmdId == 5 && payload.length >= codeLen + 9) {
        final o = codeLen; // koordinatların başladığı ofset
        final faceBytes = payload.sublist(0, codeLen);
        final faceHex = hexOf(faceBytes);
        final timeX = (payload[o] << 8) | payload[o + 1];
        final timeY = (payload[o + 2] << 8) | payload[o + 3];
        final color = (payload[o + 4] << 8) | payload[o + 5];
        final above = payload[o + 6];
        final below = payload[o + 7];
        final bgUpdate = payload[o + 8];

        return CustomWatchFaceRecord(
          faceCodeHex: faceHex,
          faceCodeBytes: faceBytes,
          timeX: timeX,
          timeY: timeY,
          colorRgb565: color,
          aboveWidget: above,
          belowWidget: below,
          bgUpdate: bgUpdate,
        );
      }
    }

    // 2. CİHAZ KONTROL TETİKLEYİCİLERİ (Cmd 12)
    if (cmdId == PbsCommandIds.cmdDeviceControl) {
      if (subCmdId == 1 || subCmdId == 12) {
        return DeviceTriggerType.cameraShutter;
      } else if (subCmdId == 2 || subCmdId == 11) {
        return DeviceTriggerType.findPhone;
      }
    }

    // 3. SPOR VE SAĞLIK GEÇMİŞ / SENKRON VERİLERİ (Cmd 5)
    if (cmdId == PbsCommandIds.cmdSportInfo) {
      return _parseSportData(subCmdId, payload);
    }

    // 4. ANLIK SENSÖR ÖLÇÜM VEYA AYAR YANITLARI (Cmd 2)
    if (cmdId == PbsCommandIds.cmdSettingOrder && payload.isNotEmpty) {
      // 4.1 Anlık Nabız (Sub 13)
      if (subCmdId == PbsCommandIds.subSwitchHeart) {
        final bpm = payload[0];
        if (bpm > 30 && bpm < 220) {
          return HeartRateRecord(bpm: bpm);
        }
      }
      // 4.2 Anlık Tansiyon (Sub 14)
      else if (subCmdId == PbsCommandIds.subSwitchBloodPressure) {
        if (payload.length >= 2) {
          final sys = payload[0];
          final dia = payload[1];
          if (sys >= 50 && sys <= 250 && dia >= 30 && dia <= 180) {
            return BloodPressureRecord(systolic: sys, diastolic: dia);
          }
        }
      }
      // 4.3 Anlık Kandaki Oksijen SpO2 (Sub 28)
      else if (subCmdId == PbsCommandIds.subSwitchBloodOxygen) {
        final spo2 = payload[0];
        if (spo2 >= 70 && spo2 <= 100) {
          return BloodOxygenRecord(percentage: spo2);
        }
      }
    }

    return null;
  }

  static dynamic _parseSportData(int subCmd, Uint8List payload) {
    switch (subCmd) {
      // Nabız Verisi (Sub 4)
      case PbsCommandIds.sportSyncHeartHistory:
        if (payload.isNotEmpty) {
          final bpm = payload[payload.length - 1];
          if (bpm > 30 && bpm < 220) {
            return HeartRateRecord(bpm: bpm);
          }
        }
        break;

      // Tansiyon Verisi (Sub 5)
      case PbsCommandIds.sportSyncBloodHistory:
        if (payload.length >= 12) {
          final count = payload[3];
          if (count > 0 && payload.length >= 4 + (count * 8)) {
            final lastEntryStart = 4 + ((count - 1) * 8);
            final sys = payload[lastEntryStart + 6];
            final dia = payload[lastEntryStart + 7];
            if (sys >= 50 && dia >= 30) {
              return BloodPressureRecord(systolic: sys, diastolic: dia);
            }
          }
        } else if (payload.length >= 2) {
          final systolic = payload[0];
          final diastolic = payload[1];
          if (systolic >= 50 && diastolic >= 30) {
            return BloodPressureRecord(systolic: systolic, diastolic: diastolic);
          }
        }
        break;

      // Kandaki Oksijen SpO2 (Sub 14)
      case 14:
        if (payload.length >= 12) {
          final spo2 = payload[11];
          if (spo2 >= 70 && spo2 <= 100) {
            return BloodOxygenRecord(percentage: spo2);
          }
        } else if (payload.isNotEmpty) {
          final spo2 = payload[payload.length - 1];
          if (spo2 >= 70 && spo2 <= 100) {
            return BloodOxygenRecord(percentage: spo2);
          }
        }
        break;

      // Adım, Mesafe ve Kalori Verisi (Sub 12, 10, 6, 8 veya 2)
      // StepUtils.java: getTotalStepData
      case 12: // KEY_SYNC_REAL_TIME_STEP
      case PbsCommandIds.sportRealTimeStepSwitch: // 6
      case PbsCommandIds.sportSyncTodayHistory:   // 10
      case PbsCommandIds.sportSyncStepHistory:    // 2
        if (payload.length >= 12) {
          final steps = (payload[0] << 24) |
                        (payload[1] << 16) |
                        (payload[2] << 8)  |
                        payload[3];

          final dist = ((payload[4] << 24) |
                        (payload[5] << 16) |
                        (payload[6] << 8)  |
                        payload[7]).toDouble();

          final cal = ((payload[8] << 24) |
                       (payload[9] << 16) |
                       (payload[10] << 8) |
                       payload[11]).toDouble();

          if (steps >= 0 && steps < 250000) {
            return StepRecord(
              steps: steps,
              calories: cal,
              distanceMeters: dist,
            );
          }
        } else if (payload.length >= 8) {
          final steps = (payload[0] << 24) |
                        (payload[1] << 16) |
                        (payload[2] << 8)  |
                        payload[3];

          final cal = ((payload[4] << 8) | payload[5]).toDouble();
          final dist = ((payload[6] << 8) | payload[7]).toDouble();

          if (steps >= 0 && steps < 250000) {
            return StepRecord(
              steps: steps,
              calories: cal,
              distanceMeters: dist,
            );
          }
        }
        break;

      // Uyku Verisi (Sub 3)
      case PbsCommandIds.sportSyncSleepHistory:
        if (payload.length >= 4) {
          final deep = (payload[0] << 8) | payload[1];
          final light = (payload[2] << 8) | payload[3];
          return SleepRecord(
            totalMinutes: deep + light,
            deepMinutes: deep,
            lightMinutes: light,
          );
        }
        break;
    }
    return null;
  }
}
