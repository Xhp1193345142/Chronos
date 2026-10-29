import 'package:chronos/chronos_theme.dart';
import 'package:chronos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'manual theme switches without leaving the selected page and persists',
    (tester) async {
      await tester.pumpWidget(const ChronosApp(demoOnly: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('趋势').last);
      await tester.pumpAndSettle();
      expect(find.text('七天使用轨迹'), findsOneWidget);

      await tester.tap(find.byTooltip('切换主题'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('晨雾纸感'));
      await tester.pumpAndSettle();
      expect(find.text('七天使用轨迹'), findsOneWidget);
      expect(
        chronosColors(tester.element(find.byType(Scaffold).first)).background,
        ChronosPalette.morning.background,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('chronos_theme'), 'morning');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const ChronosApp(demoOnly: true));
      await tester.pumpAndSettle();
      expect(
        chronosColors(tester.element(find.byType(Scaffold).first)).accent,
        ChronosPalette.morning.accent,
      );
    },
  );

  testWidgets('system choice follows platform brightness', (tester) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    await tester.pumpWidget(const ChronosApp(demoOnly: true));
    await tester.pumpAndSettle();
    expect(
      chronosColors(tester.element(find.byType(Scaffold).first)).background,
      ChronosPalette.twilight.background,
    );

    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    await tester.pumpAndSettle();
    expect(
      chronosColors(tester.element(find.byType(Scaffold).first)).background,
      ChronosPalette.morning.background,
    );
  });

  testWidgets('all appearance choices remain reachable in a short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const ChronosApp(demoOnly: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('切换主题'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('日落脉冲'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日落脉冲'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      chronosColors(tester.element(find.byType(Scaffold).first)).accent,
      ChronosPalette.sunset.accent,
    );
  });
}
