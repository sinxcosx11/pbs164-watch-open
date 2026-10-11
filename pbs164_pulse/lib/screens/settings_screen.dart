import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../services/native_bridge.dart';
import '../protocol/pbs164_protocol.dart';
import '../core/theme.dart';
import 'watch_face_studio_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Ayar Durumları
  bool _raiseToWake = true;
  bool _is24Hour = true;
  bool _isLeftHand = true;
  bool _dndEnabled = false;
  bool _sedentaryEnabled = true;
  bool _drinkWaterEnabled = true;
  bool _whatsappEnabled = true;
  bool _callEnabled = true;

  // Sesli Asistan Tercihi ('google', 'gemini', 'chatgpt')
  String _selectedAssistant = 'google';

  TimeOfDay _alarmTime = const TimeOfDay(hour: 7, minute: 30);

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<PbsBleService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("SAAT AYARLARI & ASİSTAN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. SESLİ ASİSTAN & YAPAY ZEKA KÖPRÜSÜ
          _buildSectionHeader("🤖 SESLİ ASİSTAN & YAPAY ZEKA ENTEGRASYONU"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: PbsTheme.cyan.withOpacity(0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: PbsTheme.cyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.mic, color: PbsTheme.cyan, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Varsayılan Asistan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text("Saatte veya telefonda tetiklenecek yapay zeka", style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'google', label: Text("Google", style: TextStyle(fontSize: 12)), icon: Icon(Icons.assistant, size: 16)),
                      ButtonSegment(value: 'gemini', label: Text("Gemini", style: TextStyle(fontSize: 12)), icon: Icon(Icons.auto_awesome, size: 16)),
                      ButtonSegment(value: 'chatgpt', label: Text("ChatGPT", style: TextStyle(fontSize: 12)), icon: Icon(Icons.chat_bubble_outline, size: 16)),
                    ],
                    selected: {_selectedAssistant},
                    onSelectionChanged: (set) {
                      setState(() => _selectedAssistant = set.first);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final success = await PbsNativeBridge.launchAssistant(_selectedAssistant);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? "$_selectedAssistant asistanı başlatıldı!" : "$_selectedAssistant açılamadı. Uygulamanın yüklü olduğunu kontrol edin."),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          label: const Text("Asistanı Test Et", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PbsTheme.cyan,
                            side: const BorderSide(color: PbsTheme.cyan),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, color: PbsTheme.amber, size: 16),
                            SizedBox(width: 6),
                            Text("Saatte 'Telefona Bağlı Değil' Uyarısı Neden Çıkar?", style: TextStyle(color: PbsTheme.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "PBS 164'te mikrofon ve hoparlör için ayrı bir Bluetooth Ses (BT 3.0 / Çağrı) çipi vardır. Saatteki asistanın çalışması için saatin Bluetooth Çağrı modunun telefonla eşleşmesi gerekir.",
                          style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => PbsNativeBridge.openBluetoothSettings(),
                            icon: const Icon(Icons.bluetooth_audio, size: 16),
                            label: const Text("Bluetooth Ses Eşleştirme Sayfasını Aç", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. DONANIM VE SAAT KONTROLLERİ
          _buildSectionHeader("⌚ DONANIM & SAAT KONTROLLERİ"),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.palette, color: Colors.black, size: 20),
                  ),
                  title: const Text("Kadran & Ekran Stüdyosu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Saat konumu, RGB565 renkler ve ekran widget'ları", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: PbsTheme.cyan),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WatchFaceStudioScreen()),
                    );
                  },
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.vibration, color: PbsTheme.neonPink),
                  title: const Text("Saati Titret / Bul", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Kayıp saatin kuvvetli titremesini sağlar", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  trailing: ElevatedButton(
                    onPressed: ble.isConnected ? () => ble.vibrateWatch() : null,
                    style: ElevatedButton.styleFrom(backgroundColor: PbsTheme.neonPink.withOpacity(0.2), foregroundColor: PbsTheme.neonPink),
                    child: const Text("Titret", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const Divider(height: 1, color: Colors.white10),
                SwitchListTile(
                  secondary: const Icon(Icons.screen_lock_rotation, color: PbsTheme.cyan),
                  title: const Text("Bilek Hareketiyle Ekran Aç", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Kolunuzu kaldırdığınızda ekran otomatik uyanır", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  value: _raiseToWake,
                  activeColor: PbsTheme.cyan,
                  onChanged: ble.isConnected ? (val) {
                    setState(() => _raiseToWake = val);
                    ble.setRaiseToWake(val);
                  } : null,
                ),
                const Divider(height: 1, color: Colors.white10),
                SwitchListTile(
                  secondary: const Icon(Icons.access_time, color: PbsTheme.amber),
                  title: const Text("24 Saat Zaman Formatı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(_is24Hour ? "24 Saat (14:30)" : "12 Saat (2:30 PM)", style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  value: _is24Hour,
                  activeColor: PbsTheme.amber,
                  onChanged: ble.isConnected ? (val) {
                    setState(() => _is24Hour = val);
                    ble.setHourFormat(val);
                  } : null,
                ),
                const Divider(height: 1, color: Colors.white10),
                SwitchListTile(
                  secondary: const Icon(Icons.pan_tool, color: PbsTheme.electricBlue),
                  title: const Text("Takış Kolu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(_isLeftHand ? "Sol Kol" : "Sağ Kol", style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  value: _isLeftHand,
                  activeColor: PbsTheme.electricBlue,
                  onChanged: ble.isConnected ? (val) {
                    setState(() => _isLeftHand = val);
                    ble.setWearingHand(val);
                  } : null,
                ),
                const Divider(height: 1, color: Colors.white10),
                SwitchListTile(
                  secondary: const Icon(Icons.do_not_disturb_on, color: Colors.purpleAccent),
                  title: const Text("Rahatsız Etme Modu (DND)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Gece titreşim ve ekran uyanmasını engeller (23:00 - 07:00)", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  value: _dndEnabled,
                  activeColor: Colors.purpleAccent,
                  onChanged: ble.isConnected ? (val) {
                    setState(() => _dndEnabled = val);
                    ble.setDoNotDisturb(val);
                  } : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. SAĞLIK VE ALIŞKANLIK HATIRLATICILARI
          _buildSectionHeader("⏰ ALARMLAR & SAĞLIK HATIRLATICILARI"),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.alarm, color: PbsTheme.neonGreen),
                  title: const Text("Titreşimli Saat Alarmı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("Saat: ${_alarmTime.format(context)} (Bileğinizde sessizce titrer)", style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  trailing: ElevatedButton(
                    onPressed: ble.isConnected ? () async {
                      final picked = await showTimePicker(context: context, initialTime: _alarmTime);
                      if (picked != null) {
                        setState(() => _alarmTime = picked);
                        await ble.setAlarmClock(hour: picked.hour, minute: picked.minute);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Alarm saate ayarlandı: ${picked.format(context)}")),
                        );
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(backgroundColor: PbsTheme.neonGreen.withOpacity(0.2), foregroundColor: PbsTheme.neonGreen),
                    child: const Text("Ayarla", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const Divider(height: 1, color: Colors.white10),
                SwitchListTile(
                  secondary: const Icon(Icons.airline_seat_recline_normal, color: PbsTheme.amber),
                  title: const Text("Hareketsizlik Uyarısı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("60 dk hareketsiz oturulduğunda ayağa kalk uyarısı", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  value: _sedentaryEnabled,
                  activeColor: PbsTheme.amber,
                  onChanged: ble.isConnected ? (val) {
                    setState(() => _sedentaryEnabled = val);
                    ble.setSedentaryReminder(val);
                  } : null,
                ),
                const Divider(height: 1, color: Colors.white10),
                SwitchListTile(
                  secondary: const Icon(Icons.water_drop, color: PbsTheme.cyan),
                  title: const Text("Su İçme Hatırlatıcısı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Gün boyu düzenli su içme uyarısı verir", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  value: _drinkWaterEnabled,
                  activeColor: PbsTheme.cyan,
                  onChanged: ble.isConnected ? (val) {
                    setState(() => _drinkWaterEnabled = val);
                    ble.setDrinkWaterReminder(val);
                  } : null,
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.wb_sunny, color: Colors.orangeAccent),
                  title: const Text("Hava Durumu Senkronu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Saatin ekranındaki hava durumu widget'ını günceller", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  trailing: OutlinedButton(
                    onPressed: ble.isConnected ? () async {
                      await ble.pushWeather(currentTemp: 22, minTemp: 16, maxTemp: 25, city: "Istanbul");
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Hava durumu saate iletildi (22°C - Güneşli).")),
                      );
                    } : null,
                    child: const Text("Gönder", style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. BİLDİRİM VE ARAMA KÖPRÜSÜ
          _buildSectionHeader("📲 BİLDİRİM & ÇAĞRI KÖPRÜSÜ"),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.chat, color: PbsTheme.neonGreen),
                  title: const Text("WhatsApp Bildirimleri", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Gelen mesajlar başlık ve içerikle saate basılır", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  value: _whatsappEnabled,
                  activeColor: PbsTheme.neonGreen,
                  onChanged: (val) => setState(() => _whatsappEnabled = val),
                ),
                const Divider(height: 1, color: Colors.white10),
                SwitchListTile(
                  secondary: const Icon(Icons.phone_in_talk, color: PbsTheme.electricBlue),
                  title: const Text("Gelen Arama Uyarısı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Arayan kişi adı saatte görünür ve titrer", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  value: _callEnabled,
                  activeColor: PbsTheme.electricBlue,
                  onChanged: (val) => setState(() => _callEnabled = val),
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.send_to_mobile, color: Colors.white70),
                  title: const Text("Test Bildirimi Gönder", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Saate anında örnek WhatsApp mesajı basar", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  trailing: ElevatedButton(
                    onPressed: ble.isConnected ? () async {
                      await ble.pushNotification("Ahmet Yılmaz", "Selam, akşam görüşüyor muyuz?");
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Test bildirimi saate iletildi.")),
                      );
                    } : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                    child: const Text("Test Et", style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. CİHAZ YÖNETİMİ & VERİ DIŞA AKTARMA
          _buildSectionHeader("💾 VERİ & SIFIRLAMA"),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download, color: PbsTheme.cyan),
                  title: const Text("Tüm Biyometrik Verileri CSV İndir", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Kaydedilen nabız, tansiyon ve SpO2 raporunu kaydeder", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  onTap: () async {
                    try {
                      final path = await ble.storage.exportCsv();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: PbsTheme.cyan,
                          content: Text("Sağlık raporu kaydedildi:\n$path", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Hata: $e")),
                      );
                    }
                  },
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.restart_alt, color: PbsTheme.neonPink),
                  title: const Text("Fabrika Ayarlarına Sıfırla", style: TextStyle(color: PbsTheme.neonPink, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Saatteki tüm verileri sıfırlar", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  onTap: ble.isConnected ? () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: PbsTheme.cardDark,
                        title: const Text("Saati Sıfırla?"),
                        content: const Text("PBS 164 fabrika ayarlarına döndürülecektir."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: PbsTheme.neonPink),
                            onPressed: () {
                              Navigator.pop(ctx);
                              ble.sendPacket(Pbs164Protocol.buildPacket(13, 0));
                            },
                            child: const Text("Sıfırla"),
                          ),
                        ],
                      ),
                    );
                  } : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
      ),
    );
  }
}
