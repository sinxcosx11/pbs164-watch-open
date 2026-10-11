// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pbs164_pulse/main.dart';
import 'package:pbs164_pulse/services/ble_service.dart';
import 'package:pbs164_pulse/services/location_service.dart';

void main() {
  testWidgets('App shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PbsBleService()),
          ChangeNotifierProvider(create: (_) => PbsLocationService()),
        ],
        child: const PbsPulseApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PBS 164 PULSE'), findsOneWidget);
    expect(find.text('Özet'), findsOneWidget);
  });
}
