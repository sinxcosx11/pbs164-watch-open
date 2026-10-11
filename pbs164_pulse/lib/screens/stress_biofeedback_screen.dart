import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../services/biofeedback_service.dart';
import '../core/theme.dart';

class StressBiofeedbackScreen extends StatefulWidget {
  const StressBiofeedbackScreen({super.key});

  @override
  State<StressBiofeedbackScreen> createState() => _StressBiofeedbackScreenState();
}

class _StressBiofeedbackScreenState extends State<StressBiofeedbackScreen> with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _breathAnimController;
  BreathingPhase _lastKnownPhase = BreathingPhase.ready;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _breathAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
      value: 0.6,
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    _breathAnimController.dispose();
    super.dispose();
  }

  void _syncBreathAnimation(BiofeedbackService bio) {
    if (!bio.isSessionActive) {
      if (_breathAnimController.value != 0.6) {
        _breathAnimController.animateTo(0.6, duration: const Duration(milliseconds: 400));
      }
      _lastKnownPhase = BreathingPhase.ready;
      return;
    }

    if (bio.currentPhase != _lastKnownPhase) {
      _lastKnownPhase = bio.currentPhase;
      final dur = Duration(seconds: bio.currentPhaseSeconds);
      _breathAnimController.duration = dur;

      switch (bio.currentPhase) {
        case BreathingPhase.inhale:
          _breathAnimController.forward(from: 0.45);
          break;
        case BreathingPhase.holdIn:
          _breathAnimController.value = 1.0;
          break;
        case BreathingPhase.exhale:
          _breathAnimController.reverse(from: 1.0);
          break;
        case BreathingPhase.holdOut:
          _breathAnimController.value = 0.45;
          break;
        case BreathingPhase.ready:
          _breathAnimController.value = 0.6;
          break;
      }
    }
  }

  void _showSessionReport(BuildContext context, BiofeedbackService bio) {
    final startBpm = bio.startBpm;
    final endBpm = bio.currentBpm;
    final bpmDiff = endBpm - startBpm;

    final startStress = bio.startStress.toInt();
    final endStress = bio.stressScore.toInt();
    final stressDiff = endStress - startStress;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF131A29),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: PbsTheme.cyan.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PbsTheme.neonGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline, color: PbsTheme.neonGreen, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "SEANS TAMAMLANDI",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Biyolojik ritminiz başarıyla parasempatik moda geçti.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white60),
              ),
              const SizedBox(height: 24),

              // Metrik Değişim Kartları
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.favorite, color: PbsTheme.neonPink, size: 22),
                          const SizedBox(height: 6),
                          const Text("NABIZ", style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            "$endBpm BPM",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bpmDiff <= 0 ? "$bpmDiff BPM 🌿" : "+$bpmDiff BPM",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: bpmDiff <= 0 ? PbsTheme.neonGreen : PbsTheme.neonPink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.psychology, color: PbsTheme.cyan, size: 22),
                          const SizedBox(height: 6),
                          const Text("STRES SKORU", style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            "%$endStress",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stressDiff <= 0 ? "$stressDiff Puan 🧘" : "+$stressDiff Puan",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: stressDiff <= 0 ? PbsTheme.neonGreen : PbsTheme.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: PbsTheme.cyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PbsTheme.cyan.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.waves, color: PbsTheme.cyan, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Kalp Ritmi Koheransı (HRV)", style: TextStyle(fontSize: 11, color: Colors.white60)),
                          Text(
                            "${bio.hrvScore.toStringAsFixed(1)} ms RMSSD (Yüksek Denge)",
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PbsTheme.cyan),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PbsTheme.cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("HARİKA, ANLADIM", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bio = context.watch<BiofeedbackService>();
    final ble = context.watch<PbsBleService>();

    _syncBreathAnimation(bio);

    final stress = bio.stressScore;
    Color stressColor;
    String stressLabel;
    if (stress < 30) {
      stressColor = PbsTheme.neonGreen;
      stressLabel = "ZEN / MEDİTATİF";
    } else if (stress < 55) {
      stressColor = PbsTheme.cyan;
      stressLabel = "DENGELİ / SAKİN";
    } else if (stress < 75) {
      stressColor = PbsTheme.amber;
      stressLabel = "UYARILMA / HAREKETLİ";
    } else {
      stressColor = PbsTheme.neonPink;
      stressLabel = "YÜKSEK STRES / ALARM";
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "STRES RADARI & NEFES",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ble.isConnected ? PbsTheme.neonGreen.withOpacity(0.12) : Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ble.isConnected ? PbsTheme.neonGreen.withOpacity(0.4) : Colors.white24),
            ),
            child: Row(
              children: [
                Icon(
                  ble.isConnected ? Icons.watch : Icons.watch_off,
                  size: 14,
                  color: ble.isConnected ? PbsTheme.neonGreen : Colors.white54,
                ),
                const SizedBox(width: 5),
                Text(
                  ble.isConnected ? "Bilek Haptik" : "Saat Yok",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: ble.isConnected ? PbsTheme.neonGreen : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Canlı Biyometrik Radar Paneli
            _buildBiometricStatusCard(bio, stressColor, stressLabel),
            const SizedBox(height: 24),

            // Merkezi Haptik Nefes Küresi & Radarı
            _buildBreathingCore(bio, stressColor),
            const SizedBox(height: 24),

            // Faz Bilgisi ve Yönlendirici Metin
            _buildPhaseInstruction(bio),
            const SizedBox(height: 24),

            // Protokol ve Süre Seçici (Seans aktif değilken)
            if (!bio.isSessionActive) ...[
              _buildTechniqueSelector(bio),
              const SizedBox(height: 16),
              _buildDurationSelector(bio),
              const SizedBox(height: 24),
            ],

            // Seansı Başlat / Bitir Butonu
            _buildActionButton(bio, ble),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Canlı Nabız, HRV ve Stres Skoru Özeti
  Widget _buildBiometricStatusCard(BiofeedbackService bio, Color stressColor, String stressLabel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A29),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: stressColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    stressLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: stressColor,
                    ),
                  ),
                ],
              ),
              Text(
                "Stres İndeksi: %${bio.stressScore.toInt()}",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: PbsTheme.neonPink, size: 20),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("CANLI NABIZ", style: TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold)),
                          Text("${bio.currentBpm} BPM", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.waves, color: PbsTheme.cyan, size: 20),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("HRV (RMSSD)", style: TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold)),
                          Text("${bio.hrvScore.toStringAsFixed(0)} ms", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Optimize Edilmiş Nefes Küresi & Radarı
  Widget _buildBreathingCore(BiofeedbackService bio, Color stressColor) {
    Color phaseColor;
    switch (bio.currentPhase) {
      case BreathingPhase.inhale:
        phaseColor = PbsTheme.cyan;
        break;
      case BreathingPhase.holdIn:
        phaseColor = PbsTheme.amber;
        break;
      case BreathingPhase.exhale:
        phaseColor = const Color(0xFFC084FC);
        break;
      case BreathingPhase.holdOut:
        phaseColor = const Color(0xFF38BDF8);
        break;
      case BreathingPhase.ready:
        phaseColor = PbsTheme.cyan;
        break;
    }

    return SizedBox(
      height: 280,
      width: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dış Radar Tarama Halkası (Optimize edilmiş yay çizimi)
          AnimatedBuilder(
            animation: _radarController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(280, 280),
                painter: FastRadarPainter(
                  angle: _radarController.value * 2 * math.pi,
                  color: phaseColor,
                  isActive: bio.isSessionActive,
                ),
              );
            },
          ),

          // Donanım Hızlandırmalı Nefes Küresi
          AnimatedBuilder(
            animation: _breathAnimController,
            builder: (context, child) {
              final scale = _breathAnimController.value;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        phaseColor.withOpacity(0.8),
                        phaseColor.withOpacity(0.25),
                        phaseColor.withOpacity(0.0),
                      ],
                      stops: const [0.3, 0.75, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // İç Çekirdek ve Sayaç
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF090D16).withOpacity(0.92),
              border: Border.all(color: phaseColor.withOpacity(0.7), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!bio.isSessionActive) ...[
                  const Icon(Icons.air, color: PbsTheme.cyan, size: 34),
                  const SizedBox(height: 4),
                  const Text("HAZIR", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white70)),
                ] else ...[
                  Text(
                    _getPhaseName(bio.currentPhase),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: phaseColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${bio.phaseRemainingSeconds}s",
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPhaseName(BreathingPhase phase) {
    switch (phase) {
      case BreathingPhase.inhale: return "NEFES AL";
      case BreathingPhase.holdIn: return "TUT";
      case BreathingPhase.exhale: return "VER";
      case BreathingPhase.holdOut: return "BEKLE";
      case BreathingPhase.ready: return "HAZIR";
    }
  }

  /// Nefes Yönlendirici Açıklama Kutusu
  Widget _buildPhaseInstruction(BiofeedbackService bio) {
    String text;
    String subtext;

    if (!bio.isSessionActive) {
      text = "Biyolojik Geri Bildirim Seansı";
      subtext = "Gözlerinizi kapatabilirsiniz. Akıllı saatiniz her nefes dönüşünde bileğinizi titreterek sizi yönlendirir.";
    } else {
      switch (bio.currentPhase) {
        case BreathingPhase.inhale:
          text = "Burnunuzdan Derin ve Yavaşça Çekin";
          subtext = "Diyaframınızı şişirin, omuzlarınızı gevşetin.";
          break;
        case BreathingPhase.holdIn:
          text = "Nefesinizi Sakince Tutun";
          subtext = "Hava ciğerlerinizde oksijenleşirken dingin kalın.";
          break;
        case BreathingPhase.exhale:
          text = "Ağzınızdan Sakince ve Uzunca Bırakın";
          subtext = "Vücudunuzdaki tüm gerginliği nefesle serbest bırakın.";
          break;
        case BreathingPhase.holdOut:
          text = "Boşlukta Huzurla Kalın";
          subtext = "Parasempatik kalp ritminiz yavaşlıyor.";
          break;
        case BreathingPhase.ready:
          text = "Hazırlanın...";
          subtext = "İlk nefes döngüsü başlıyor.";
          break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          if (bio.isSessionActive) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (bio.sessionElapsedSeconds / bio.sessionDurationSeconds).clamp(0.0, 1.0),
                backgroundColor: Colors.white10,
                color: PbsTheme.cyan,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${bio.sessionElapsedSeconds ~/ 60}:${(bio.sessionElapsedSeconds % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                ),
                Text(
                  "${bio.sessionDurationSeconds ~/ 60}:${(bio.sessionDurationSeconds % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTechniqueSelector(BiofeedbackService bio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "KLİNİK NEFES PROTOKOLÜ",
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 1.1),
        ),
        const SizedBox(height: 10),
        Column(
          children: BreathingPattern.values.map((pat) {
            final isSelected = bio.pattern == pat;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? PbsTheme.cyan.withOpacity(0.12) : const Color(0xFF131A29),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? PbsTheme.cyan : Colors.white10,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: () => bio.setPattern(pat),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? PbsTheme.cyan : Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.self_improvement,
                    color: isSelected ? Colors.black : Colors.white70,
                    size: 20,
                  ),
                ),
                title: Text(
                  pat.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
                subtitle: Text(
                  pat.description,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
                trailing: isSelected
                    ? const Icon(Icons.radio_button_checked, color: PbsTheme.cyan, size: 20)
                    : const Icon(Icons.radio_button_off, color: Colors.white24, size: 20),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDurationSelector(BiofeedbackService bio) {
    final durations = [60, 180, 300];

    return Row(
      children: durations.map((sec) {
        final isSelected = bio.sessionDurationSeconds == sec;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text("${sec ~/ 60} Dakika"),
              selected: isSelected,
              selectedColor: PbsTheme.cyan,
              backgroundColor: const Color(0xFF131A29),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              onSelected: (_) => bio.setDuration(sec),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(BiofeedbackService bio, PbsBleService ble) {
    if (bio.isSessionActive) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: PbsTheme.neonPink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.stop, size: 24),
          label: const Text(
            "SEANSI BİTİR VE ANALİZ ET",
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 13),
          ),
          onPressed: () {
            bio.stopSession();
            _showSessionReport(context, bio);
          },
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: PbsTheme.cyan,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        icon: const Icon(Icons.play_arrow, size: 26),
        label: const Text(
          "HAPTİK SEANSI BAŞLAT",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14),
        ),
        onPressed: () async {
          await bio.startSession();
        },
      ),
    );
  }
}

/// Yüksek Performanslı Donanım Hızlandırmalı Radar Çizicisi
class FastRadarPainter extends CustomPainter {
  final double angle;
  final Color color;
  final bool isActive;

  FastRadarPainter({
    required this.angle,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.4, ringPaint);
    canvas.drawCircle(center, radius * 0.7, ringPaint);
    canvas.drawCircle(center, radius * 0.95, ringPaint);

    final crossPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(center.dx - radius * 0.95, center.dy), Offset(center.dx + radius * 0.95, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius * 0.95), Offset(center.dx, center.dy + radius * 0.95), crossPaint);

    if (isActive) {
      final sweepArcPaint = Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius * 0.95);
      canvas.drawArc(rect, angle, 0.8, false, sweepArcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant FastRadarPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.color != color || oldDelegate.isActive != isActive;
  }
}
