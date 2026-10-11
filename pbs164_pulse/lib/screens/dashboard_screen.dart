import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../services/biofeedback_service.dart';
import '../core/theme.dart';
import 'watch_face_studio_screen.dart';
import 'stress_biofeedback_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _latestBpm = 0;
  int _latestSteps = 0;
  double _calories = 0;
  double _distanceKm = 0;

  @override
  void initState() {
    super.initState();
    final ble = Provider.of<PbsBleService>(context, listen: false);
    ble.heartRateStream.listen((record) {
      if (mounted) setState(() => _latestBpm = record.bpm);
    });
    ble.stepStream.listen((record) {
      if (mounted) {
        setState(() {
          _latestSteps = record.steps;
          _calories = record.calories;
          _distanceKm = record.distanceKm;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<PbsBleService>();

    final displaySteps = ble.lastSteps != null ? ble.lastSteps!.steps : _latestSteps;
    final displayCal = ble.lastSteps != null ? ble.lastSteps!.calories.toInt() : (_latestSteps * 0.04).toInt();
    final displayDist = ble.lastSteps != null ? ble.lastSteps!.distanceKm.toStringAsFixed(1) : (_latestSteps * 0.00075).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "PBS 164 PULSE",
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        actions: [
          if (ble.isConnected)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.battery_charging_full, color: PbsTheme.neonGreen, size: 16),
                  const SizedBox(width: 4),
                  Text("%${ble.batteryLevel}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Bağlantı Kartı
            _buildConnectionCard(ble),
            const SizedBox(height: 16),

            // 2. Günlük Adım ve Aktivite Halkası
            _buildActivityRingCard(displaySteps, displayCal, displayDist),
            const SizedBox(height: 16),

            // 3. Canlı Nabız Kartı
            _buildLiveHeartCard(ble),
            const SizedBox(height: 16),

            // 4. Biyometrik Sensör Paneli (Tansiyon & SpO2)
            _buildBiometricPanel(ble),
            const SizedBox(height: 16),

            // 5. Stres Radarı & Haptik Nefes Seansı
            _buildStressBiofeedbackBanner(context),
            const SizedBox(height: 16),

            // 6. Kadran & Ekran Stüdyosu Bannerı
            _buildWatchFaceStudioBanner(context),
            const SizedBox(height: 16),

            // 7. Hızlı Komutlar Izgarası
            _buildQuickActionsGrid(ble),
          ],
        ),
      ),
    );
  }

  Widget _buildStressBiofeedbackBanner(BuildContext context) {
    return Consumer<BiofeedbackService>(
      builder: (context, bio, _) {
        final stress = bio.stressScore.toInt();
        Color badgeColor;
        String badgeText;
        if (stress < 30) {
          badgeColor = PbsTheme.neonGreen;
          badgeText = "%$stress ZEN";
        } else if (stress < 55) {
          badgeColor = PbsTheme.cyan;
          badgeText = "%$stress SAKİN";
        } else if (stress < 75) {
          badgeColor = PbsTheme.amber;
          badgeText = "%$stress UYARILMA";
        } else {
          badgeColor = PbsTheme.neonPink;
          badgeText = "%$stress STRES";
        }

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: PbsTheme.neonPink.withOpacity(0.35)),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StressBiofeedbackScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2A6D), Color(0xFF00F2FE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: PbsTheme.neonPink.withOpacity(0.3), blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.self_improvement, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text("STRES RADARI & NEFES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withOpacity(0.5)),
                          ),
                          child: Text(badgeText, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: badgeColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      "Bilek haptik geribildirimiyle biofeedback seansı & HRV",
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: PbsTheme.neonPink),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildWatchFaceStudioBanner(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: PbsTheme.cyan.withOpacity(0.4)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WatchFaceStudioScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: PbsTheme.cyan.withOpacity(0.3), blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.palette, color: Colors.black, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("KADRAN STÜDYOSU", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                        SizedBox(width: 6),
                        Text("CANLI", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PbsTheme.neonGreen)),
                      ],
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Saat konumu, RGB565 renkler ve ekran widget'larını özelleştirin",
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: PbsTheme.cyan),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard(PbsBleService ble) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: ble.isConnected ? PbsTheme.neonGreen : PbsTheme.neonPink,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (ble.isConnected ? PbsTheme.neonGreen : PbsTheme.neonPink).withOpacity(0.6),
                        blurRadius: 10,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  ble.isConnected ? "Bağlı: ${ble.device?.platformName ?? 'PBS 164'}" : "Saat Bağlı Değil",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                if (ble.isConnected)
                  IconButton(
                    icon: const Icon(Icons.link_off, color: Colors.white60),
                    onPressed: () => ble.disconnect(),
                    tooltip: "Bağlantıyı Kes",
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!ble.isConnected)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.bluetooth_searching, size: 20),
                  label: const Text("SAATİ TARA & BAĞLAN", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PbsTheme.cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _showScanDialog(ble),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Nordic BLE UART Köprüsü", style: TextStyle(color: Colors.white38, fontSize: 12)),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16, color: PbsTheme.cyan),
                    label: const Text("Verileri Yenile", style: TextStyle(color: PbsTheme.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Saat verileri yenileniyor..."),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      await ble.refreshAllData();
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRingCard(int steps, int cal, String distKm) {
    const goalSteps = 10000;
    final progress = (steps / goalSteps).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Dairesel İlerleme
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 9,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor: const AlwaysStoppedAnimation<Color>(PbsTheme.cyan),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      "${(progress * 100).toInt()}%",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Metrikler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Günlük Adım", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(
                    "$steps",
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMiniStat(Icons.local_fire_department, "$cal kcal", PbsTheme.neonPink),
                      const SizedBox(width: 16),
                      _buildMiniStat(Icons.place, "$distKm km", PbsTheme.electricBlue),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLiveHeartCard(PbsBleService ble) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PbsTheme.neonPink.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: PbsTheme.neonPink, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Anlık Nabız", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _latestBpm > 0 ? "$_latestBpm" : (ble.lastHeartRate != null ? "${ble.lastHeartRate!.bpm}" : "--"),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: PbsTheme.neonPink),
                      ),
                      const SizedBox(width: 6),
                      const Text("BPM", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ble.isMeasuringHeart ? Colors.white12 : PbsTheme.neonPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: ble.isConnected ? () => ble.toggleHeartRate() : null,
              child: Text(ble.isMeasuringHeart ? "Durdur" : "Nabız Ölç"),
            ),
          ],
        ),
      ),
    );
  }

  // Biyometrik Sensör Paneli (Tansiyon & SpO2)
  Widget _buildBiometricPanel(PbsBleService ble) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text("BİYOMETRİK SENSÖRLER", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        Row(
          children: [
            // 1. Tansiyon
            Expanded(
              child: _buildSensorCard(
                title: "TANSİYON",
                value: ble.lastBloodPressure != null ? "${ble.lastBloodPressure!.systolic}/${ble.lastBloodPressure!.diastolic}" : "--/--",
                unit: "mmHg (Kan Basıncı)",
                icon: Icons.speed,
                color: PbsTheme.electricBlue,
                isMeasuring: ble.isMeasuringBp,
                onTap: ble.isConnected ? () => ble.toggleBloodPressure() : null,
              ),
            ),
            const SizedBox(width: 12),
            // 2. SpO2 Oksijen
            Expanded(
              child: _buildSensorCard(
                title: "OKSİJEN",
                value: ble.lastBloodOxygen != null ? "%${ble.lastBloodOxygen!.percentage}" : "--%",
                unit: "SpO2 (Doygunluk)",
                icon: Icons.bloodtype,
                color: PbsTheme.neonPink,
                isMeasuring: ble.isMeasuringSpo2,
                onTap: ble.isConnected ? () => ble.toggleBloodOxygen() : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required bool isMeasuring,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 24),
                  if (isMeasuring)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: PbsTheme.cyan),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(unit, style: const TextStyle(fontSize: 10, color: Colors.white30)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isMeasuring ? PbsTheme.neonPink.withOpacity(0.2) : color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isMeasuring ? PbsTheme.neonPink : color.withOpacity(0.4)),
                ),
                child: Text(
                  isMeasuring ? "Durdur" : "Ölçümü Başlat",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isMeasuring ? PbsTheme.neonPink : color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(PbsBleService ble) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text("HIZLI EYLEMLER", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _buildActionCard(
              icon: Icons.vibration,
              label: "Saati Titret",
              hint: "Cihazı Bul",
              color: PbsTheme.amber,
              onTap: ble.isConnected ? () => ble.vibrate() : null,
            ),
            _buildActionCard(
              icon: Icons.access_time_filled,
              label: "Saati Eşitle",
              hint: "Saat Senkronu",
              color: PbsTheme.electricBlue,
              onTap: ble.isConnected ? () => ble.syncTimeNow() : null,
            ),
            _buildActionCard(
              icon: Icons.camera_alt,
              label: "Kamera Modu",
              hint: "Uzaktan Deklanşör",
              color: PbsTheme.neonGreen,
              onTap: ble.isConnected ? () => ble.triggerCamera() : null,
            ),
            _buildActionCard(
              icon: Icons.message,
              label: "Bildirim Gönder",
              hint: "WhatsApp Test",
              color: const Color(0xFF7F00FF),
              onTap: ble.isConnected ? () => _showNotificationDialog(ble) : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String hint,
    required Color color,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: PbsTheme.cardDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: disabled ? Colors.white.withOpacity(0.04) : PbsTheme.cardBorder),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: disabled ? Colors.white24 : color, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: disabled ? Colors.white30 : Colors.white)),
                Text(hint, style: TextStyle(fontSize: 10, color: disabled ? Colors.white12 : Colors.white54)),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showScanDialog(PbsBleService ble) {
    ble.startScan();
    showModalBottomSheet(
      context: context,
      backgroundColor: PbsTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Saat Aranıyor...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              const LinearProgressIndicator(color: PbsTheme.cyan),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: FlutterBluePlus.scanResults,
                  initialData: FlutterBluePlus.lastScanResults,
                  builder: (context, snapshot) {
                    final results = snapshot.data ?? [];
                    if (results.isEmpty) {
                      return const Center(child: Text("Yakında BLE cihaz aranıyor...", style: TextStyle(color: Colors.white54)));
                    }
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final r = results[i];
                        final name = r.device.platformName.isNotEmpty ? r.device.platformName : r.device.remoteId.str;
                        return ListTile(
                          leading: const Icon(Icons.watch, color: PbsTheme.cyan),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("RSSI: ${r.rssi} dBm"),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () async {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("${r.device.platformName.isNotEmpty ? r.device.platformName : 'Cihaza'} bağlanılıyor..."),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            final ok = await ble.connect(r.device);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok ? "PBS 164 Bağlandı! 🚀" : "Bağlantı kurulamadı. Tekrar deneyin."),
                                  backgroundColor: ok ? Colors.teal : Colors.redAccent,
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationDialog(PbsBleService ble) {
    final titleCtrl = TextEditingController(text: "WhatsApp - Test");
    final bodyCtrl = TextEditingController(text: "Saatinden selamlar! 🚀");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PbsTheme.cardDark,
        title: const Text("Saate Bildirim Gönder"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Başlık")),
            TextField(controller: bodyCtrl, decoration: const InputDecoration(labelText: "Mesaj")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ble.pushNotification(titleCtrl.text, bodyCtrl.text);
            },
            child: const Text("Gönder"),
          ),
        ],
      ),
    );
  }
}
