import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/ble_service.dart';
import '../services/biofeedback_service.dart';
import '../services/storage_service.dart';
import '../core/theme.dart';
import '../models/health_models.dart';
import 'stress_biofeedback_screen.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final List<FlSpot> _heartSpots = [];
  double _timeX = 0;
  String _selectedFilter = 'all'; // 'all', 'heart', 'bp', 'spo2'

  @override
  void initState() {
    super.initState();
    final ble = Provider.of<PbsBleService>(context, listen: false);

    ble.heartRateStream.listen((record) {
      if (mounted) {
        setState(() {
          _timeX += 1;
          _heartSpots.add(FlSpot(_timeX, record.bpm.toDouble()));
          if (_heartSpots.length > 30) _heartSpots.removeAt(0);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<PbsBleService>();
    final storage = ble.storage;
    final allRecords = storage.allRecords;

    final filteredRecords = _selectedFilter == 'all'
        ? allRecords
        : allRecords.where((r) => r.type == _selectedFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("SAĞLIK & BİYOMETRİK ANALİZ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (allRecords.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.file_download, color: PbsTheme.cyan),
              tooltip: "CSV Olarak Dışa Aktar",
              onPressed: () => _handleExportCsv(context, storage),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white60),
              tooltip: "Geçmişi Temizle",
              onPressed: () => _showClearConfirmDialog(storage),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Canlı Kalp Ritmi Grafiği (EKG / Dalga)
            _buildHeartChartCard(ble),
            const SizedBox(height: 16),

            // 2. Stres Radarı & Haptik Biyolojik Nefes Seansı
            _buildStressBiofeedbackBanner(context),
            const SizedBox(height: 16),

            // 3. Tansiyon ve SpO2 Canlı Analiz Kartları
            Row(
              children: [
                Expanded(child: _buildBloodPressureCard(ble)),
                const SizedBox(width: 12),
                Expanded(child: _buildBloodOxygenCard(ble)),
              ],
            ),
            const SizedBox(height: 20),

            // 3. Geçmiş Ölçüm Filtre Çipleri
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "ÖLÇÜM GEÇMİŞİ & GÜNLÜK",
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
                Text(
                  "${allRecords.length} Kayıt",
                  style: const TextStyle(color: PbsTheme.cyan, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Tümü', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('❤️ Nabız', 'heart'),
                  const SizedBox(width: 8),
                  _buildFilterChip('🩺 Tansiyon', 'bp'),
                  const SizedBox(width: 8),
                  _buildFilterChip('🫁 Oksijen', 'spo2'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Kronolojik Ölçüm Listesi (Depolama Alanı)
            _buildHistoryTimeline(filteredRecords, storage),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: PbsTheme.cyan,
      backgroundColor: PbsTheme.cardDark,
      side: BorderSide(color: isSelected ? PbsTheme.cyan : Colors.white12),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildHeartChartCard(PbsBleService ble) {
    final currentBpm = ble.lastHeartRate?.bpm ?? 0;
    final zone = ble.lastHeartRate?.zone ?? "Dinlenme / Isınma";

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.monitor_heart, color: ble.isMeasuringHeart ? PbsTheme.neonGreen : PbsTheme.neonPink, size: 22),
                    const SizedBox(width: 8),
                    const Text("Canlı Nabız Akışı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: ble.isConnected ? () => ble.toggleHeartRate() : null,
                  icon: Icon(ble.isMeasuringHeart ? Icons.stop : Icons.play_arrow, size: 16),
                  label: Text(ble.isMeasuringHeart ? "Durdur" : "Kesintisiz Ölç"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ble.isMeasuringHeart ? PbsTheme.neonPink.withOpacity(0.25) : PbsTheme.cyan.withOpacity(0.2),
                    foregroundColor: ble.isMeasuringHeart ? PbsTheme.neonPink : PbsTheme.cyan,
                    side: BorderSide(color: ble.isMeasuringHeart ? PbsTheme.neonPink : PbsTheme.cyan),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currentBpm > 0 ? "$currentBpm" : "--",
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(width: 6),
                const Text("BPM", style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    ble.enableSmoothing = !ble.enableSmoothing;
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ble.enableSmoothing ? PbsTheme.cyan.withOpacity(0.15) : Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ble.enableSmoothing ? PbsTheme.cyan : Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ble.enableSmoothing ? Icons.auto_graph : Icons.show_chart, size: 12, color: ble.enableSmoothing ? PbsTheme.cyan : Colors.white60),
                        const SizedBox(width: 4),
                        Text(
                          ble.enableSmoothing ? "Filtreli (Stabil)" : "Ham (Anlık)",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: ble.enableSmoothing ? PbsTheme.cyan : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ble.isMeasuringHeart ? PbsTheme.neonGreen.withOpacity(0.15) : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ble.isMeasuringHeart ? PbsTheme.neonGreen : Colors.white24),
                  ),
                  child: Text(
                    ble.isMeasuringHeart ? "Sensör Canlı (Sürekli)" : zone,
                    style: TextStyle(
                      color: ble.isMeasuringHeart ? PbsTheme.neonGreen : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: _heartSpots.isEmpty
                  ? const Center(child: Text("Sürekli canlı grafik için yukarıdan 'Kesintisiz Ölç'e basın", style: TextStyle(color: Colors.white30, fontSize: 12)))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _heartSpots,
                            isCurved: true,
                            color: PbsTheme.neonPink,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: PbsTheme.neonPink.withOpacity(0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodPressureCard(PbsBleService ble) {
    final bp = ble.lastBloodPressure;
    final sys = bp?.systolic ?? 0;
    final dia = bp?.diastolic ?? 0;

    String status = "Bekleniyor";
    Color statusColor = Colors.white38;
    if (sys > 0) {
      if (sys < 120 && dia < 80) {
        status = "İdeal 🟢";
        statusColor = PbsTheme.neonGreen;
      } else if (sys <= 129 && dia < 80) {
        status = "Hafif Yüksek 🟡";
        statusColor = PbsTheme.amber;
      } else {
        status = "Yüksek (Hipertansiyon) 🔴";
        statusColor = PbsTheme.neonPink;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.speed, color: PbsTheme.electricBlue, size: 24),
                if (ble.isMeasuringBp)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: PbsTheme.electricBlue)),
              ],
            ),
            const SizedBox(height: 10),
            const Text("TANSİYON", style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(sys > 0 ? "$sys / $dia" : "-- / --", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const Text("mmHg", style: TextStyle(fontSize: 10, color: Colors.white30)),
            const SizedBox(height: 6),
            Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: ble.isConnected ? () => ble.toggleBloodPressure() : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ble.isMeasuringBp ? PbsTheme.neonPink : PbsTheme.electricBlue,
                  side: BorderSide(color: ble.isMeasuringBp ? PbsTheme.neonPink : PbsTheme.electricBlue.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(ble.isMeasuringBp ? "Durdur" : "Ölçümü Başlat", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodOxygenCard(PbsBleService ble) {
    final spo2 = ble.lastBloodOxygen?.percentage ?? 0;

    String status = "Bekleniyor";
    Color statusColor = Colors.white38;
    if (spo2 > 0) {
      if (spo2 >= 95) {
        status = "İdeal Doygunluk 🟢";
        statusColor = PbsTheme.neonGreen;
      } else if (spo2 >= 90) {
        status = "Dikkat 🟡";
        statusColor = PbsTheme.amber;
      } else {
        status = "Düşük Oksijen 🔴";
        statusColor = PbsTheme.neonPink;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.bloodtype, color: PbsTheme.neonPink, size: 24),
                if (ble.isMeasuringSpo2)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: PbsTheme.neonPink)),
              ],
            ),
            const SizedBox(height: 10),
            const Text("OKSİJEN (SpO2)", style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(spo2 > 0 ? "%$spo2" : "-- %", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const Text("Kandaki Oksijen", style: TextStyle(fontSize: 10, color: Colors.white30)),
            const SizedBox(height: 6),
            Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: ble.isConnected ? () => ble.toggleBloodOxygen() : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ble.isMeasuringSpo2 ? PbsTheme.neonPink : PbsTheme.cyan,
                  side: BorderSide(color: ble.isMeasuringSpo2 ? PbsTheme.neonPink : PbsTheme.cyan.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(ble.isMeasuringSpo2 ? "Durdur" : "Ölçümü Başlat", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTimeline(List<HealthRecordEntry> records, PbsHealthStorageService storage) {
    if (records.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.history_toggle_off, color: Colors.white24, size: 42),
                const SizedBox(height: 10),
                const Text("Henüz kaydedilmiş bir ölçüm yok.", style: TextStyle(color: Colors.white54, fontSize: 13)),
                const Text("Yukarıdan Nabız, Tansiyon veya SpO2 ölçtüğünde buraya otomatik kaydedilir.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = records[index];
        IconData icon;
        Color color;
        String title;
        String valText;

        if (entry.type == 'heart') {
          icon = Icons.favorite;
          color = PbsTheme.neonPink;
          title = "Kalp Atış Hızı";
          valText = "${entry.data['bpm']} BPM";
        } else if (entry.type == 'bp') {
          icon = Icons.speed;
          color = PbsTheme.electricBlue;
          title = "Kan Basıncı (Tansiyon)";
          valText = "${entry.data['systolic']}/${entry.data['diastolic']} mmHg";
        } else {
          icon = Icons.bloodtype;
          color = PbsTheme.cyan;
          title = "Kandaki Oksijen (SpO2)";
          valText = "%${entry.data['percentage']}";
        }

        final dt = entry.timestamp;
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        final s = dt.second.toString().padLeft(2, '0');
        final day = dt.day.toString().padLeft(2, '0');
        final mo = dt.month.toString().padLeft(2, '0');
        final formattedDate = "$h:$m:$s • $day.$mo.${dt.year}";

        return Card(
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(valText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            subtitle: Text("$title • $formattedDate", style: const TextStyle(color: Colors.white38, fontSize: 11)),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.white24),
              onPressed: () => storage.deleteRecord(entry.id),
              tooltip: "Kaydı Sil",
            ),
          ),
        );
      },
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
            side: BorderSide(color: PbsTheme.cyan.withOpacity(0.4)),
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
                        colors: [Color(0xFF00F2FE), Color(0xFFFF2A6D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: PbsTheme.cyan.withOpacity(0.3), blurRadius: 8),
                      ],
                    ),
                    child: const Icon(Icons.air, color: Colors.black, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text("STRES RADARI & HAPTİK NEFES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
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
                        Text(
                          "HRV RMSSD: ${bio.hrvScore.toStringAsFixed(1)} ms • Biofeedback Seansı",
                          style: const TextStyle(fontSize: 11, color: Colors.white60),
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
      },
    );
  }

  void _showClearConfirmDialog(PbsHealthStorageService storage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PbsTheme.cardDark,
        title: const Text("Tüm Geçmiş Silinsin mi?"),
        content: const Text("Kaydedilen tüm tansiyon, nabız ve SpO2 ölçüm kayıtları kalıcı olarak temizlenecektir."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PbsTheme.neonPink),
            onPressed: () {
              Navigator.pop(ctx);
              storage.clearAll();
            },
            child: const Text("Temizle"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportCsv(BuildContext ctx, PbsHealthStorageService storage) async {
    try {
      final path = await storage.exportCsv();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: PbsTheme.cyan,
          content: Text("Sağlık raporu başarıyla kaydedildi:\n$path", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Dışa aktarma hatası: $e")),
      );
    }
  }
}
