import 'dart:typed_data';

/// PBS 164 / HryFine 'WF' Kadran Biçimi Kaydı.
class WfRecord {
  Uint8List raw; // 16 bayt
  List<Uint8List> images; // PAR görselleri

  WfRecord(this.raw, this.images);

  int get type => raw[0];
  set type(int v) => raw[0] = v & 0xFF;

  int get id => raw[1];
  set id(int v) => raw[1] = v & 0xFF;

  int get count {
    return raw.buffer.asByteData(raw.offsetInBytes, 16).getUint16(2, Endian.little);
  }

  set count(int v) {
    raw.buffer.asByteData(raw.offsetInBytes, 16).setUint16(2, v, Endian.little);
  }

  int get x {
    return raw.buffer.asByteData(raw.offsetInBytes, 16).getUint16(4, Endian.little);
  }

  set x(int v) {
    raw.buffer.asByteData(raw.offsetInBytes, 16).setUint16(4, v, Endian.little);
  }

  int get y {
    return raw.buffer.asByteData(raw.offsetInBytes, 16).getUint16(6, Endian.little);
  }

  set y(int v) {
    raw.buffer.asByteData(raw.offsetInBytes, 16).setUint16(6, v, Endian.little);
  }

  WfRecord copyWith({int? x, int? y, int? count, List<Uint8List>? images}) {
    final newRaw = Uint8List.fromList(raw);
    final rec = WfRecord(newRaw, images != null ? List.from(images) : List.from(this.images));
    if (x != null) rec.x = x;
    if (y != null) rec.y = y;
    if (count != null) rec.count = count;
    return rec;
  }

  @override
  String toString() => 'WfRecord(type=$type, id=0x${id.toRadixString(16).padLeft(2, '0')}, count=$count, pos=($x,$y), imgs=${images.length})';
}

/// PBS 164 / HryFine 'WF' Kadran Konteyneri (Ayrıştırıcı ve Derleyici).
class WfDial {
  int version = 0x03fc;
  Uint8List id = Uint8List(8);
  int w = 240;
  int h = 298;
  int extra = 0;
  Uint8List hdrTail = Uint8List(8);
  List<WfRecord> records = [];

  WfDial();

  static List<Uint8List> splitPars(Uint8List blob) {
    final starts = <int>[];
    var i = 0;
    while (i + 12 <= blob.length) {
      if (blob[i] == 0x50 && blob[i + 1] == 0x41) {
        // 'PA'
        final bd = blob.buffer.asByteData(blob.offsetInBytes, blob.length);
        final w = bd.getUint16(i + 4, Endian.little);
        final h = bd.getUint16(i + 6, Endian.little);
        if (w > 0 && w <= 2048 && h > 0 && h <= 4096) {
          if (starts.isEmpty || (i - starts.last) > 40) {
            starts.add(i);
          }
        }
      }
      i++;
    }
    final out = <Uint8List>[];
    for (var k = 0; k < starts.length; k++) {
      final s = starts[k];
      final e = (k + 1 < starts.length) ? starts[k + 1] : blob.length;
      out.add(Uint8List.fromList(blob.sublist(s, e)));
    }
    return out;
  }

  static WfDial parse(Uint8List data) {
    if (data.length < 0x1a || data[0] != 0x57 || data[1] != 0x46) {
      throw FormatException('Geçersiz WF kadran imzası');
    }
    final bd = data.buffer.asByteData(data.offsetInBytes, data.length);
    final dial = WfDial();
    dial.version = bd.getUint16(2, Endian.little);
    dial.id = Uint8List.fromList(data.sublist(4, 12));
    dial.w = bd.getUint16(12, Endian.little);
    dial.h = bd.getUint16(14, Endian.little);
    final cnt = data[16];
    dial.extra = data[17];
    dial.hdrTail = Uint8List.fromList(data.sublist(18, 26));

    final n = cnt - dial.extra;
    var pos = 0x1a;
    final raws = <Uint8List>[];
    final ptrs = <int>[];

    for (var i = 0; i < n; i++) {
      raws.add(Uint8List.fromList(data.sublist(pos, pos + 16)));
      if (i < n - 1) {
        ptrs.add(bd.getUint32(pos + 16, Endian.little));
        pos += 20;
      } else {
        pos += 16;
      }
    }

    final tableEnd = pos;
    final starts = <int>[tableEnd, ...ptrs];
    final ends = <int>[];
    for (var i = 0; i < n; i++) {
      int? nextStart;
      for (var s = i + 1; s < starts.length; s++) {
        if (starts[s] > starts[i]) {
          nextStart = starts[s];
          break;
        }
      }
      ends.add(nextStart ?? data.length);
    }

    for (var i = 0; i < n; i++) {
      List<Uint8List> imgs = [];
      if (i < n - 1 && starts[i + 1] == starts[i]) {
        imgs = [];
      } else {
        if (starts[i] < ends[i]) {
          final blob = Uint8List.fromList(data.sublist(starts[i], ends[i]));
          imgs = splitPars(blob);
        }
      }
      dial.records.add(WfRecord(raws[i], imgs));
    }

    return dial;
  }

  Uint8List build() {
    final builder = BytesBuilder();
    final n = records.length;

    // Başlık
    final hdr = Uint8List(26);
    final hbd = ByteData.sublistView(hdr);
    hdr[0] = 0x57; // 'W'
    hdr[1] = 0x46; // 'F'
    hbd.setUint16(2, version, Endian.little);
    hdr.setRange(4, 12, id);
    hbd.setUint16(12, w, Endian.little);
    hbd.setUint16(14, h, Endian.little);
    hdr[16] = (n + extra) & 0xFF;
    hdr[17] = extra & 0xFF;
    hdr.setRange(18, 26, hdrTail);
    builder.add(hdr);

    final tableEnd = 0x1a + (n - 1) * 20 + 16;
    var pos = tableEnd;
    final starts = <int>[];
    final blobs = <Uint8List>[];

    for (final rec in records) {
      starts.add(pos);
      final blobBuilder = BytesBuilder();
      for (final img in rec.images) {
        blobBuilder.add(img);
      }
      final blob = blobBuilder.toBytes();
      blobs.add(blob);
      pos += blob.length;
    }

    // Tablo (N-1 adet 20 bayt + 1 adet 16 bayt)
    for (var i = 0; i < n; i++) {
      builder.add(records[i].raw);
      if (i < n - 1) {
        final ptr = Uint8List(4);
        ByteData.sublistView(ptr).setUint32(0, starts[i + 1], Endian.little);
        builder.add(ptr);
      }
    }

    // Veriler
    for (final b in blobs) {
      builder.add(b);
    }

    return builder.toBytes();
  }
}
