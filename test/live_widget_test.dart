import 'package:chronos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('chronos/native');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('denied usage shows permission gateway without device totals', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'status':
              return {'usageGranted': false, 'notificationsGranted': false};
            case 'getGoals':
              return [];
            case 'insightPreferences':
              return {'enabled': true, 'weekRangeSuppressedUntil': 0};
            default:
              throw MissingPluginException(call.method);
          }
        });

    await tester.pumpWidget(const ChronosApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timer-start')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('连接设备使用时间'), 200);
    expect(find.text('连接设备使用时间'), findsOneWidget);
    expect(find.byKey(const Key('live-today-total')), findsNothing);
    await tester.scrollUntilVisible(find.text('先看演示数据'), 200);
    await tester.ensureVisible(find.text('先看演示数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('先看演示数据'));
    await tester.pumpAndSettle();
    expect(find.text('演示数据'), findsOneWidget);
  });

  testWidgets('manual timing starts from the denied-permission screen', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'status':
              return {'usageGranted': false, 'notificationsGranted': false};
            case 'getGoals':
              return [];
            case 'insightPreferences':
              return {'enabled': true, 'weekRangeSuppressedUntil': 0};
            default:
              throw MissingPluginException(call.method);
          }
        });

    await tester.pumpWidget(const ChronosApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('正在计时'), findsOneWidget);
    expect(find.byKey(const Key('live-today-total')), findsNothing);
    await tester.tap(find.byKey(const Key('timer-stop')));
    await tester.pump();
  });

  testWidgets('unreliable device totals explain why today is hidden', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'status':
              return {'usageGranted': true, 'notificationsGranted': false};
            case 'getGoals':
              return [];
            case 'insightPreferences':
              return {'enabled': true, 'weekRangeSuppressedUntil': 0};
            case 'snapshot':
              return {
                'state': 'empty',
                'days': [
                  {
                    'date': '2026-11-03',
                    'totalMinutes': 1439,
                    'available': false,
                    'reason': 'unreliable',
                    'complete': false,
                    'apps': [],
                  },
                ],
              };
            default:
              throw MissingPluginException(call.method);
          }
        });

    await tester.pumpWidget(const ChronosApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('设备数据暂无法核对'), 200);
    expect(find.text('设备数据暂无法核对'), findsOneWidget);
    expect(find.byKey(const Key('live-today-total')), findsNothing);
    await tester.scrollUntilVisible(find.textContaining('应用时长与屏幕交互时长不一致'), 200);
    expect(find.textContaining('应用时长与屏幕交互时长不一致'), findsOneWidget);
  });

  testWidgets('partial days show missing data instead of a zero-duration bar', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'status':
              return {'usageGranted': true, 'notificationsGranted': false};
            case 'getGoals':
              return [];
            case 'insightPreferences':
              return {'enabled': true, 'weekRangeSuppressedUntil': 0};
            case 'snapshot':
              return {
                'state': 'partial',
                'readAtMillis': DateTime(
                  2026,
                  10,
                  29,
                  16,
                ).millisecondsSinceEpoch,
                'days': List.generate(7, (index) {
                  final available = index >= 3 && index != 4;
                  return {
                    'date': '2026-10-${23 + index}',
                    'totalMinutes': index == 4
                        ? 1439
                        : available
                        ? 90 + index * 5
                        : 0,
                    'available': available,
                    'reason': index == 4 ? 'unreliable' : 'missing',
                    'complete': available && index < 6,
                    'hourly': null,
                    'apps': available
                        ? [
                            {
                              'id': 'com.example.video',
                              'label': '视频',
                              'minutes': 90 + index * 5,
                              'category': '影音娱乐',
                            },
                          ]
                        : [],
                  };
                }),
              };
            default:
              throw MissingPluginException(call.method);
          }
        });

    await tester.pumpWidget(const ChronosApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('live-today-total')),
      200,
    );
    expect(find.byKey(const Key('live-today-total')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('视频'), 200);
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('视频'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已知日期合计'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('趋势').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('无数据'), 250);
    expect(find.textContaining('无数据'), findsWidgets);
    await tester.scrollUntilVisible(find.text('完整日期的最大差异'), 250);
    expect(find.text('完整日期的最大差异'), findsOneWidget);
    expect(find.text('10 分钟'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoked usage permission clears live totals', (tester) async {
    var granted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'status':
              return {'usageGranted': granted, 'notificationsGranted': false};
            case 'getGoals':
              return [];
            case 'insightPreferences':
              return {'enabled': true, 'weekRangeSuppressedUntil': 0};
            case 'snapshot':
              return {
                'state': 'ready',
                'days': [
                  {
                    'date': '2026-10-29',
                    'totalMinutes': 60,
                    'available': true,
                    'complete': false,
                    'apps': [],
                  },
                ],
              };
            default:
              throw MissingPluginException(call.method);
          }
        });

    await tester.pumpWidget(const ChronosApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('live-today-total')),
      200,
    );
    expect(find.byKey(const Key('live-today-total')), findsOneWidget);
    granted = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('使用权限已关闭'), 200);
    expect(find.text('使用权限已关闭'), findsOneWidget);
    expect(find.byKey(const Key('live-today-total')), findsNothing);
  });

  testWidgets('multiple goals remain separate and weekend limit is editable', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'status':
              return {'usageGranted': true, 'notificationsGranted': false};
            case 'getGoals':
              return [
                {
                  'id': 'social',
                  'name': '社交应用',
                  'packageIds': ['com.example.social'],
                  'limitMinutes': 120,
                  'weekendLimitMinutes': 180,
                  'tone': '直接',
                  'enabled': true,
                },
                {
                  'id': 'reading',
                  'name': '阅读',
                  'packageIds': ['com.example.read'],
                  'limitMinutes': 60,
                  'tone': '温和',
                  'enabled': false,
                },
              ];
            case 'insightPreferences':
              return {'enabled': true, 'weekRangeSuppressedUntil': 0};
            case 'snapshot':
              return {
                'state': 'ready',
                'days': [
                  {
                    'date': '2026-10-29',
                    'totalMinutes': 90,
                    'available': true,
                    'complete': false,
                    'apps': [
                      {
                        'id': 'com.example.social',
                        'label': '社交',
                        'minutes': 50,
                      },
                      {'id': 'com.example.read', 'label': '阅读器', 'minutes': 40},
                    ],
                  },
                ],
              };
            case 'selectedGoalMinutes':
              return call.arguments['id'] == 'social' ? 50 : 40;
            default:
              throw MissingPluginException(call.method);
          }
        });

    await tester.pumpWidget(const ChronosApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('目标').last);
    await tester.pumpAndSettle();
    expect(find.text('社交应用'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('阅读'), 150);
    expect(find.text('阅读'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('社交应用'), -150);
    await tester.tap(find.text('社交应用'));
    await tester.pumpAndSettle();
    expect(find.text('周末使用不同上限'), findsOneWidget);
    expect(find.text('周末合计上限 · 3 小时'), findsOneWidget);
  });
}
