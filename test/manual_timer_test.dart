import 'package:chronos/manual_timer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('one tap starts and a running timer recovers after reload', () async {
    var current = DateTime.utc(2026, 10, 30, 8);
    final first = ManualTimerController(clock: () => current);
    expect(await first.start(), isTrue);
    expect(first.active?.category, '未分类');
    await first.flush();
    first.dispose();

    current = current.add(const Duration(minutes: 42));
    final restored = ManualTimerController(clock: () => current);
    await restored.load();
    expect(restored.active?.elapsed(restored.now), const Duration(minutes: 42));
    await restored.stop();
    expect(restored.active, isNull);
    expect(
      restored.entries.single.elapsed(restored.now),
      const Duration(minutes: 42),
    );
    restored.dispose();
  });

  test('pause is excluded from elapsed time and survives reload', () async {
    var current = DateTime.utc(2026, 10, 30, 8);
    final timer = ManualTimerController(clock: () => current);
    await timer.start();
    current = current.add(const Duration(minutes: 20));
    await timer.pause();
    current = current.add(const Duration(minutes: 30));
    expect(timer.active?.elapsed(timer.now), const Duration(minutes: 20));
    await timer.resume();
    current = current.add(const Duration(minutes: 10));
    await timer.stop();
    expect(
      timer.entries.single.elapsed(timer.now),
      const Duration(minutes: 30),
    );
    final saved = timer.entries.single;
    expect(
      await timer.saveInterval(
        id: saved.id,
        start: saved.startedAt,
        end: saved.endedAt!,
        category: '阅读',
      ),
      isNull,
    );
    expect(
      timer.entries.single.elapsed(timer.now),
      const Duration(minutes: 30),
    );

    final restored = ManualTimerController(clock: () => current);
    await restored.load();
    expect(
      restored.entries.single.elapsed(restored.now),
      const Duration(minutes: 30),
    );
    timer.dispose();
    restored.dispose();
  });

  test('cross-midnight minutes split by local calendar day', () async {
    final start = DateTime(2026, 10, 29, 23, 45);
    final end = DateTime(2026, 10, 30, 0, 15);
    final timer = ManualTimerController(clock: () => DateTime(2026, 10, 30, 1));
    expect(
      await timer.saveInterval(start: start, end: end, category: '阅读'),
      isNull,
    );
    expect(timer.durationForDay(start), const Duration(minutes: 15));
    expect(timer.durationForDay(end), const Duration(minutes: 15));
    expect(
      timer.entryDurationForDay(timer.entries.single, end),
      const Duration(minutes: 15),
    );
    timer.dispose();
  });

  test('backfill refuses overlap, allows editing and clearing', () async {
    final clock = DateTime.utc(2026, 10, 30, 12);
    final timer = ManualTimerController(clock: () => clock);
    final from = clock.subtract(const Duration(hours: 2));
    final to = clock.subtract(const Duration(hours: 1));
    expect(
      await timer.saveInterval(start: from, end: to, category: '工作'),
      isNull,
    );
    expect(
      await timer.saveInterval(
        start: from.add(const Duration(minutes: 20)),
        end: clock,
        category: '学习',
      ),
      '这段时间已有手动记录',
    );
    final id = timer.entries.single.id;
    expect(
      await timer.saveInterval(
        id: id,
        start: from,
        end: to,
        category: '阅读',
        note: '纸质书',
      ),
      isNull,
    );
    expect(timer.entries.single.category, '阅读');
    expect(timer.entries.single.note, '纸质书');
    await timer.clear();
    expect(timer.entries, isEmpty);
    final restored = ManualTimerController(clock: () => clock);
    await restored.load();
    expect(restored.entries, isEmpty);
    timer.dispose();
    restored.dispose();
  });
}
