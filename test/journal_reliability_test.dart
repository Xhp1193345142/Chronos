import 'dart:convert';
import 'dart:io';

import 'package:chronos/manual_timer.dart';
import 'package:chronos/storage/manual_store.dart';
import 'package:chronos/storage/manual_store_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FaultStore extends ManualRecordStore {
  String? payload;
  bool fail = false;
  @override
  Future<String?> read() async => payload;
  @override
  Future<void> write(String value) async {
    if (fail) throw const FileSystemException('disk full');
    payload = value;
  }

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('failed pause, stop and delete keep the last committed record and can retry', () async {
    var now = DateTime.utc(2026, 11, 5, 9);
    final store = FaultStore();
    final timer = ManualTimerController(store: store, clock: () => now);
    await timer.start(category: '工作');
    final saved = store.payload;
    store.fail = true;
    now = now.add(const Duration(minutes: 10));
    await timer.pause();
    expect(timer.active!.isRunning, isTrue);
    await timer.stop();
    expect(timer.active, isNotNull);
    await timer.delete(timer.active!.id);
    expect(timer.entries.length, 1);
    expect(store.payload, saved);
    expect(timer.error, contains('未生效'));
    store.fail = false;
    await timer.stop();
    expect(timer.active, isNull);
    expect(timer.error, isNull);
    expect(timer.entries.single.elapsed(now), const Duration(minutes: 10));
    timer.dispose();
  });

  test(
    'concurrent starts serialize and create only one active timer',
    () async {
      final timer = ManualTimerController(store: FaultStore());
      final results = await Future.wait([
        timer.start(),
        timer.start(),
        timer.start(),
      ]);
      expect(results.where((value) => value).length, 1);
      expect(timer.entries.length, 1);
      timer.dispose();
    },
  );

  test('backup closes its own snapshot, preserves the running timer and merges idempotently', () async {
    var now = DateTime.utc(2026, 11, 5, 9);
    final timer = ManualTimerController(store: FaultStore(), clock: () => now);
    await timer.start(category: '阅读');
    now = now.add(const Duration(minutes: 15));
    await timer.pause();
    now = now.add(const Duration(minutes: 5));
    await timer.resume();
    now = now.add(const Duration(minutes: 10));
    final backup = await timer.exportBackup();
    expect(timer.active!.isRunning, isTrue);
    final snapshot = ManualTimerController.readBackup(backup).single;
    expect(snapshot.isActive, isFalse);
    expect(snapshot.elapsed(now), const Duration(minutes: 25));
    final restored = ManualTimerController(
      store: FaultStore(),
      clock: () => now,
    );
    expect(await restored.importBackup(backup), isNull);
    expect(await restored.importBackup(backup), isNull);
    expect(restored.entries.length, 1);
    final conflict = jsonDecode(backup) as Map<String, dynamic>;
    conflict['entries'][0]['note'] = 'conflict';
    expect(await restored.importBackup(jsonEncode(conflict)), contains('冲突'));
    expect(restored.entries.single.note, isEmpty);
    final overlapping = jsonDecode(backup) as Map<String, dynamic>;
    overlapping['entries'][0]['id'] = 'different-id';
    expect(
      await restored.importBackup(jsonEncode(overlapping)),
      contains('重叠'),
    );
    expect(restored.entries.length, 1);
    timer.dispose();
    restored.dispose();
  });

  test(
    'malformed legacy data is preserved and cannot be overwritten by start',
    () async {
      final store = FaultStore()..payload = '{broken';
      final timer = ManualTimerController(store: store);
      await timer.load();
      expect(timer.error, contains('原始数据已保留'));
      expect(await timer.start(), isFalse);
      expect(store.payload, '{broken');
      timer.dispose();
    },
  );

  test(
    'clock rollback cannot create an overlapping record that fails on reload',
    () async {
      var now = DateTime.utc(2026, 11, 5, 9);
      final store = FaultStore();
      final timer = ManualTimerController(store: store, clock: () => now);
      await timer.start();
      now = now.add(const Duration(hours: 1));
      await timer.stop();
      final saved = store.payload;
      now = now.subtract(const Duration(minutes: 30));
      expect(await timer.start(), isFalse);
      expect(timer.entries.length, 1);
      expect(store.payload, saved);
      expect(timer.error, contains('重叠'));
      timer.dispose();
    },
  );

  test(
    'editing a paused record preserves a separate activity inside its pause',
    () async {
      var now = DateTime.utc(2026, 11, 5, 9);
      final timer = ManualTimerController(
        store: FaultStore(),
        clock: () => now,
      );
      await timer.start(category: '工作');
      now = now.add(const Duration(minutes: 10));
      await timer.pause();
      now = now.add(const Duration(minutes: 10));
      await timer.resume();
      now = now.add(const Duration(minutes: 10));
      await timer.stop();
      final work = timer.entries.single;
      expect(
        await timer.saveInterval(
          start: DateTime.utc(2026, 11, 5, 9, 10),
          end: DateTime.utc(2026, 11, 5, 9, 20),
          category: '休息',
        ),
        isNull,
      );
      expect(
        await timer.saveInterval(
          id: work.id,
          start: work.startedAt,
          end: work.endedAt!,
          category: '学习',
          note: '保留暂停',
        ),
        isNull,
      );
      expect(
        timer.entries.firstWhere((e) => e.id == work.id).elapsed(now),
        const Duration(minutes: 20),
      );
      expect(timer.entries.length, 2);
      timer.dispose();
    },
  );

  test('CSV quotes notes and neutralizes spreadsheet formulas', () async {
    final now = DateTime.utc(2026, 11, 5, 12);
    final timer = ManualTimerController(store: FaultStore(), clock: () => now);
    await timer.saveInterval(
      start: now.subtract(const Duration(hours: 1)),
      end: now,
      category: '工作',
      note: '=SUM(1,2) "quoted"',
    );
    final csv = await timer.exportCsv();
    expect(csv, contains('"\'=SUM(1,2) ""quoted"""'));
    expect(csv, startsWith('\uFEFF'));
    timer.dispose();
  });

  test('SQLite migrates legacy records, survives reopen and never resurrects cleared data', () async {
    final temp = await Directory.systemTemp.createTemp('chronos-db-test-');
    final path = '${temp.path}/journal.db';
    final legacy = FaultStore();
    final original = ManualTimerController(store: legacy);
    await original.start(category: '学习');
    await original.pause();
    SharedPreferences.setMockInitialValues({legacyManualKey: legacy.payload!});
    final store = SqliteManualStore(path: path);
    final migrated = ManualTimerController(store: store);
    await migrated.load();
    expect(migrated.error, isNull);
    expect(migrated.active!.category, '学习');
    expect(
      (await SharedPreferences.getInstance()).containsKey(legacyManualKey),
      isFalse,
    );
    await store.close();
    final store2 = SqliteManualStore(path: path);
    final reopened = ManualTimerController(store: store2);
    await reopened.load();
    expect(reopened.entries.single.id, migrated.entries.single.id);
    expect(await reopened.clear(), isTrue);
    await store2.close();
    SharedPreferences.setMockInitialValues({legacyManualKey: legacy.payload!});
    final store3 = SqliteManualStore(path: path);
    final cleared = ManualTimerController(store: store3);
    await cleared.load();
    expect(cleared.entries, isEmpty);
    await store3.close();
    original.dispose();
    migrated.dispose();
    reopened.dispose();
    cleared.dispose();
    await temp.delete(recursive: true);
  });
}
