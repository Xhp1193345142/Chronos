part of '../main.dart';

String _goalCheckLabel(String result) => switch (result) {
  'sent' => '提醒已提交系统',
  'already_notified' => '今天已提醒，不重复发送',
  'below_limit' => '尚未达到上限',
  'disabled' => '目标已关闭',
  'paused' => '今天已暂停',
  'permission_denied' => '使用权限未开启',
  'notifications_denied' => '系统或通知渠道未开启',
  'data_unavailable' => '当天数据无法核对，未发送提醒',
  'changed' => '目标已变化，请重新检查',
  'day_changed' => '日期已变化，请重新检查',
  'error' => '检查失败，请重试',
  _ => '尚未检查',
};

class _NativeStatus {
  const _NativeStatus({
    required this.usageGranted,
    required this.notificationsGranted,
    required this.openGoal,
    this.monitorScheduled = false,
  });

  final bool usageGranted;
  final bool notificationsGranted;
  final bool openGoal;
  final bool monitorScheduled;

  factory _NativeStatus.fromMap(Map<Object?, Object?> map) => _NativeStatus(
    usageGranted: map['usageGranted'] == true,
    notificationsGranted: map['notificationsGranted'] == true,
    openGoal: map['openGoal'] == true,
    monitorScheduled: map['monitorScheduled'] == true,
  );
}

class _LiveAppUsage {
  const _LiveAppUsage({
    required this.id,
    required this.label,
    required this.minutes,
    required this.category,
  });

  final String id;
  final String label;
  final int minutes;
  final String category;

  factory _LiveAppUsage.fromMap(Map<Object?, Object?> map) => _LiveAppUsage(
    id: map['id'] as String,
    label: map['label'] as String,
    minutes: (map['minutes'] as num).toInt(),
    category: map['category'] as String? ?? '其他',
  );
}

class _LiveDay {
  const _LiveDay({
    required this.date,
    required this.totalMinutes,
    required this.apps,
    required this.hourly,
    required this.available,
    required this.reason,
    required this.complete,
    this.source = '',
  });

  final DateTime date;
  final int totalMinutes;
  final List<_LiveAppUsage> apps;
  final List<int>? hourly;
  final bool available;
  final String reason;
  final bool complete;
  final String source;

  factory _LiveDay.fromMap(Map<Object?, Object?> map) => _LiveDay(
    date: DateTime.parse(map['date'] as String),
    totalMinutes: (map['totalMinutes'] as num).toInt(),
    apps: ((map['apps'] as List?) ?? const [])
        .map((item) => _LiveAppUsage.fromMap(item as Map<Object?, Object?>))
        .toList(),
    hourly: (map['hourly'] as List?)
        ?.map((item) => (item as num).toInt())
        .toList(),
    available: map['available'] == true,
    reason: map['reason'] as String? ?? '',
    complete: map['complete'] == true,
    source: map['source'] as String? ?? '',
  );
}

class _LiveSnapshot {
  const _LiveSnapshot({
    required this.state,
    required this.readAt,
    required this.days,
    required this.monthDays,
  });

  final String state;
  final DateTime? readAt;
  final List<_LiveDay> days;
  final List<_LiveDay> monthDays;

  _LiveDay? get today => days.isEmpty ? null : days.last;

  factory _LiveSnapshot.fromMap(Map<Object?, Object?> map) => _LiveSnapshot(
    state: map['state'] as String? ?? 'error',
    readAt: map['readAtMillis'] is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (map['readAtMillis'] as num).toInt(),
          )
        : null,
    days: ((map['days'] as List?) ?? const [])
        .map((item) => _LiveDay.fromMap(item as Map<Object?, Object?>))
        .toList(),
    monthDays: ((map['monthDays'] as List?) ?? const [])
        .map((item) => _LiveDay.fromMap(item as Map<Object?, Object?>))
        .toList(),
  );
}

class _LiveGoal {
  const _LiveGoal({
    required this.id,
    required this.name,
    required this.packageIds,
    required this.limitMinutes,
    required this.weekendLimitMinutes,
    required this.tone,
    required this.enabled,
    required this.pausedDate,
    required this.lastCheckedAt,
    this.lastCheckResult = 'never',
  });

  final String? id;
  final String name;
  final List<String> packageIds;
  final int limitMinutes;
  final int? weekendLimitMinutes;
  final String tone;
  final bool enabled;
  final String pausedDate;
  final DateTime? lastCheckedAt;
  final String lastCheckResult;

  factory _LiveGoal.fromMap(Map<Object?, Object?> map) => _LiveGoal(
    id: map['id'] as String?,
    name: map['name'] as String? ?? '我的目标',
    packageIds: ((map['packageIds'] as List?) ?? const []).cast<String>(),
    limitMinutes: (map['limitMinutes'] as num?)?.toInt() ?? 120,
    weekendLimitMinutes: (map['weekendLimitMinutes'] as num?)?.toInt(),
    tone: map['tone'] as String? ?? '直接',
    enabled: map['enabled'] == true,
    pausedDate: map['pausedDate'] as String? ?? '',
    lastCheckResult: map['lastCheckResult'] as String? ?? 'never',
    lastCheckedAt:
        map['lastCheckedAtMillis'] is num &&
            (map['lastCheckedAtMillis'] as num) > 0
        ? DateTime.fromMillisecondsSinceEpoch(
            (map['lastCheckedAtMillis'] as num).toInt(),
          )
        : null,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'packageIds': packageIds,
    'limitMinutes': limitMinutes,
    'weekendLimitMinutes': weekendLimitMinutes,
    'tone': tone,
    'enabled': enabled,
  };

  int limitFor(DateTime date) =>
      date.weekday >= 6 ? weekendLimitMinutes ?? limitMinutes : limitMinutes;
}

class _InsightPreferences {
  const _InsightPreferences({
    required this.enabled,
    required this.suppressedUntil,
  });
  final bool enabled;
  final DateTime? suppressedUntil;

  factory _InsightPreferences.fromMap(Map<Object?, Object?> map) {
    final millis = (map['weekRangeSuppressedUntil'] as num?)?.toInt() ?? 0;
    return _InsightPreferences(
      enabled: map['enabled'] == true,
      suppressedUntil: millis > 0
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : null,
    );
  }

  bool get showWeekRange =>
      enabled &&
      (suppressedUntil == null || suppressedUntil!.isBefore(DateTime.now()));
}

class _NativeBridge {
  static const _channel = MethodChannel('chronos/native');

  Future<void> checkGoalsNow() => _channel.invokeMethod('checkGoalsNow');

  void onGoalRequested(Future<void> Function()? callback) =>
      _channel.setMethodCallHandler(
        callback == null
            ? null
            : (call) async {
                if (call.method == 'openGoal') await callback();
              },
      );

  Future<_NativeStatus> status() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('status');
    return _NativeStatus.fromMap(map!);
  }

  Future<_LiveSnapshot> snapshot() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('snapshot');
    return _LiveSnapshot.fromMap(map!);
  }

  Future<_LiveGoal?> goal() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('getGoal');
    return map == null ? null : _LiveGoal.fromMap(map);
  }

  Future<List<_LiveGoal>> goals() async {
    final values = await _channel.invokeListMethod<Object?>('getGoals');
    return (values ?? const [])
        .map((value) => _LiveGoal.fromMap(value as Map<Object?, Object?>))
        .toList();
  }

  Future<_LiveGoal> saveGoal(_LiveGoal goal) async {
    final map = await _channel.invokeMapMethod<Object?, Object?>(
      'saveGoal',
      goal.toMap(),
    );
    return _LiveGoal.fromMap(map!);
  }

  Future<_LiveGoal?> setGoalEnabled(String id, bool enabled) async {
    final map = await _channel.invokeMapMethod<Object?, Object?>(
      'setGoalEnabled',
      {'id': id, 'enabled': enabled},
    );
    return map == null ? null : _LiveGoal.fromMap(map);
  }

  Future<_LiveGoal?> pauseGoalToday(String id) async {
    final map = await _channel.invokeMapMethod<Object?, Object?>(
      'pauseGoalToday',
      {'id': id},
    );
    return map == null ? null : _LiveGoal.fromMap(map);
  }

  Future<int?> selectedGoalMinutes(String id) =>
      _channel.invokeMethod<int>('selectedGoalMinutes', {'id': id});

  Future<void> deleteGoal(String id) =>
      _channel.invokeMethod('deleteGoal', {'id': id});

  Future<void> openUsageSettings() =>
      _channel.invokeMethod('openUsageSettings');
  Future<void> openNotificationSettings() =>
      _channel.invokeMethod('openNotificationSettings');
  Future<bool> requestNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestNotificationPermission') ??
      false;
  Future<void> deleteLocalData() => _channel.invokeMethod('deleteLocalData');

  Future<_InsightPreferences> insightPreferences() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>(
      'insightPreferences',
    );
    return _InsightPreferences.fromMap(map!);
  }

  Future<_InsightPreferences> setInsightsEnabled(bool enabled) async {
    final map = await _channel.invokeMapMethod<Object?, Object?>(
      'setInsightsEnabled',
      {'enabled': enabled},
    );
    return _InsightPreferences.fromMap(map!);
  }

  Future<_InsightPreferences> suppressWeekRange() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>(
      'suppressWeekRange',
    );
    return _InsightPreferences.fromMap(map!);
  }

  Future<_InsightPreferences> restoreInsights() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>(
      'restoreInsights',
    );
    return _InsightPreferences.fromMap(map!);
  }
}
