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
  });

  testWidgets('sample data stays labeled while navigating to goal controls', (
    tester,
  ) async {
    await tester.pumpWidget(const ChronosApp());
    expect(find.text('演示数据'), findsOneWidget);
    expect(find.text('今天，时间去了哪里？'), findsOneWidget);

    await tester.tap(find.text('目标').last);
    await tester.pumpAndSettle();
    expect(find.text('由你定义，更好的节奏。'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });
}
