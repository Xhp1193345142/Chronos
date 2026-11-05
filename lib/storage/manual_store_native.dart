import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'manual_store.dart';

ManualRecordStore createManualStore() => Platform.isAndroid || Platform.isIOS
    ? SqliteManualStore()
    : PreferenceManualStore();

class SqliteManualStore extends ManualRecordStore {
  SqliteManualStore({this.path = 'chronos_journal.db'});
  final String path;
  Future<Database>? _opening;
  Map<String, String>? _saved;
  bool _needsMigration = false;

  Future<Database> _database() => _opening ??= openDatabase(
    path,
    version: 1,
    onConfigure: (db) async {
      await db.execute('PRAGMA synchronous = FULL');
    },
    onCreate: (db, _) async {
      await db.execute(
        'CREATE TABLE entries (id TEXT PRIMARY KEY, payload TEXT NOT NULL, active INTEGER NOT NULL)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX one_active_timer ON entries(active) WHERE active = 1',
      );
      await db.execute(
        'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
    },
  );

  @override
  Future<String?> read() async {
    final db = await _database();
    final initialized = await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['initialized'],
    );
    if (initialized.isEmpty) {
      _needsMigration = true;
      // Leave the old payload untouched until validation and transaction commit.
      return (await SharedPreferences.getInstance()).getString(legacyManualKey);
    }
    final rows = await db.query('entries');
    _saved = {
      for (final row in rows) row['id'] as String: row['payload'] as String,
    };
    return '[${_saved!.values.join(',')}]';
  }

  @override
  Future<void> write(String payload) async {
    final values = jsonDecode(payload) as List<dynamic>;
    final next = <String, String>{
      for (final value in values) value['id'] as String: jsonEncode(value),
    };
    final db = await _database();
    await db.transaction((tx) async {
      final old =
          _saved ??
          {
            for (final row in await tx.query('entries'))
              row['id'] as String: row['payload'] as String,
          };
      // Close the previous active row before opening another one.
      final batch = tx.batch();
      for (final id in old.keys.where(
        (id) => !next.containsKey(id) || old[id] != next[id],
      )) {
        batch.delete('entries', where: 'id = ?', whereArgs: [id]);
      }
      for (final value in values) {
        final id = value['id'] as String;
        if (old[id] == next[id]) continue;
        batch.insert('entries', {
          'id': id,
          'payload': next[id],
          'active': value['completedAt'] == null ? 1 : 0,
        });
      }
      batch.insert('metadata', {
        'key': 'initialized',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    });
    _saved = next;
    _needsMigration = false;
    // DB is authoritative only after a committed migration. Never fall back to
    // a stale preference snapshot after deletion or a later database failure.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(legacyManualKey)) {
        await prefs.remove(legacyManualKey);
      }
    } catch (_) {
      // Committed DB data stays authoritative even if legacy cleanup fails.
    }
  }

  @override
  Future<void> finishLoad(String validatedPayload) async {
    if (_needsMigration) await write(validatedPayload);
  }

  @override
  Future<void> close() async {
    if (_opening != null) await (await _opening!).close();
  }
}
