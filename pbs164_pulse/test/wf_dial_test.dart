import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbs164_pulse/protocol/wf_dial.dart';

void main() {
  test('WfDial round-trip parse and build matches original byte-for-byte', () {
    final bytes = File('assets/templates/tmpl_base.bin').readAsBytesSync();
    expect(bytes.length, equals(30508));
    final dial = WfDial.parse(bytes);
    expect(dial.records.length, equals(12));
    final rebuilt = dial.build();
    expect(rebuilt.length, equals(bytes.length));
    for (var i = 0; i < bytes.length; i++) {
      if (rebuilt[i] != bytes[i]) {
        fail('Mismatch at byte $i: expected 0x${bytes[i].toRadixString(16)}, got 0x${rebuilt[i].toRadixString(16)}');
      }
    }
  });
}
