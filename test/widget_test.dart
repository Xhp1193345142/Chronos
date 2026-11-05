import 'dart:convert';

import 'package:chronos/demo_data.dart';
import 'package:chronos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('formatMinutes handles minutes and whole hours', () {
    expect(formatMinutes(22), '22 分钟');
    expect(formatMinutes(120), '2 小时');
    expect(formatMinutes(342), '5 小时 42 分钟');
  });

  test('demo chart data agrees on the current day total', () {
    expect(DemoData.todayMinutes, 342);
    expect(DemoData.week[DemoData.todayIndex], DemoData.todayMinutes);
    expect(DemoData.hourly.reduce((a, b) => a + b), DemoData.todayMinutes);
    expect(DemoData.lastWeekSameDayMinutes - DemoData.todayMinutes, 42);
    expect(DemoData.weekAverageMinutes, 339);
    for (var day = 0; day < DemoData.week.length; day++) {
      expect(
        DemoData.hourlyForDay(day).reduce((a, b) => a + b),
        DemoData.week[day],
      );
    }
    expect(DemoData.peakWindowStart(DemoData.hourly), 18);
    expect(DemoData.peakWindowMinutes(DemoData.hourly), 100);
  });

  testWidgets('sample data stays labeled while navigating to goal controls', (
    tester,
  ) async {
    await tester.pumpWidget(const ChronosApp(demoOnly: true));
    expect(find.text('演示数据'), findsOneWidget);
    expect(find.byKey(const Key('timer-start')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('比上周同日少 42 分钟'), 200);
    expect(find.text('比上周同日少 42 分钟'), findsOneWidget);
    expect(find.byKey(const Key('today-duration')), findsOneWidget);

    await tester.tap(find.text('目标').last);
    await tester.pumpAndSettle();
    expect(find.text('提醒只针对你设置的上限。'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(Slider), 200);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('opening the app and tapping once starts a local timer', (
    tester,
  ) async {
    await tester.pumpWidget(const ChronosApp(demoOnly: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('正在计时'), findsOneWidget);
    expect(find.byKey(const Key('timer-elapsed')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byKey(const Key('timer-pause-resume')));
    await tester.pump();
    expect(find.text('已暂停'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timer-stop')));
    await tester.pump();
    expect(find.byKey(const Key('timer-start')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('1 段'), 200);
    expect(find.text('1 段'), findsOneWidget);
  });

  testWidgets('a quick action starts a categorized local timer', (
    tester,
  ) async {
    await tester.pumpWidget(const ChronosApp(demoOnly: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timer-quick-阅读')));
    await tester.pump();
    expect(find.text('正在计时'), findsOneWidget);
    expect(find.text('阅读'), findsWidgets);
    await tester.tap(find.byKey(const Key('timer-stop')));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('1 段'), 200);
    expect(find.text('阅读'), findsWidgets);
  });

  testWidgets(
    'journal sample is labeled, read only and leaves local records empty',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const ChronosApp(demoOnly: true));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('看看手账样例  ↗'), 150);
      await Scrollable.ensureVisible(
        tester.element(find.text('看看手账样例  ↗')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('看看手账样例  ↗'));
      await tester.pumpAndSettle();
      expect(find.text('只读样例 · 不保存到本机'), findsOneWidget);
      expect(find.text('04:05:00'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('去河边走一走'), 150);
      expect(find.text('去河边走一走'), findsOneWidget);
      expect(find.text('保存记录'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'chronos_manual_entries_v1',
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('0 段'), findsOneWidget);
    },
  );

  testWidgets(
    'journal clips a crossing-midnight record and counts paused segments',
    (tester) async {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      SharedPreferences.setMockInitialValues({
        'chronos_manual_entries_v1': jsonEncode([
          {
            'id': 'cross-midnight',
            'category': '阅读',
            'note': '跨夜阅读',
            'segments': [
              {
                'start': midnight
                    .subtract(const Duration(minutes: 10))
                    .toUtc()
                    .toIso8601String(),
                'end': midnight
                    .add(const Duration(minutes: 10))
                    .toUtc()
                    .toIso8601String(),
              },
              {
                'start': midnight
                    .add(const Duration(minutes: 20))
                    .toUtc()
                    .toIso8601String(),
                'end': midnight
                    .add(const Duration(minutes: 30))
                    .toUtc()
                    .toIso8601String(),
              },
            ],
            'completedAt': midnight
                .add(const Duration(minutes: 30))
                .toUtc()
                .toIso8601String(),
          },
        ]),
      });
      await tester.pumpWidget(const ChronosApp(demoOnly: true));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('跨夜阅读'), 150);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('00:30'), findsOneWidget);
      expect(find.text('00:20:00'), findsWidgets);
      expect(find.text('含暂停 · 仅累计实际计时'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selecting a day updates both trend charts', (tester) async {
    await tester.pumpWidget(const ChronosApp(demoOnly: true));
    await tester.tap(find.text('趋势').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('周一最多，周二最少'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('week-day-0')), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('week-day-0')));
    await tester.pumpAndSettle();
    final peak = tester.widget<Text>(
      find.byKey(const Key('selected-day-peak')),
    );
    expect(peak.data, contains('周五'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('selected-day-duration')),
      200,
    );
    expect(find.text('周五  5 小时 12 分钟'), findsOneWidget);
  });

  testWidgets('main charts fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ChronosApp(demoOnly: true));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.byKey(const Key('hour-15')), 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('hour-15')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('15:00–16:00  ·  34 分钟'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('影音娱乐'), 200);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('趋势').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('目标').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
