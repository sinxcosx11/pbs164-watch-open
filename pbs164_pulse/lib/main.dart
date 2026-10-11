import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'services/ble_service.dart';
import 'services/biofeedback_service.dart';
import 'services/debug_bridge.dart';
import 'services/location_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/health_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PbsBleService()),
        ChangeNotifierProvider(create: (_) => PbsLocationService()),
        ChangeNotifierProxyProvider<PbsBleService, BiofeedbackService>(
          create: (ctx) => BiofeedbackService(ctx.read<PbsBleService>()),
          update: (ctx, ble, prev) => prev ?? BiofeedbackService(ble),
        ),
      ],
      child: const PbsPulseApp(),
    ),
  );
}

class PbsPulseApp extends StatelessWidget {
  const PbsPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PBS 164 Pulse',
      debugShowCheckedModeBanner: false,
      theme: PbsTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PbsDebugBridge.start(context.read<PbsBleService>());
    });
  }

  final List<Widget> _screens = const [
    DashboardScreen(),
    WorkoutScreen(),
    HealthScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: PbsTheme.cardDark,
          indicatorColor: PbsTheme.cyan.withOpacity(0.18),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: PbsTheme.cyan, fontWeight: FontWeight.bold, fontSize: 11);
            }
            return const TextStyle(color: Colors.white54, fontSize: 11);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: PbsTheme.cyan),
              label: 'Özet',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_run_outlined),
              selectedIcon: Icon(Icons.directions_run, color: PbsTheme.cyan),
              label: 'Antrenman',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite, color: PbsTheme.neonPink),
              label: 'Sağlık',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings, color: PbsTheme.cyan),
              label: 'Ayarlar',
            ),
          ],
        ),
      ),
    );
  }
}
