import 'package:flutter/material.dart';

/// DIY kadranda saatin üstünde/altında gösterilebilen bilgi (HryFine `getConvertWhich` kodları).
enum WatchWidgetType {
  none(0, 'Kapalı', Icons.block),
  date(1, 'Tarih', Icons.calendar_today_rounded),
  sleep(2, 'Uyku', Icons.bedtime_rounded),
  heart(3, 'Nabız', Icons.favorite_rounded),
  steps(4, 'Adım', Icons.directions_walk_rounded);

  final int code;
  final String label;
  final IconData icon;
  const WatchWidgetType(this.code, this.label, this.icon);

  static WatchWidgetType fromCode(int code) =>
      WatchWidgetType.values.firstWhere((e) => e.code == code, orElse: () => WatchWidgetType.none);
}

/// Fotoğraf yerine kullanılabilen hazır arka planlar (gönderirken görsele çevrilir).
class BackgroundPreset {
  final String name;
  final Gradient gradient;
  const BackgroundPreset(this.name, this.gradient);
}

const List<BackgroundPreset> kBackgroundPresets = [
  BackgroundPreset(
    'Siyah',
    LinearGradient(colors: [Color(0xFF000000), Color(0xFF000000)]),
  ),
  BackgroundPreset(
    'Gece Mavisi',
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0B1B3A), Color(0xFF02060F)],
    ),
  ),
  BackgroundPreset(
    'Siber',
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0D0221), Color(0xFF190061), Color(0xFF0F051D)],
    ),
  ),
  BackgroundPreset(
    'Gün Batımı',
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2A0845), Color(0xFFB4235C), Color(0xFFFF8A3D)],
    ),
  ),
  BackgroundPreset(
    'Orman',
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF021B14), Color(0xFF0B5D3B), Color(0xFF031A0F)],
    ),
  ),
  BackgroundPreset(
    'Karbon',
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1B1B1B), Color(0xFF2E0808), Color(0xFF111111)],
    ),
  ),
];
