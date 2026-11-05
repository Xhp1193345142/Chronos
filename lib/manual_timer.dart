import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'storage/manual_store.dart';
import 'storage/manual_store_platform.dart'
    if (dart.library.io) 'storage/manual_store_native.dart'
    as platform_store;

const manualCategories = <String>[
  '未分类',
  '工作',
  '学习',
  '阅读',
  '运动',
  '休息',
  '生活',
  '社交',
  '其他',
];

class ManualSegment {
  const ManualSegment(this.start, this.end);

  final DateTime start;
  final DateTime? end;

  Duration elapsed(DateTime now) {
    final value = (end ?? now).difference(start);
    return value.isNegative ? Duration.zero : value;
  }

  Map<String, Object?> toJson() => {
    'start': start.toIso8601String(),
    'end': end?.toIso8601String(),
  };

  factory ManualSegment.fromJson(Map<String, dynamic> json) => ManualSegment(
    DateTime.parse(json['start'] as String).toUtc(),
    json['end'] == null ? null : DateTime.parse(json['end'] as String).toUtc(),
  );
}

class ManualEntry {
  const ManualEntry({
    required this.id,
    required this.category,
    required this.segments,
    this.note = '',
    this.completedAt,
  });

  final String id;
  final String category;
  final String note;
  final List<ManualSegment> segments;
  final DateTime? completedAt;

  bool get isActive => completedAt == null;
  bool get isRunning => isActive && segments.last.end == null;
  DateTime get startedAt => segments.first.start;
  DateTime? get endedAt => completedAt;

  Duration elapsed(DateTime now) => segments.fold(
    Duration.zero,
    (total, segment) => total + segment.elapsed(now),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'category': category,
    'note': note,
    'segments': segments.map((segment) => segment.toJson()).toList(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory ManualEntry.fromJson(Map<String, dynamic> json) {
    final segments = (json['segments'] as List<dynamic>)
        .map((value) => ManualSegment.fromJson(value as Map<String, dynamic>))
        .toList();
    if (segments.isEmpty) throw const FormatException('Empty timer entry');
    return ManualEntry(
      id: json['id'] as String,
      category: json['category'] as String? ?? '未分类',
      note: json['note'] as String? ?? '',
      segments: segments,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String).toUtc(),
    );
  }
}

/// Strict decoding is shared by migration and backup restoration. Invalid data
/// is never converted into an empty journal and never overwrites the source.
List<ManualEntry> decodeManualEntries(String raw) {
  if (utf8.encode(raw).length > 8 * 1024 * 1024) {
    throw const FormatException('备份超过 8 MB');
  }
  final decoded = jsonDecode(raw);
  if (decoded is! List || decoded.length > 50000) {
    throw const FormatException('记录格式或数量无效');
  }
  final entries = decoded
      .map((value) => ManualEntry.fromJson(value as Map<String, dynamic>))
      .toList();
  final ids = <String>{};
  final intervals = <ManualSegment>[];
  for (final entry in entries) {
    if (entry.id.isEmpty ||
        entry.id.length > 160 ||
        !ids.add(entry.id) ||
        !manualCategories.contains(entry.category) ||
        entry.note.length > 120) {
      throw const FormatException('分类、备注或记录标识无效');
    }
    DateTime? previousEnd;
    for (var i = 0; i < entry.segments.length; i++) {
      final segment = entry.segments[i];
      if (segment.start.year < 1970 ||
          segment.start.year > 2100 ||
          (segment.end != null && segment.end!.isBefore(segment.start)) ||
          (previousEnd != null && segment.start.isBefore(previousEnd)) ||
          (segment.end == null &&
              (i != entry.segments.length - 1 || !entry.isActive))) {
        throw const FormatException('计时时间段无效');
      }
      if (entry.completedAt != null &&
          (segment.end == null || segment.end!.isAfter(entry.completedAt!))) {
        throw const FormatException('结束时间无效');
      }
      previousEnd = segment.end;
      if (segment.end == null || segment.end!.isAfter(segment.start)) {
        intervals.add(segment);
      }
    }
  }
  if (entries.where((entry) => entry.isActive).length > 1) {
    throw const FormatException('只能恢复一个计时器');
  }
  intervals.sort((a, b) => a.start.compareTo(b.start));
  for (var i = 1; i < intervals.length; i++) {
    final prior = intervals[i - 1];
    if (prior.end == null || intervals[i].start.isBefore(prior.end!)) {
      throw const FormatException('备份包含重叠记录');
    }
  }
  return entries;
}

class ManualTimerController extends ChangeNotifier {
  ManualTimerController({DateTime Function()? clock, ManualRecordStore? store})
    : _clock = clock ?? DateTime.now,
      _store = store ?? platform_store.createManualStore();

  final DateTime Function() _clock;
  final ManualRecordStore _store;
  List<ManualEntry> _entries = [];
  Future<void>? _loadFuture;
  Future<void> _operations = Future.value();
  Timer? _ticker;
  bool _loaded = false;
  bool _loadFailed = false;
  bool _disposed = false;
  String? _error;
  int _nextId = 0;

  bool get loaded => _loaded;
  String? get error => _error;
  List<ManualEntry> get entries => List.unmodifiable(_entries);
  ManualEntry? get active =>
      _entries.where((entry) => entry.isActive).firstOrNull;
  DateTime get now => _clock().toUtc();
  Future<void> flush() => _operations;
  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      final raw = await _store.read();
      final entries = decodeManualEntries(raw ?? '[]');
      // The native store migrates legacy preferences in a single transaction.
      await _store.finishLoad(
        jsonEncode(entries.map((entry) => entry.toJson()).toList()),
      );
      _entries = entries;
    } catch (_) {
      _loadFailed = true;
      _error = '本机记录读取失败，原始数据已保留。请先保留应用并联系支持。';
    } finally {
      _loaded = true;
      _syncTicker();
      _notify();
    }
  }

  Future<T> _run<T>(Future<T> Function() action) {
    final result = _operations.then((_) async {
      await load();
      return action();
    });
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<bool> _commit(List<ManualEntry> next) async {
    try {
      final payload = jsonEncode(next.map((entry) => entry.toJson()).toList());
      // Apply the same constraints on writes and reads. A changed clock or a
      // full journal must never create data that cannot be loaded next time.
      decodeManualEntries(payload);
      await _store.write(payload);
      _entries = next;
      _error = null;
      _loadFailed = false;
      _syncTicker();
      _notify();
      return true;
    } on FormatException catch (error) {
      _error = '${error.message}，刚才的操作未生效。';
      _notify();
      return false;
    } catch (_) {
      _error = '保存失败，刚才的操作未生效。请检查设备空间后重试。';
      _notify();
      return false;
    }
  }

  Future<bool> start({String category = '未分类'}) => _run(() async {
    if (!manualCategories.contains(category)) {
      throw ArgumentError.value(category);
    }
    if (_loadFailed || active != null) return false;
    final start = now;
    return _commit([
      ManualEntry(
        id: '${start.microsecondsSinceEpoch}-${_nextId++}',
        category: category,
        segments: [ManualSegment(start, null)],
      ),
      ..._entries,
    ]);
  });

  Future<void> pause() => _run(() async {
    final current = active;
    if (_loadFailed || current == null || !current.isRunning) return;
    final end = now;
    if (end.isBefore(current.segments.last.start)) {
      _clockError();
      return;
    }
    await _replace(
      current,
      ManualEntry(
        id: current.id,
        category: current.category,
        note: current.note,
        segments: [
          ...current.segments.take(current.segments.length - 1),
          ManualSegment(current.segments.last.start, end),
        ],
      ),
    );
  });

  Future<void> resume() => _run(() async {
    final current = active;
    if (_loadFailed || current == null || current.isRunning) return;
    if (now.isBefore(current.segments.last.end!)) {
      _clockError();
      return;
    }
    await _replace(
      current,
      ManualEntry(
        id: current.id,
        category: current.category,
        note: current.note,
        segments: [...current.segments, ManualSegment(now, null)],
      ),
    );
  });

  Future<void> stop() => _run(() async {
    final current = active;
    if (_loadFailed || current == null) return;
    final end = now;
    if (end.isBefore(
      current.segments.last.end ?? current.segments.last.start,
    )) {
      _clockError();
      return;
    }
    final segments = current.isRunning
        ? [
            ...current.segments.take(current.segments.length - 1),
            ManualSegment(current.segments.last.start, end),
          ]
        : current.segments;
    await _replace(
      current,
      ManualEntry(
        id: current.id,
        category: current.category,
        note: current.note,
        segments: segments,
        completedAt: end,
      ),
    );
  });

  Future<void> setCategory(String id, String category) => _run(() async {
    if (_loadFailed || !manualCategories.contains(category)) return;
    final current = _find(id);
    if (current != null) {
      await _replace(
        current,
        ManualEntry(
          id: id,
          category: category,
          note: current.note,
          segments: current.segments,
          completedAt: current.completedAt,
        ),
      );
    }
  });

  Future<void> setNote(String id, String note) => _run(() async {
    if (_loadFailed) return;
    final current = _find(id);
    if (note.trim().length > 120) {
      _error = '备注最多 120 字';
      _notify();
      return;
    }
    if (current != null) {
      await _replace(
        current,
        ManualEntry(
          id: id,
          category: current.category,
          note: note.trim(),
          segments: current.segments,
          completedAt: current.completedAt,
        ),
      );
    }
  });

  Future<String?> saveInterval({
    String? id,
    required DateTime start,
    required DateTime end,
    required String category,
    String note = '',
  }) => _run(() async {
    if (_loadFailed) return _error;
    final from = start.toUtc();
    final to = end.toUtc();
    if (!to.isAfter(from)) return '结束时间必须晚于开始时间';
    if (to.isAfter(now)) return '结束时间不能晚于现在';
    if (!manualCategories.contains(category)) return '请选择有效分类';
    if (note.trim().length > 120) return '备注最多 120 字';
    final old = id == null ? null : _find(id);
    if (id != null && (old == null || old.isActive)) return '记录已不存在或仍在计时';
    final unchangedTimes =
        old != null &&
        old.startedAt.isAtSameMomentAs(from) &&
        old.endedAt!.isAtSameMomentAs(to);
    final hasPause =
        old != null &&
        (old.segments.length > 1 ||
            !old.segments.last.end!.isAtSameMomentAs(old.endedAt!));
    if (hasPause && !unchangedTimes) return '含暂停的记录请删除后补记，以免暂停时长被计入';
    if (!unchangedTimes && _overlaps(from, to, exceptId: id)) {
      return '这段时间已有手动记录';
    }
    final item = ManualEntry(
      id: id ?? '${now.microsecondsSinceEpoch}-${_nextId++}',
      category: category,
      note: note.trim(),
      segments: unchangedTimes ? old.segments : [ManualSegment(from, to)],
      completedAt: to,
    );
    final success = await _commit(
      id == null
          ? [item, ..._entries]
          : [for (final entry in _entries) entry.id == id ? item : entry],
    );
    return success ? null : _error;
  });

  Future<void> delete(String id) => _run(() async {
    if (!_loadFailed) {
      await _commit(_entries.where((entry) => entry.id != id).toList());
    }
  });

  Future<bool> clear() => _run(() => _commit([]));

  Future<String> exportBackup() => _run(() async {
    if (_loadFailed) throw StateError(_error!);
    final at = now;
    final snapshot = _entries.map((entry) {
      if (!entry.isActive) return entry.toJson();
      return ManualEntry(
        id: entry.id,
        category: entry.category,
        note: entry.note,
        completedAt: at,
        segments: entry.segments
            .map((s) => ManualSegment(s.start, s.end ?? at))
            .toList(),
      ).toJson();
    }).toList();
    decodeManualEntries(jsonEncode(snapshot));
    return jsonEncode({
      'format': 'chronos.manual-backup',
      'version': 1,
      'exportedAt': at.toIso8601String(),
      'entries': snapshot,
    });
  });

  static List<ManualEntry> readBackup(String raw) {
    if (utf8.encode(raw).length > 8 * 1024 * 1024) {
      throw const FormatException('备份超过 8 MB');
    }
    final data = jsonDecode(raw);
    if (data is! Map ||
        data['format'] != 'chronos.manual-backup' ||
        data['version'] != 1) {
      throw const FormatException('不是支持的 Chronos 备份');
    }
    final entries = decodeManualEntries(jsonEncode(data['entries']));
    if (entries.any((e) => e.isActive)) {
      throw const FormatException('备份不能含运行中的计时器');
    }
    return entries;
  }

  Future<String?> importBackup(String raw) => _run(() async {
    if (_loadFailed) return _error;
    if (active != null) return '请先结束当前计时，再恢复备份';
    try {
      final incoming = readBackup(raw);
      final combined = {for (final entry in _entries) entry.id: entry};
      for (final entry in incoming) {
        final old = combined[entry.id];
        if (old != null &&
            jsonEncode(old.toJson()) != jsonEncode(entry.toJson())) {
          return '备份与本机存在同名记录冲突，未修改任何记录';
        }
        combined[entry.id] = entry;
      }
      final next = decodeManualEntries(
        jsonEncode(combined.values.map((e) => e.toJson()).toList()),
      );
      return await _commit(next) ? null : _error;
    } on FormatException catch (error) {
      return error.message.toString();
    } catch (_) {
      return '备份文件无效，未修改任何记录';
    }
  });

  Future<String> exportCsv() => _run(() async {
    if (_loadFailed) throw StateError(_error!);
    String cell(String value) {
      // Prevent spreadsheet formula injection from user notes or imported data.
      if (RegExp(r'^\s*[=+\-@]|^[\t\r\n]').hasMatch(value)) value = "'$value";
      return '"${value.replaceAll('"', '""')}"';
    }

    final rows = <List<String>>[
      ['记录ID', '分类', '备注', '开始时间UTC', '结束时间UTC', '累计秒数', '状态'],
    ];
    for (final e in _entries) {
      rows.add([
        e.id,
        e.category,
        e.note,
        e.startedAt.toIso8601String(),
        e.endedAt?.toIso8601String() ?? '',
        e.elapsed(now).inSeconds.toString(),
        e.isActive ? '进行中' : '已结束',
      ]);
    }
    return '\uFEFF${rows.map((row) => row.map(cell).join(',')).join('\r\n')}';
  });

  void _clockError() {
    _error = '系统时间早于已保存的计时，请校准设备时间后重试。';
    _notify();
  }

  Future<bool> _replace(ManualEntry old, ManualEntry updated) => _commit([
    for (final entry in _entries) entry.id == old.id ? updated : entry,
  ]);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Duration durationForDay(DateTime localDay) {
    return _entries.fold(
      Duration.zero,
      (total, entry) => total + entryDurationForDay(entry, localDay),
    );
  }

  Duration entryDurationForDay(ManualEntry entry, DateTime localDay) {
    final start = DateTime(localDay.year, localDay.month, localDay.day);
    final end = DateTime(localDay.year, localDay.month, localDay.day + 1);
    final current = now;
    var total = Duration.zero;
    for (final segment in entry.segments) {
      final from = segment.start.toLocal();
      final to = (segment.end ?? current).toLocal();
      final clippedStart = from.isAfter(start) ? from : start;
      final clippedEnd = to.isBefore(end) ? to : end;
      if (clippedEnd.isAfter(clippedStart)) {
        total += clippedEnd.difference(clippedStart);
      }
    }
    return total;
  }

  List<ManualEntry> entriesForDay(DateTime localDay) {
    final start = DateTime(localDay.year, localDay.month, localDay.day);
    final end = DateTime(localDay.year, localDay.month, localDay.day + 1);
    return _entries.where((entry) {
      return entry.segments.any((segment) {
        final from = segment.start.toLocal();
        final to = (segment.end ?? now).toLocal();
        return from.isBefore(end) && to.isAfter(start);
      });
    }).toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  ManualEntry? _find(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  bool _overlaps(DateTime from, DateTime to, {String? exceptId}) {
    for (final entry in _entries) {
      if (entry.id == exceptId) continue;
      for (final segment in entry.segments) {
        final end = segment.end ?? now;
        if (from.isBefore(end) && to.isAfter(segment.start)) return true;
      }
    }
    return false;
  }

  void _syncTicker() {
    if (active?.isRunning == true && !_disposed) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    unawaited(
      Future.wait([_operations, _loadFuture ?? Future<void>.value()])
          .then((_) => _store.close())
          .catchError((Object _) {}),
    );
    super.dispose();
  }
}
