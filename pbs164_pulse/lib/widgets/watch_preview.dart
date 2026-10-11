import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../models/diy_widgets.dart';

/// Saat ekranının gerçek piksel ölçeğinde canlı önizlemesi.
///
/// İçeriği "saat pikseli" koordinatlarında (ör. 240x298) çizer ve ekrana sığacak şekilde büyütür.
/// [background] bir [RepaintBoundary] içindedir; gönderirken yalnızca arka plan yakalanır, saatin
/// kendi çizdiği yazı (zaman + bilgi satırları) yakalanmaz.
class WatchPreview extends StatelessWidget {
  /// Saat bloğunun yaklaşık ölçüsü (HryFine konum sınırlarından çıkarıldı: X<=140, Y<=198).
  static const double blockWidth = 100;
  static const double infoRowHeight = 22;
  static const double timeHeight = 56;

  final int watchW;
  final int watchH;
  final double scale;
  final GlobalKey captureKey;
  final Widget background;
  final bool backgroundInteractive;

  final double timeX;
  final double timeY;
  final Color textColor;
  final WatchWidgetType above;
  final WatchWidgetType below;
  final bool moveMode;
  final void Function(double dx, double dy) onMove;

  final String timeText;
  final Map<WatchWidgetType, String> infoValues;
  final String? fontFamily;
  final FontWeight fontWeight;
  final bool isStacked;
  final bool isMinimalist;

  const WatchPreview({
    super.key,
    required this.watchW,
    required this.watchH,
    required this.scale,
    required this.captureKey,
    required this.background,
    required this.backgroundInteractive,
    required this.timeX,
    required this.timeY,
    required this.textColor,
    required this.above,
    required this.below,
    required this.moveMode,
    required this.onMove,
    required this.timeText,
    required this.infoValues,
    this.fontFamily,
    this.fontWeight = FontWeight.w700,
    this.isStacked = false,
    this.isMinimalist = true,
  });

  static double blockHeight(WatchWidgetType above, WatchWidgetType below) =>
      timeHeight + (above == WatchWidgetType.none ? 0 : infoRowHeight) + (below == WatchWidgetType.none ? 0 : infoRowHeight);

  @override
  Widget build(BuildContext context) {
    final w = watchW * scale;
    final h = watchH * scale;
    const bezel = 9.0;
    final corner = 34.0 * scale;

    return SizedBox(
      width: w + bezel * 2 + 8,
      height: h + bezel * 2,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Saat gövdesi
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: w + bezel * 2,
              height: h + bezel * 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(corner + bezel),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2B3140), Color(0xFF12151D)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 26, offset: const Offset(0, 12)),
                  BoxShadow(color: textColor.withValues(alpha: 0.22), blurRadius: 34, spreadRadius: 1),
                ],
              ),
              padding: const EdgeInsets.all(bezel),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(corner),
                child: SizedBox(
                  width: w,
                  height: h,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: watchW.toDouble(),
                      height: watchH.toDouble(),
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          RepaintBoundary(
                            key: captureKey,
                            child: SizedBox(
                              width: watchW.toDouble(),
                              height: watchH.toDouble(),
                              child: ClipRect(child: IgnorePointer(ignoring: !backgroundInteractive, child: background)),
                            ),
                          ),
                          _timeBlock(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Kulakçık (taç)
          Positioned(
            right: 0,
            top: (h + bezel * 2) * 0.30,
            child: Container(
              width: 8,
              height: 46 * scale.clamp(0.8, 1.4),
              decoration: BoxDecoration(
                color: const Color(0xFF3A4050),
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBlock() {
    final showAbove = !isMinimalist && above != WatchWidgetType.none;
    final showBelow = !isMinimalist && below != WatchWidgetType.none;

    final parts = timeText.split(':');
    final hourStr = parts.isNotEmpty ? parts[0] : '12';
    final minStr = parts.length > 1 ? parts[1] : '45';

    final textStyle = TextStyle(
      color: textColor,
      fontSize: isStacked ? 48 : 44,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
      height: 1.05,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final Widget timeWidget;
    if (isStacked) {
      timeWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(hourStr, style: textStyle),
          const SizedBox(height: 2),
          Text(minStr, style: textStyle),
        ],
      );
    } else {
      timeWidget = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 76,
            child: Text(hourStr, style: textStyle, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 34), // İki nokta tam bu boşluğun ortasında parlar (asla üst üste binmez!)
          SizedBox(
            width: 76,
            child: Text(minStr, style: textStyle, textAlign: TextAlign.center),
          ),
        ],
      );
    }

    final block = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isStacked ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (showAbove) ...[
          _infoRow(above),
          const SizedBox(height: 4),
        ],
        timeWidget,
        if (showBelow) ...[
          const SizedBox(height: 4),
          _infoRow(below),
        ],
      ],
    );

    return Positioned(
      left: timeX,
      top: timeY,
      child: moveMode
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => onMove(d.delta.dx / scale, d.delta.dy / scale),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1),
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                child: block,
              ),
            )
          : IgnorePointer(child: block),
    );
  }

  Widget _infoRow(WatchWidgetType type) {
    return SizedBox(
      height: infoRowHeight,
      child: Row(
        children: [
          Icon(type.icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                infoValues[type] ?? '',
                style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
