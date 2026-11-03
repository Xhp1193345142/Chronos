import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class ManualTimerController extends ChangeNotifier {
  ManualTimerController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _storageKey = 'chronos_manual_entries_v1';
  final DateTime Function() _clock;
  List<ManualEntry> _entries = [];
  Future<void>? _loadFuture;
  Future<void> _writeTail = Future.value();
  Timer? _ticker;
  bool _loaded = false;
  bool _disposed = false;
  String? _error;
  int _nextId = 0;

  bool get loaded => _loaded;
  String? get error => _error;
  List<ManualEntry> get entries => List.unmodifiable(_entries);
  ManualEntry? get active {
    for (final entry in _entries) {
      if (entry.isActive) return entry;
    }
    return null;
  }

  DateTime get now => _clock().toUtc();
  Future<void> flush() => _writeTail;

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final entries = decoded
            .map((item) => ManualEntry.fromJson(item as Map<String, dynamic>))
            .toList();
        if (entries.where((entry) => entry.isActive).length > 1) {
          throw const FormatException('Multiple active timers');
        }
        _entries = entries;
      }
    } catch (_) {
      _error = '本机计时记录暂时无法读取';
    } finally {
      _loaded = true;
      _syncTicker();
      notifyListeners();
    }
  }

  Future<bool> start({String category = '未分类'}) async {
    await load();
    if (!manualCategories.contains(category)) {
      throw ArgumentError.value(category, 'category', '未知的活动分类');
    }
    if (_error != null || active != null) return false;
    final start = now;
    _entries = [
      ManualEntry(
        id: '${start.microsecondsSinceEpoch}-${_nextId++}',
        category: category,
        segments: [ManualSegment(start, null)],
      ),
      ..._entries,
    ];
    _changed();
    await flush();
    return _error == null;
  }

  Future<void> pause() async {
    await load();
    final current = active;
    if (current == null || !current.isRunning) return;
    final end = now;
    _replace(
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
    await flush();
  }

  Future<void> resume() async {
    await load();
    final current = active;
    if (current == null || current.isRunning) return;
    _replace(
      current,
      ManualEntry(
        id: current.id,
        category: current.category,
        note: current.note,
        segments: [...current.segments, ManualSegment(now, null)],
      ),
    );
    await flush();
  }

  Future<void> stop() async {
    await load();
    final current = active;
    if (current == null) return;
    final end = now;
    final segments = current.isRunning
        ? [
            ...current.segments.take(current.segments.length - 1),
            ManualSegment(current.segments.last.start, end),
          ]
        : current.segments;
    _replace(
      current,
      ManualEntry(
        id: current.id,
        category: current.category,
        note: current.note,
        segments: segments,
        completedAt: end,
      ),
    );
    await flush();
  }

  Future<void> setCategory(String id, String category) async {
    await load();
    if (!manualCategories.contains(category)) return;
    final current = _find(id);
    if (current == null) return;
    _replace(
      current,
      ManualEntry(
        id: id,
        category: category,
        note: current.note,
        segments: current.segments,
        completedAt: current.completedAt,
      ),
    );
    await flush();
  }

  Future<void> setNote(String id, String note) async {
    await load();
    final current = _find(id);
    if (current == null) return;
    _replace(
      current,
      ManualEntry(
        id: id,
        category: current.category,
        note: note.trim(),
        segments: current.segments,
        completedAt: current.completedAt,
      ),
    );
    await flush();
  }

  Future<String?> saveInterval({
    String? id,
    required DateTime start,
    required DateTime end,
    required String category,
    String note = '',
  }) async {
    await load();
    if (_error != null) return _error;
    final from = start.toUtc();
    final to = end.toUtc();
    if (!to.isAfter(from)) return '结束时间必须晚于开始时间';
    if (to.isAfter(now)) return '结束时间不能晚于现在';
    if (!manualCategories.contains(category)) return '请选择有效分类';
    if (_overlaps(from, to, exceptId: id)) return '这段时间已有手动记录';
    final old = id == null ? null : _find(id);
    if (id != null && (old == null || old.isActive)) {
      return '记录已不存在或仍在计时';
    }
    final unchangedTimes =
        old != null &&
        old.startedAt.isAtSameMomentAs(from) &&
        old.endedAt!.isAtSameMomentAs(to);
    final hasPause =
        old != null &&
        (old.segments.length > 1 ||
            !old.segments.last.end!.isAtSameMomentAs(old.endedAt!));
    if (hasPause && !unchangedTimes) {
      return '含暂停的记录请删除后补记，以免暂停时长被计入';
    }
    final item = ManualEntry(
      id: id ?? '${now.microsecondsSinceEpoch}-${_nextId++}',
      category: category,
      note: note.trim(),
      segments: unchangedTimes ? old.segments : [ManualSegment(from, to)],
      completedAt: to,
    );
    if (id == null) {
      _entries = [item, ..._entries];
      _changed();
    } else {
      _replace(old!, item);
    }
    await flush();
    return _error;
  }

  Future<void> delete(String id) async {
    await load();
    _entries = _entries.where((entry) => entry.id != id).toList();
    _changed();
    await flush();
  }

  Future<bool> clear() async {
    await load();
    _entries = [];
    _error = null;
    _changed();
    await _writeTail;
    return _error == null;
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

  void _replace(ManualEntry old, ManualEntry updated) {
    _entries = [
      for (final entry in _entries) entry.id == old.id ? updated : entry,
    ];
    _changed();
  }

  void _changed() {
    _error = null;
    _syncTicker();
    notifyListeners();
    final snapshot = jsonEncode(
      _entries.map((entry) => entry.toJson()).toList(),
    );
    _writeTail = _writeTail.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(_storageKey, snapshot)) {
          throw StateError('Failed to save timer records');
        }
      } catch (_) {
        _error = '本机计时记录暂时无法保存';
        if (!_disposed) notifyListeners();
      }
    });
  }

  void _syncTicker() {
    if (active?.isRunning == true) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        notifyListeners();
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
