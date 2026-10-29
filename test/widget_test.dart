import 'package:chronos/demo_data.dart';
import 'package:chronos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    await tester.pumpWidget(const ChronosApp());
    expect(find.text('演示数据'), findsOneWidget);
    expect(find.text('今天少用 42 分钟'), findsOneWidget);
    expect(find.byKey(const Key('today-duration')), findsOneWidget);

    await tester.tap(find.text('目标').last);
    await tester.pumpAndSettle();
    expect(find.text('由你定义，更好的节奏。'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('selecting a day updates both trend charts', (tester) async {
    await tester.pumpWidget(const ChronosApp());
    await tester.tap(find.text('趋势').last);
    await tester.pumpAndSettle();

    expect(find.text('周一最多，周二最少'), findsOneWidget);
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
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ChronosApp());
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('hour-15')));
    await tester.pumpAndSettle();
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
