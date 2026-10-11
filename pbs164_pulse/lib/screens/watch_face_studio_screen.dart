import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/rgb565.dart';
import '../core/theme.dart';
import '../models/diy_widgets.dart';
import '../services/ble_service.dart';
import '../services/native_bridge.dart';
import '../services/wf_dial_builder.dart';
import '../services/wf_font_service.dart';
import '../widgets/watch_preview.dart';

enum _StudioTab { background, text, info, faces }

enum _BgKind { keep, photo, preset, defaultBg }

/// Kadran Stüdyosu: saatin DIY (özel) kadranını görsel olarak tasarlayıp OTA ile saate yazar.
class WatchFaceStudioScreen extends StatefulWidget {
  const WatchFaceStudioScreen({super.key});

  @override
  State<WatchFaceStudioScreen> createState() => _WatchFaceStudioScreenState();
}

class _WatchFaceStudioScreenState extends State<WatchFaceStudioScreen> {
  // Saatin yazı konumu sınırları (HryFine 240x298 cihazlarda X<=140, Y<=198 uygular)
  static const double _maxX = 140;
  static const double _maxY = 198;

  static const List<Color> _palette = [
    Color(0xFFFFFFFF),
    Color(0xFFFFD60A),
    Color(0xFFFF9F0A),
    Color(0xFFFF453A),
    Color(0xFFFF2D9B),
    Color(0xFFBF5AF2),
    Color(0xFF7D7AFF),
    Color(0xFF0A84FF),
    Color(0xFF64D2FF),
    Color(0xFF00F2FE),
    Color(0xFF30D158),
    Color(0xFFB8FF3C),
    Color(0xFFFFB5C2),
    Color(0xFFC7B9A0),
    Color(0xFF8E8E93),
    Color(0xFF000000),
  ];

  final GlobalKey _captureKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  final TransformationController _tc = TransformationController();

  _StudioTab _tab = _StudioTab.background;
  bool _moveMode = false;

  // Arka plan
  _BgKind _bgKind = _BgKind.preset;
  bool _bgDirty = true;
  Uint8List? _photoBytes;
  Size? _photoSize;
  int _presetIndex = 0;
  double _brightness = 0;
  double _saturation = 1;
  double _dim = 0;

  // Özel Kadran Motoru Ayarları
  String _selectedFontId = 'ink';
  WfTimeLayout _layout = WfTimeLayout.singleLine;
  bool _isMinimalist = true;

  // Yazı Konumu ve Renk (240x298 ekran için 27, 121 tam ortadır)
  double _timeX = 27;
  double _timeY = 121;
  HSVColor _hsv = HSVColor.fromColor(const Color(0xFFFF70BA));
  WatchWidgetType _above = WatchWidgetType.heart;
  WatchWidgetType _below = WatchWidgetType.date;

  bool _loadedFromWatch = false;
  bool _sending = false;
  double _progress = 0;
  String _stage = '';

  Color get _color => _hsv.toColor();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ble = context.read<PbsBleService>();
      if (ble.isConnected) _refreshFromWatch(ble);
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _refreshFromWatch(PbsBleService ble) async {
    await ble.queryWatchFaces();
    await Future.delayed(const Duration(milliseconds: 200));
    await ble.readCustomWatchFace();
    if (mounted) setState(() => _loadedFromWatch = false);
  }

  /// Saatin kayıtlı DIY değerlerini bir kez arayüze al (konumları ezmez).
  void _maybeLoadFromWatch(PbsBleService ble) {
    final rec = ble.customWatchFace;
    if (_loadedFromWatch || rec == null) return;
    _loadedFromWatch = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _hsv = HSVColor.fromColor(Rgb565.toColor(rec.colorRgb565));
        _above = WatchWidgetType.fromCode(rec.aboveWidget);
        _below = WatchWidgetType.fromCode(rec.belowWidget);
      });
    });
  }

  (int, int) _screenSize(PbsBleService ble) {
    final f = ble.features;
    if (f != null && f.valid) return f.screenSize;
    return (240, 298);
  }

  // ---------------------------------------------------------------------------
  // Arka plan işlemleri
  // ---------------------------------------------------------------------------

  Future<void> _pickPhoto(ImageSource source, PbsBleService ble) async {
    try {
      final x = await _picker.pickImage(source: source, maxWidth: 1800, maxHeight: 1800, imageQuality: 95);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final desc = await ui.ImageDescriptor.encoded(buffer);
      final size = Size(desc.width.toDouble(), desc.height.toDouble());
      desc.dispose();
      buffer.dispose();
      final (w, h) = _screenSize(ble);
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoSize = size;
        _bgKind = _BgKind.photo;
        _bgDirty = true;
        _tc.value = _centeredTransform(size, w, h);
        _moveMode = false;
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      _snack('Fotoğraf seçilemedi: $e', error: true);
    }
  }

  Matrix4 _centeredTransform(Size photo, int w, int h) {
    final cover = math.max(w / photo.width, h / photo.height);
    final cw = photo.width * cover;
    final ch = photo.height * cover;
    return Matrix4.identity()..translate(-(cw - w) / 2, -(ch - h) / 2);
  }

  List<double> _colorMatrix() {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final s = _saturation;
    final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
    final b = _brightness * 255;
    return [
      sr + s, sg, sb, 0, b,
      sr, sg + s, sb, 0, b,
      sr, sg, sb + s, 0, b,
      0, 0, 0, 1, 0,
    ];
  }

  Widget _buildBackground(int w, int h) {
    Widget content;
    switch (_bgKind) {
      case _BgKind.photo:
        final ps = _photoSize!;
        final cover = math.max(w / ps.width, h / ps.height);
        content = InteractiveViewer(
          transformationController: _tc,
          constrained: false,
          minScale: 1,
          maxScale: 8,
          boundaryMargin: EdgeInsets.zero,
          onInteractionEnd: (_) => setState(() => _bgDirty = true),
          child: SizedBox(
            width: ps.width * cover,
            height: ps.height * cover,
            child: Image.memory(_photoBytes!, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.medium),
          ),
        );
        break;
      case _BgKind.preset:
        content = DecoratedBox(
          decoration: BoxDecoration(gradient: kBackgroundPresets[_presetIndex].gradient),
          child: const SizedBox.expand(),
        );
        break;
      case _BgKind.defaultBg:
        content = const _PlaceholderBackground(
          icon: Icons.restart_alt_rounded,
          text: 'Saatin dahili\narka planı kullanılacak',
        );
        break;
      case _BgKind.keep:
        content = const _PlaceholderBackground(
          icon: Icons.photo_size_select_actual_outlined,
          text: 'Saatteki mevcut\narka plan korunur\n(değiştirmek için seç)',
        );
        break;
    }

    final styled = Stack(
      fit: StackFit.expand,
      children: [
        if (_bgKind == _BgKind.photo || _bgKind == _BgKind.preset) ...[
          ColorFiltered(colorFilter: ColorFilter.matrix(_colorMatrix()), child: content),
          if (_dim > 0) IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: _dim))),
        ] else ...[
          content,
        ],
        if (_layout == WfTimeLayout.singleLine)
          Positioned(
            left: _timeX + 89,
            top: _timeY + 15,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
      ],
    );
    return SizedBox(width: w.toDouble(), height: h.toDouble(), child: styled);
  }

  Future<Uint8List> _captureBackground() async {
    final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  // ---------------------------------------------------------------------------
  // Gönderme
  // ---------------------------------------------------------------------------

  Future<void> _send(PbsBleService ble) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _progress = 0;
      _stage = 'Hazırlanıyor...';
    });
    HapticFeedback.mediumImpact();
    try {
      final (w, h) = _screenSize(ble);

      // 1. Arka plan PAR dönüştürme
      setState(() {
        _stage = 'Arka plan işleniyor...';
        _progress = 0.05;
      });
      final bgPng = await _captureBackground();
      final bgRes = await PbsNativeBridge.makePar(
        bgPng,
        width: w,
        height: h,
        maxBytes: ble.watchFaces?.paperSize ?? 0,
      );

      // 2. Özel font PAR şeridi üretme (38x560 alfa)
      setState(() {
        _stage = 'Özel font şeridi oluşturuluyor...';
        _progress = 0.12;
      });
      final digitStripPar = await WfFontService.generateDigitStripPar(
        color: _color,
        fontId: _selectedFontId,
      );

      // 3. Sıfırdan donmayan tam WF kadranı derleme
      setState(() {
        _stage = 'Kadran derleniyor...';
        _progress = 0.18;
      });
      final tmpl = await WfDialBuilder.loadBaseTemplate();
      final dialBytes = WfDialBuilder.buildCustomDial(
        baseTemplate: tmpl,
        backgroundPar: bgRes.par,
        digitStripPar: digitStripPar,
        layout: _layout,
        timeX: _timeX.round(),
        timeY: _timeY.round(),
        minimalist: _isMinimalist,
      );

      // 4. OTA ile saate aktarma (cmd=5, sub=1)
      setState(() {
        _stage = 'Saate aktarılıyor...';
      });
      final res = await ble.pushDialFile(
        dialBytes,
        onProgress: (stage, p) {
          if (mounted) {
            setState(() {
              _stage = stage;
              _progress = 0.2 + (0.8 * p);
            });
          }
        },
      );

      if (!mounted) return;
      if (res.ok) {
        setState(() {
          _bgDirty = false;
          _loadedFromWatch = true;
        });
        HapticFeedback.heavyImpact();
      }
      _snack(res.message, error: !res.ok);
    } catch (e) {
      _snack('Kadran yükleme hatası: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: error ? PbsTheme.neonPink : PbsTheme.neonGreen,
        behavior: SnackBarBehavior.floating,
        content: Text(msg, style: TextStyle(color: error ? Colors.white : Colors.black, fontWeight: FontWeight.w700)),
      ));
  }

  // ---------------------------------------------------------------------------
  // Arayüz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<PbsBleService>();
    _maybeLoadFromWatch(ble);
    final (w, h) = _screenSize(ble);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KADRAN STÜDYOSU', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.5)),
        actions: [
          IconButton(
            tooltip: 'Saatten yeniden oku',
            icon: const Icon(Icons.sync_rounded),
            onPressed: ble.isConnected && !_sending ? () => _refreshFromWatch(ble) : null,
          ),
          IconButton(
            tooltip: 'BLE günlüğü',
            icon: const Icon(Icons.receipt_long_rounded, color: PbsTheme.cyan),
            onPressed: () => _showLogs(ble),
          ),
          IconButton(
            tooltip: 'Bilgi',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              children: [
                _statusPill(ble, w, h),
                const SizedBox(height: 12),
                _previewArea(ble, w, h),
                const SizedBox(height: 10),
                _modeToggle(),
                const SizedBox(height: 12),
                _tabBar(),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(_tab), child: _tabContent(ble)),
              ),
            ),
          ),
          _sendBar(ble),
        ],
      ),
    );
  }

  Widget _statusPill(PbsBleService ble, int w, int h) {
    final f = ble.features;
    final connected = ble.isConnected;
    final detail = connected && f != null && f.valid
        ? '$w×$h  •  ${f.supportPush ? 'OTA hazır' : 'OTA yok'}  •  ${f.is8Bytes ? '8 bayt kod' : '2 bayt kod'}'
        : connected
            ? 'Cihaz bilgisi okunuyor…'
            : 'Saat bağlı değil — Özet sayfasından bağlan';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PbsTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PbsTheme.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.watch_rounded, size: 18, color: connected ? PbsTheme.neonGreen : Colors.white38),
          const SizedBox(width: 10),
          Expanded(child: Text(detail, style: TextStyle(fontSize: 12, color: connected ? Colors.white70 : Colors.white38))),
          if (_loadedFromWatch && connected) const Icon(Icons.check_circle_rounded, size: 16, color: PbsTheme.neonGreen),
        ],
      ),
    );
  }

  Widget _previewArea(PbsBleService ble, int w, int h) {
    final infoValues = <WatchWidgetType, String>{
      WatchWidgetType.date: _dateText(),
      WatchWidgetType.steps: '${ble.lastSteps?.steps ?? 6420}',
      WatchWidgetType.heart: '${ble.lastHeartRate?.bpm ?? 78}',
      WatchWidgetType.sleep: '7:45',
    };
    final now = DateTime.now();
    final timeText = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return LayoutBuilder(builder: (context, c) {
      final maxH = MediaQuery.of(context).size.height * 0.33;
      final scale = math.min(math.min((c.maxWidth - 40) / w, (maxH - 18) / h), 1.4);
      return Center(
        child: WatchPreview(
          watchW: w,
          watchH: h,
          scale: scale,
          captureKey: _captureKey,
          background: _buildBackground(w, h),
          backgroundInteractive: _bgKind == _BgKind.photo && !_moveMode,
          timeX: _timeX,
          timeY: _timeY,
          textColor: Rgb565.quantize(_color),
          above: _above,
          below: _below,
          moveMode: _moveMode,
          onMove: (dx, dy) => setState(() {
            final isSingle = _layout == WfTimeLayout.singleLine;
            final maxX = isSingle ? 54.0 : 160.0;
            final maxY = isSingle ? 240.0 : 180.0;
            _timeX = (_timeX + dx).clamp(0, maxX);
            _timeY = (_timeY + dy).clamp(0, maxY);
          }),
          timeText: timeText,
          infoValues: infoValues,
          fontFamily: WfFontService.getPreset(_selectedFontId).fontFamily,
          fontWeight: WfFontService.getPreset(_selectedFontId).weight,
          isStacked: _layout == WfTimeLayout.stacked,
          isMinimalist: _isMinimalist,
        ),
      );
    });
  }

  String _dateText() {
    final n = DateTime.now();
    // Saatin kendi tarih widget'ı gün ve ayı ayraçsız rakamla çizer.
    return '${n.day.toString().padLeft(2, '0')}${n.month.toString().padLeft(2, '0')}';
  }

  Widget _modeToggle() {
    final canPan = _bgKind == _BgKind.photo;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _modeChip(
          icon: Icons.pan_tool_alt_rounded,
          label: 'Fotoğrafı ayarla',
          selected: !_moveMode && canPan,
          enabled: canPan,
          onTap: () => setState(() => _moveMode = false),
        ),
        const SizedBox(width: 8),
        _modeChip(
          icon: Icons.open_with_rounded,
          label: 'Yazıyı taşı',
          selected: _moveMode,
          enabled: true,
          onTap: () => setState(() => _moveMode = true),
        ),
      ],
    );
  }

  Widget _modeChip({
    required IconData icon,
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final fg = selected ? Colors.black : (enabled ? Colors.white70 : Colors.white24);
    return Flexible(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? PbsTheme.cyan : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? PbsTheme.cyan : PbsTheme.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBar() {
    const items = [
      (_StudioTab.background, Icons.wallpaper_rounded, 'Arka plan'),
      (_StudioTab.text, Icons.text_fields_rounded, 'Yazı'),
      (_StudioTab.info, Icons.dashboard_customize_rounded, 'Bilgiler'),
      (_StudioTab.faces, Icons.watch_later_outlined, 'Kadranlar'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PbsTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PbsTheme.cardBorder),
      ),
      child: Row(
        children: [
          for (final (tab, icon, label) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _tab = tab;
                  if (tab == _StudioTab.text || tab == _StudioTab.info) _moveMode = true;
                  if (tab == _StudioTab.background && _bgKind == _BgKind.photo) _moveMode = false;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _tab == tab ? PbsTheme.cyan.withValues(alpha: 0.16) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(icon, size: 19, color: _tab == tab ? PbsTheme.cyan : Colors.white54),
                      const SizedBox(height: 3),
                      Text(label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _tab == tab ? PbsTheme.cyan : Colors.white54,
                          )),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabContent(PbsBleService ble) {
    switch (_tab) {
      case _StudioTab.background:
        return _backgroundTab(ble);
      case _StudioTab.text:
        return _textTab();
      case _StudioTab.info:
        return _infoTab();
      case _StudioTab.faces:
        return _facesTab(ble);
    }
  }

  // --- Arka plan sekmesi ---------------------------------------------------

  Widget _backgroundTab(PbsBleService ble) {
    final adjustable = _bgKind == _BgKind.photo || _bgKind == _BgKind.preset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _actionButton(Icons.photo_library_rounded, 'Galeri', () => _pickPhoto(ImageSource.gallery, ble))),
            const SizedBox(width: 10),
            Expanded(child: _actionButton(Icons.photo_camera_rounded, 'Kamera', () => _pickPhoto(ImageSource.camera, ble))),
            const SizedBox(width: 10),
            Expanded(
              child: _actionButton(Icons.restart_alt_rounded, 'Varsayılan', () {
                setState(() {
                  _bgKind = _BgKind.defaultBg;
                  _moveMode = true;
                });
              }, active: _bgKind == _BgKind.defaultBg),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionLabel('HAZIR ARKA PLANLAR'),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kBackgroundPresets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final selected = _bgKind == _BgKind.preset && _presetIndex == i;
              return GestureDetector(
                onTap: () => setState(() {
                  _bgKind = _BgKind.preset;
                  _presetIndex = i;
                  _bgDirty = true;
                  _moveMode = true;
                }),
                child: Container(
                  width: 74,
                  decoration: BoxDecoration(
                    gradient: kBackgroundPresets[i].gradient,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? PbsTheme.cyan : PbsTheme.cardBorder, width: selected ? 2.5 : 1),
                  ),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(kBackgroundPresets[i].name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel('GÖRSEL AYARLARI'),
        _slider('Parlaklık', _brightness, -0.5, 0.5, (v) => setState(() {
              _brightness = v;
              _bgDirty = true;
            }), enabled: adjustable, format: (v) => '${(v * 100).round()}%'),
        _slider('Doygunluk', _saturation, 0, 2, (v) => setState(() {
              _saturation = v;
              _bgDirty = true;
            }), enabled: adjustable, format: (v) => '${(v * 100).round()}%'),
        _slider('Karartma', _dim, 0, 0.8, (v) => setState(() {
              _dim = v;
              _bgDirty = true;
            }), enabled: adjustable, format: (v) => '${(v * 100).round()}%'),
        if (_bgKind == _BgKind.keep)
          const _HintCard(
            icon: Icons.lightbulb_outline_rounded,
            text: 'Saat, arka plan görselini geri okutmuyor. Yeni bir fotoğraf seçmeden gönderirsen yalnızca yazı ayarları değişir, mevcut arka plan kalır.',
          ),
      ],
    );
  }

  // --- Yazı sekmesi ------------------------------------------------------------

  Widget _textTab() {
    final shown = Rgb565.quantize(_color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('YAZI TİPİ (ÖZEL FONT)'),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: WfFontService.presets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final preset = WfFontService.presets[i];
              final selected = _selectedFontId == preset.id;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFontId = preset.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 110,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? PbsTheme.cyan.withValues(alpha: 0.16) : PbsTheme.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? PbsTheme.cyan : PbsTheme.cardBorder,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        preset.previewSample,
                        style: TextStyle(
                          color: _color,
                          fontSize: 20,
                          fontWeight: preset.weight,
                          fontFamily: preset.fontFamily,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? PbsTheme.cyan : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel('KADRAN DÜZENİ'),
        Row(
          children: [
            Expanded(
              child: _modeChip(
                icon: Icons.view_headline_rounded,
                label: 'Yan Yana (12:45)',
                selected: _layout == WfTimeLayout.singleLine,
                enabled: true,
                onTap: () => setState(() {
                  _layout = WfTimeLayout.singleLine;
                  _timeX = 27;
                  _timeY = 121;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _modeChip(
                icon: Icons.table_rows_rounded,
                label: 'Üst Üste (12 / 45)',
                selected: _layout == WfTimeLayout.stacked,
                enabled: true,
                onTap: () => setState(() {
                  _layout = WfTimeLayout.stacked;
                  _timeX = 80;
                  _timeY = 90;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: PbsTheme.cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PbsTheme.cardBorder),
          ),
          child: Row(
            children: [
              Icon(
                _isMinimalist ? Icons.cleaning_services_rounded : Icons.dashboard_customize_rounded,
                color: _isMinimalist ? PbsTheme.neonGreen : PbsTheme.cyan,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isMinimalist ? 'Minimalist & Sade (Sadece Saat)' : 'Tam Bilgi (Tarih ve Simgeler)',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _isMinimalist ? 'Ekstra widget\'lar gizlenir, tertemiz kadran' : 'Tarih ve diğer widget\'lar görüntülenir',
                      style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isMinimalist,
                activeThumbColor: PbsTheme.neonGreen,
                onChanged: (v) => setState(() => _isMinimalist = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel('YAZI RENGİ'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in _palette)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _hsv = HSVColor.fromColor(c));
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Rgb565.fromColor(c) == Rgb565.fromColor(_color) ? PbsTheme.cyan : Colors.white24,
                      width: Rgb565.fromColor(c) == Rgb565.fromColor(_color) ? 3 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _gradientSlider(
          label: 'Ton',
          value: _hsv.hue,
          max: 360,
          colors: [for (var i = 0; i <= 6; i++) HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor()],
          onChanged: (v) => setState(() => _hsv = _hsv.withHue(v)),
        ),
        _gradientSlider(
          label: 'Canlılık',
          value: _hsv.saturation,
          max: 1,
          colors: [HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(), HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor()],
          onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
        ),
        _gradientSlider(
          label: 'Parlaklık',
          value: _hsv.value,
          max: 1,
          colors: [Colors.black, HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor()],
          onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Saat 16-bit renk (RGB565) gösterir; ekrandaki gerçek renk: #${shown.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel('KONUM'),
        _positionGrid(),
        const SizedBox(height: 10),
        _positionSliders(),
        const _HintCard(
          icon: Icons.auto_awesome_rounded,
          text: '✨ Özel Kadran Motoru devrede! Seçtiğiniz yazı tipi ve renk şeridi doğrudan saatin dahili OTA flash belleğine yazılır.',
        ),
      ],
    );
  }

  Widget _positionSliders() {
    final isSingle = _layout == WfTimeLayout.singleLine;
    final maxX = isSingle ? 54.0 : 160.0;
    final maxY = isSingle ? 240.0 : 180.0;
    return Column(
      children: [
        _slider('Yatay (X)', _timeX.clamp(0, maxX), 0, maxX, (v) => setState(() => _timeX = v.roundToDouble()), format: (v) => '${v.round()} px'),
        _slider('Dikey (Y)', _timeY.clamp(0, maxY), 0, maxY, (v) => setState(() => _timeY = v.roundToDouble()), format: (v) => '${v.round()} px'),
      ],
    );
  }

  Widget _positionGrid() {
    final isSingle = _layout == WfTimeLayout.singleLine;
    // 240x298 piksel ekran için matematiksel olarak tam hizalamalar:
    // Tek satır: blok 186x56 px -> Merkez X=27, Merkez Y=121 (Sol: 10, Sağ: 44)
    // Üst üste: blok 80x118 px -> Merkez X=80, Merkez Y=90
    final double leftX = isSingle ? 10.0 : 20.0;
    final double centerX = isSingle ? 27.0 : 80.0;
    final double rightX = isSingle ? 44.0 : 140.0;

    final double topY = isSingle ? 35.0 : 25.0;
    final double centerY = isSingle ? 121.0 : 90.0;
    final double bottomY = isSingle ? 205.0 : 155.0;

    final xs = [leftX, centerX, rightX];
    final ys = [topY, centerY, bottomY];
    const labels = [
      ['Sol üst', 'Üst', 'Sağ üst'],
      ['Sol', 'Orta', 'Sağ'],
      ['Sol alt', 'Alt', 'Sağ alt'],
    ];
    return Column(
      children: [
        for (var r = 0; r < 3; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var c = 0; c < 3; c++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: c < 2 ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _timeX = xs[c].roundToDouble();
                          _timeY = ys[r].roundToDouble();
                        }),
                        child: Container(
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: (_timeX - xs[c]).abs() < 2 && (_timeY - ys[r]).abs() < 2 ? PbsTheme.cyan.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (_timeX - xs[c]).abs() < 2 && (_timeY - ys[r]).abs() < 2 ? PbsTheme.cyan : PbsTheme.cardBorder,
                            ),
                          ),
                          child: Text(labels[r][c], style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // --- Bilgiler sekmesi -----------------------------------------------------

  Widget _infoTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SAAT ÜSTÜ'),
        _infoPicker(_above, (t) => setState(() => _above = t)),
        const SizedBox(height: 16),
        _sectionLabel('SAAT ALTI'),
        _infoPicker(_below, (t) => setState(() => _below = t)),
        const _HintCard(
          icon: Icons.calendar_month_rounded,
          text: 'Tarih satırı saatin kendi biçimiyle (gün+ay, ayraçsız rakam) çizilir; bu da donanımdan geliyor.',
        ),
      ],
    );
  }

  Widget _infoPicker(WatchWidgetType selected, ValueChanged<WatchWidgetType> onPick) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final t in WatchWidgetType.values)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onPick(t);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 92,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected == t ? PbsTheme.cyan.withValues(alpha: 0.18) : PbsTheme.cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected == t ? PbsTheme.cyan : PbsTheme.cardBorder, width: selected == t ? 2 : 1),
              ),
              child: Column(
                children: [
                  Icon(t.icon, size: 22, color: selected == t ? PbsTheme.cyan : Colors.white60),
                  const SizedBox(height: 6),
                  Text(t.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: selected == t ? PbsTheme.cyan : Colors.white70)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- Kadranlar sekmesi ----------------------------------------------------

  Widget _facesTab(PbsBleService ble) {
    final list = ble.watchFaces;
    if (!ble.isConnected) {
      return const _HintCard(icon: Icons.bluetooth_disabled_rounded, text: 'Saat bağlı değil.');
    }
    if (list == null || list.installedCodesBytes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: TextButton.icon(onPressed: () => _refreshFromWatch(ble), icon: const Icon(Icons.refresh_rounded), label: const Text('Kadranları oku')),
        ),
      );
    }
    final diyCode = ble.customWatchFace?.faceCodeHex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SAATTEKİ KADRANLAR (${list.dialCount})'),
        for (var i = 0; i < list.installedCodesBytes.length; i++)
          _faceTile(ble, i, list.installedCodesHex[i], list.installedCodesBytes[i], list.activeCodeHex, diyCode),
      ],
    );
  }

  Widget _faceTile(PbsBleService ble, int i, String hex, List<int> bytes, String activeHex, String? diyHex) {
    final active = hex.toLowerCase() == activeHex.toLowerCase();
    // DIY kodunun son iki baytı saat sorgusuna göre ters sırada gelebiliyor; ikisini de eşle.
    final isDiy = diyHex != null && _sameCode(hex, diyHex);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: PbsTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? PbsTheme.neonGreen : PbsTheme.cardBorder, width: active ? 1.8 : 1),
      ),
      child: ListTile(
        onTap: ble.isConnected
            ? () async {
                HapticFeedback.selectionClick();
                await ble.switchInternalWatchFace(bytes);
                await Future.delayed(const Duration(milliseconds: 600));
                await ble.queryWatchFaces();
              }
            : null,
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), shape: BoxShape.circle),
          child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        title: Text(isDiy ? 'Özel (DIY) kadran' : 'Kadran ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(hex, style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Colors.white38)),
        trailing: active
            ? const Chip(
                label: Text('Aktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
                backgroundColor: PbsTheme.neonGreen,
                visualDensity: VisualDensity.compact,
              )
            : const Icon(Icons.chevron_right_rounded, color: Colors.white38),
      ),
    );
  }

  bool _sameCode(String a, String b) {
    a = a.toLowerCase();
    b = b.toLowerCase();
    if (a == b) return true;
    if (a.length != b.length || a.length < 4) return false;
    // son iki baytı (4 hex) ters çevirerek karşılaştır
    final head = a.substring(0, a.length - 4);
    if (head != b.substring(0, b.length - 4)) return false;
    final ta = a.substring(a.length - 4);
    final tb = b.substring(b.length - 4);
    return ta.substring(2) + ta.substring(0, 2) == tb;
  }

  // --- Alt gönder çubuğu -----------------------------------------------------

  Widget _sendBar(PbsBleService ble) {
    final enabled = ble.isConnected && !_sending;
    final label = _sending
        ? '$_stage (${(_progress * 100).toInt()}%)'
        : !ble.isConnected
            ? 'Saat bağlı değil — Özetten bağlanın'
            : 'KADRANI SAATE YÜKLE (OTA)';
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: PbsTheme.bgDark,
          border: Border(top: BorderSide(color: PbsTheme.cardBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sending)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: _progress == 0 ? null : _progress, minHeight: 6, backgroundColor: Colors.white12, color: PbsTheme.cyan),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: enabled ? const LinearGradient(colors: [PbsTheme.cyan, PbsTheme.electricBlue]) : null,
                  color: enabled ? null : Colors.white12,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: enabled ? [BoxShadow(color: PbsTheme.cyan.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))] : null,
                ),
                child: ElevatedButton.icon(
                  onPressed: enabled ? () => _send(ble) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                      : const Icon(Icons.send_to_mobile_rounded, size: 20),
                  label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Ortak küçük bileşenler --------------------------------------------------

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.white38)),
      );

  Widget _actionButton(IconData icon, String label, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? PbsTheme.cyan.withValues(alpha: 0.18) : PbsTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? PbsTheme.cyan : PbsTheme.cardBorder, width: active ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? PbsTheme.cyan : Colors.white70),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? PbsTheme.cyan : Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    bool enabled = true,
    String Function(double)? format,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70))),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: PbsTheme.cyan,
              onChanged: enabled ? onChanged : null,
            ),
          ),
          SizedBox(width: 46, child: Text(format?.call(value) ?? value.toStringAsFixed(1), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _gradientSlider({
    required String label,
    required double value,
    required double max,
    required List<Color> colors,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70))),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), gradient: LinearGradient(colors: colors)),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 0,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                ),
                child: Slider(value: value.clamp(0, max), min: 0, max: max, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Günlük / bilgi diyalogları ---------------------------------------------

  void _showLogs(PbsBleService ble) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PbsTheme.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final logs = ble.diagnosticLogs;
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            children: [
              ListTile(
                title: const Text('BLE paket günlüğü', style: TextStyle(fontWeight: FontWeight.w800, color: PbsTheme.cyan)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () {
                      ble.clearDiagnosticLogs();
                      setSheet(() {});
                    },
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  itemBuilder: (_, i) {
                    final l = logs[i];
                    final color = l.contains('TX') ? PbsTheme.cyan : (l.contains('ACK') || l.contains('BAŞARILI') ? PbsTheme.neonGreen : Colors.white70);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(l, style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: color)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PbsTheme.cardDark,
        title: const Text('Nasıl çalışıyor?'),
        content: const Text(
          'Arka plan görseli saate Bluetooth üzerinden (OTA) yazılır ve saatin kendi biçimine (PAR) çevrilir. '
          'Saatin gösterdiği zaman ve bilgi satırları ise donanım tarafından çizilir; uygulama yalnızca '
          'konumunu, rengini ve hangi bilgilerin görüneceğini belirler.\n\n'
          'Yazıyı sürükleyerek taşıyabilir, fotoğrafı parmakla kaydırıp yakınlaştırabilirsin.',
          style: TextStyle(height: 1.4, fontSize: 13),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
      ),
    );
  }
}

class _PlaceholderBackground extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PlaceholderBackground({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF15192A), Color(0xFF0A0C14)]),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: Colors.white24),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white30, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HintCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PbsTheme.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: PbsTheme.amber),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5, color: Colors.white54, height: 1.4))),
        ],
      ),
    );
  }
}
