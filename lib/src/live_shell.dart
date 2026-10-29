part of '../main.dart';

class _LiveExperience extends StatefulWidget {
  const _LiveExperience();

  @override
  State<_LiveExperience> createState() => _LiveExperienceState();
}

class _LiveExperienceState extends State<_LiveExperience>
    with WidgetsBindingObserver {
  final _bridge = _NativeBridge();
  _NativeStatus? _status;
  _LiveSnapshot? _snapshot;
  _LiveGoal? _goal;
  _InsightPreferences? _insightPrefs;
  int? _goalUsedMinutes;
  String? _error;
  bool _loading = true;
  bool _demo = false;
  bool _hadUsageAccess = false;
  int _refreshVersion = 0;
  int _tab = 0;
  int _selectedDay = 6;
  int _selectedMonthDay = 29;
  int _selectedHour = 19;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_demo) _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted || _demo) return;
    final version = ++_refreshVersion;
    if (_snapshot == null) setState(() => _loading = true);
    try {
      final status = await _bridge.status();
      final goal = await _bridge.goal();
      final insightPrefs = await _bridge.insightPreferences();
      final snapshot = status.usageGranted ? await _bridge.snapshot() : null;
      final used = status.usageGranted && goal != null
          ? await _bridge.selectedGoalMinutes()
          : null;
      if (!mounted || _demo || version != _refreshVersion) return;
      setState(() {
        _status = status;
        if (status.usageGranted) _hadUsageAccess = true;
        _goal = goal;
        _insightPrefs = insightPrefs;
        _snapshot = snapshot;
        _goalUsedMinutes = used;
        _selectedDay = snapshot == null || snapshot.days.isEmpty
            ? 0
            : _selectedDay.clamp(0, snapshot.days.length - 1);
        _selectedMonthDay = snapshot == null || snapshot.monthDays.isEmpty
            ? 0
            : _selectedMonthDay.clamp(0, snapshot.monthDays.length - 1);
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || _demo || version != _refreshVersion) return;
      setState(() {
        _error = error is MissingPluginException ? '此平台尚未接入系统使用时间' : '读取失败，请重试';
        _loading = false;
      });
    }
  }

  Future<void> _openUsageSettings() async {
    try {
      await _bridge.openUsageSettings();
    } catch (_) {
      if (mounted) _message('系统设置暂不可用');
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  void _exitDemo() {
    setState(() {
      _demo = false;
      _loading = true;
    });
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_demo) return ChronosHome(onExitDemo: _exitDemo);
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: lime)),
      );
    }
    if (_error != null) {
      return _gateway(
        title: _error!,
        body: '设备数据未载入。演示模式会始终标注示例数据。',
        primary: '重试',
        onPrimary: _refresh,
      );
    }
    if (_status?.usageGranted != true) {
      if (_tab == 2 && _goal != null) return _permissionGoalPage();
      return _gateway(
        title: _hadUsageAccess ? '使用权限已关闭' : '连接设备使用时间',
        body: _hadUsageAccess
            ? '无法继续读取设备使用时间，目标监测也暂不可用。已保存的目标仍留在本机。'
            : 'Chronos 需要你在系统设置中允许读取应用使用情况。数据只用于本机图表和你设置的目标。',
        primary: '打开使用权限设置',
        onPrimary: _openUsageSettings,
        secondary: _goal == null ? null : '管理已保存的目标',
        onSecondary: () => setState(() => _tab = 2),
      );
    }
    if (_snapshot?.state == 'permissionDenied') {
      return _gateway(
        title: '使用权限已关闭',
        body: '无法读取设备使用时间，目标监测也暂不可用。',
        primary: '检查系统权限',
        onPrimary: _openUsageSettings,
      );
    }
    return _liveScaffold();
  }

  Widget _permissionGoalPage() => Scaffold(
    appBar: AppBar(
      title: const Text('已保存的目标'),
      actions: [
        IconButton(
          tooltip: '设置',
          onPressed: _showSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: _goalsPage(),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => setState(() => _tab = 0),
      label: const Text('返回授权说明'),
      icon: const Icon(Icons.arrow_back),
    ),
  );

  Widget _gateway({
    required String title,
    required String body,
    required String primary,
    required VoidCallback onPrimary,
    String? secondary,
    VoidCallback? onSecondary,
  }) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.access_time_filled_rounded,
                  color: lime,
                  size: 46,
                ),
                const SizedBox(height: 28),
                _Heading(title),
                const SizedBox(height: 12),
                Text(body, style: const TextStyle(color: sub, height: 1.5)),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onPrimary,
                    child: Text(primary),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      _refreshVersion++;
                      setState(() => _demo = true);
                    },
                    child: const Text('先看演示数据'),
                  ),
                ),
                if (secondary != null)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onSecondary,
                      child: Text(secondary),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _showSettings,
                    child: const Text('设置与本地数据'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _liveScaffold() => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 610),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 15, 15, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_filled_rounded,
                      color: lime,
                      size: 27,
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'CHRONOS',
                      style: TextStyle(
                        color: ink,
                        fontSize: 15,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    const _Badge('设备数据'),
                    IconButton(
                      tooltip: '设置',
                      onPressed: _showSettings,
                      icon: const Icon(Icons.settings_outlined, color: sub),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [_todayPage(), _trendsPage(), _goalsPage()],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 610),
          child: _Nav(
            tab: _tab,
            onTap: (value) => setState(() => _tab = value),
          ),
        ),
      ),
    ),
  );

  Widget _todayPage() {
    final snapshot = _snapshot!;
    final today = snapshot.today;
    if (today == null || !today.available) {
      return _page([
        const _Eyebrow('今日'),
        const SizedBox(height: 8),
        const _Heading('还没有可展示的使用记录'),
        const SizedBox(height: 14),
        _card(
          const Text(
            '设备已授权。使用手机一段时间后再刷新；这里不会把缺失数据算成 0 分钟。',
            style: TextStyle(color: sub, height: 1.5),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _refresh, child: const Text('刷新')),
      ]);
    }
    final top = today.apps.isEmpty ? null : today.apps.first;
    return _page([
      _Eyebrow(
        '星期${_weekday(today.date)}  /  ${today.date.month}月${today.date.day}日',
      ),
      const SizedBox(height: 6),
      const _Heading('今天的屏幕时间'),
      const SizedBox(height: 5),
      _Hint('最近读取 ${_clock(snapshot.readAt)} · 应用前台时长合计'),
      const SizedBox(height: 20),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle('今日累计', Icons.phone_iphone_rounded),
            const SizedBox(height: 16),
            Text(
              formatMinutes(today.totalMinutes),
              key: const Key('live-today-total'),
              style: const TextStyle(
                color: ink,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const _Hint('已记录应用的前台使用时长'),
            if (top != null) ...[
              const Divider(color: line, height: 28),
              Text(
                '最多：${top.label}  ·  ${formatMinutes(top.minutes)}',
                style: const TextStyle(color: sub, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (today.hourly != null && today.hourly!.length == 24)
        _card(
          _LiveHourlyChart(
            hours: today.hourly!,
            selectedHour: _selectedHour,
            onSelect: (value) => setState(() => _selectedHour = value),
          ),
        )
      else
        _card(
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle('使用时段', Icons.waves_rounded),
              SizedBox(height: 10),
              Text(
                '当前设备尚未提供可核对的小时分布，下面仍可查看应用去向。',
                style: TextStyle(color: sub, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      const SizedBox(height: 24),
      const _Section('时间去了哪里', '按应用时长排序'),
      const SizedBox(height: 12),
      _card(
        _LiveAppList(
          apps: today.apps,
          totalMinutes: today.totalMinutes,
          onAppTap: _showAppDetails,
        ),
      ),
      const SizedBox(height: 23),
      const _Section('你的目标', '按自己设定的标准提醒'),
      const SizedBox(height: 12),
      _goalSummary(onTap: () => setState(() => _tab = 2)),
    ]);
  }

  Widget _trendsPage() {
    final days = _snapshot!.days;
    if (days.isEmpty) {
      return _page([
        const _Eyebrow('最近七天的屏幕节奏'),
        const SizedBox(height: 8),
        const _Heading('还没有可展示的趋势'),
        const SizedBox(height: 14),
        _card(const Text('使用记录载入后，这里会显示每日累计。', style: TextStyle(color: sub))),
      ]);
    }
    final complete = days.where((day) => day.complete).toList();
    final maxDay = complete.isEmpty
        ? null
        : complete.reduce((a, b) => a.totalMinutes >= b.totalMinutes ? a : b);
    final minDay = complete.isEmpty
        ? null
        : complete.reduce((a, b) => a.totalMinutes <= b.totalMinutes ? a : b);
    final selectedDay = days[_selectedDay.clamp(0, days.length - 1)];
    final baselineSamples = _snapshot!.monthDays
        .where(
          (day) =>
              day.available &&
              day.complete &&
              day.date.weekday == selectedDay.date.weekday &&
              day.date.isBefore(selectedDay.date),
        )
        .toList()
        .reversed
        .take(3)
        .toList();
    return _page([
      const _Eyebrow('最近七天的屏幕节奏'),
      const SizedBox(height: 6),
      _Heading(
        maxDay != null && minDay != null && complete.length >= 2
            ? '最多和最少相差 ${formatMinutes(maxDay.totalMinutes - minDay.totalMinutes)}'
            : '开始积累你的使用记录',
      ),
      const SizedBox(height: 6),
      const _Hint('今天仍在进行中；无数据日期不参与排名'),
      const SizedBox(height: 20),
      if (days.any((day) => day.hourly?.length == 24)) ...[
        _card(
          _SevenDayHourly(
            days: days,
            selected: _selectedDay,
            onSelect: (value) => setState(() => _selectedDay = value),
          ),
        ),
        const SizedBox(height: 15),
      ],
      _card(
        _LiveDailyChart(
          days: days,
          selected: _selectedDay.clamp(0, days.length - 1),
          onSelect: (value) => setState(() => _selectedDay = value),
        ),
      ),
      const SizedBox(height: 15),
      _card(_LiveDayDetails(day: selectedDay)),
      if (selectedDay.complete && baselineSamples.length >= 2) ...[
        const SizedBox(height: 15),
        _card(_SameWeekdayBaseline(day: selectedDay, samples: baselineSamples)),
      ],
      if (complete.length >= 2 &&
          maxDay!.totalMinutes - minDay!.totalMinutes >= 30 &&
          _insightPrefs?.showWeekRange == true) ...[
        const SizedBox(height: 22),
        const _Section('可核查的发现', '仅基于完整日期'),
        const SizedBox(height: 12),
        _insight(
          Icons.insights_rounded,
          lime,
          '${maxDay.date.month}月${maxDay.date.day}日使用最多',
          '${formatMinutes(maxDay.totalMinutes)}，比${minDay.date.month}月${minDay.date.day}日多 ${formatMinutes(maxDay.totalMinutes - minDay.totalMinutes)}。样本 ${complete.length} 天；点上方柱形图核对。',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              final value = await _bridge.suppressWeekRange();
              if (mounted) setState(() => _insightPrefs = value);
            },
            child: const Text('少提示这类 · 30 天'),
          ),
        ),
      ],
      if (_snapshot!.monthDays.isNotEmpty) ...[
        const SizedBox(height: 22),
        const _Section('近 30 天', '屏幕使用强度'),
        const SizedBox(height: 12),
        _card(
          _MonthHeatmap(
            days: _snapshot!.monthDays,
            selected: _selectedMonthDay,
            onSelect: (value) => setState(() => _selectedMonthDay = value),
          ),
        ),
      ],
    ]);
  }

  Widget _goalsPage() => _page([
    const _Eyebrow('目标与提醒'),
    const SizedBox(height: 6),
    const _Heading('由你定义，更好的节奏。'),
    const SizedBox(height: 6),
    const _Hint('达到上限后提醒一次，送达时间可能受系统影响。'),
    const SizedBox(height: 22),
    _goalSummary(onTap: _showGoalEditor),
    const SizedBox(height: 15),
    if (_goal != null) ...[
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle('目标控制', Icons.tune_rounded),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用目标', style: TextStyle(color: ink)),
              value: _goal!.enabled,
              onChanged: (value) async {
                await _bridge.setGoalEnabled(value);
                await _refresh();
              },
            ),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _showGoalEditor,
                  child: const Text('编辑目标'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () async {
                    if (_goal?.pausedDate == _dateKey(DateTime.now())) {
                      await _bridge.setGoalEnabled(true);
                    } else {
                      await _bridge.pauseGoalToday();
                    }
                    await _refresh();
                  },
                  child: Text(
                    _goal?.pausedDate == _dateKey(DateTime.now())
                        ? '立即恢复'
                        : '暂停至明天',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 15),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle('通知状态', Icons.notifications_outlined),
            const SizedBox(height: 10),
            Text(
              _status?.notificationsGranted == true
                  ? '系统通知已允许；每个目标每天最多提醒一次。'
                  : '系统通知未开启。目标已保存，但暂不能发送系统提醒。',
              style: const TextStyle(color: sub, fontSize: 12, height: 1.5),
            ),
            if (_status?.notificationsGranted != true) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  await _bridge.requestNotificationPermission();
                  await _refresh();
                },
                child: const Text('开启通知'),
              ),
            ],
          ],
        ),
      ),
    ],
  ]);

  Widget _goalSummary({required VoidCallback onTap}) {
    final goal = _goal;
    if (goal == null) {
      return _card(
        InkWell(
          onTap: onTap,
          child: const Row(
            children: [
              Icon(Icons.add_circle_outline, color: lime),
              SizedBox(width: 10),
              Expanded(
                child: Text('为想减少使用的应用设一个每日上限', style: TextStyle(color: ink)),
              ),
              Icon(Icons.chevron_right, color: sub),
            ],
          ),
        ),
      );
    }
    final today = _snapshot?.today;
    final paused = goal.pausedDate == _dateKey(DateTime.now());
    final selectedNames = goal.packageIds
        .map((id) {
          for (final app in today?.apps ?? <_LiveAppUsage>[]) {
            if (app.id == id) return app.label;
          }
          return id.split('.').last;
        })
        .join(' + ');
    return _card(
      InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.track_changes_rounded, color: lime),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    goal.name,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: sub),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              selectedNames,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: sub, fontSize: 11),
            ),
            const SizedBox(height: 17),
            Text(
              _goalUsedMinutes == null
                  ? '等待使用数据'
                  : '${formatMinutes(_goalUsedMinutes!)} / ${formatMinutes(goal.limitMinutes)}',
              style: const TextStyle(
                color: ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _goalUsedMinutes == null
                  ? 0
                  : (_goalUsedMinutes! / goal.limitMinutes).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: line,
              color: lime,
            ),
            const SizedBox(height: 9),
            Text(
              !goal.enabled
                  ? '目标已关闭'
                  : paused
                  ? '今天已暂停，明天自动恢复'
                  : _status?.notificationsGranted != true
                  ? '通知未开启，暂不能提醒'
                  : '提醒已开启 · ${goal.tone}语气',
              style: const TextStyle(color: sub, fontSize: 11),
            ),
            if (goal.lastCheckedAt != null) ...[
              const SizedBox(height: 5),
              Text(
                '后台上次检查 ${_clock(goal.lastCheckedAt)}',
                style: const TextStyle(color: sub, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_LiveAppUsage> _availableApps() {
    final byId = <String, _LiveAppUsage>{};
    for (final day in _snapshot?.days.reversed ?? <_LiveDay>[]) {
      for (final app in day.apps) {
        byId.putIfAbsent(app.id, () => app);
      }
    }
    for (final id in _goal?.packageIds ?? <String>[]) {
      byId.putIfAbsent(
        id,
        () => _LiveAppUsage(
          id: id,
          label: id.split('.').last,
          minutes: 0,
          category: '其他',
        ),
      );
    }
    return byId.values.toList()..sort((a, b) => b.minutes.compareTo(a.minutes));
  }

  void _showGoalEditor() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: panel,
      builder: (sheetContext) => _LiveGoalEditor(
        existing: _goal,
        apps: _availableApps(),
        onSave: (value) async {
          await _bridge.saveGoal(value);
          if (_status?.notificationsGranted != true) {
            await _bridge.requestNotificationPermission();
          }
          await _refresh();
        },
      ),
    );
  }

  void _showAppDetails(_LiveAppUsage app) {
    final days = _snapshot?.days ?? <_LiveDay>[];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panel,
      isScrollControlled: true,
      builder: (_) => _AppDetailSheet(app: app, days: days),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panel,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Heading('设置与数据'),
                const SizedBox(height: 13),
                const Text(
                  '设备使用数据只在本机展示。目标设置保存在本机，不上传到服务器。',
                  style: TextStyle(color: sub, height: 1.5),
                ),
                const SizedBox(height: 14),
                ListTile(
                  title: const Text('使用权限'),
                  subtitle: Text(_status?.usageGranted == true ? '已开启' : '未开启'),
                  onTap: _openUsageSettings,
                ),
                ListTile(
                  title: const Text('通知权限'),
                  subtitle: Text(
                    _status?.notificationsGranted == true ? '已开启' : '未开启',
                  ),
                  onTap: () => _bridge.openNotificationSettings(),
                ),
                ListTile(
                  title: const Text('查看演示数据'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _refreshVersion++;
                    setState(() => _demo = true);
                  },
                ),
                SwitchListTile(
                  title: const Text('通用事实洞察'),
                  subtitle: const Text('仅在应用内显示，不发送通知'),
                  value: _insightPrefs?.enabled ?? true,
                  onChanged: (enabled) async {
                    final value = await _bridge.setInsightsEnabled(enabled);
                    if (mounted) setState(() => _insightPrefs = value);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
                if (_insightPrefs?.suppressedUntil != null)
                  ListTile(
                    title: const Text('恢复已减少的洞察'),
                    onTap: () async {
                      final value = await _bridge.restoreInsights();
                      if (mounted) setState(() => _insightPrefs = value);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  ),
                ListTile(
                  title: const Text(
                    '删除本地目标与偏好',
                    style: TextStyle(color: Color(0xFFF6B765)),
                  ),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: sheetContext,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('删除本地数据？'),
                        content: const Text(
                          '将删除 Chronos 保存的目标与提醒记录。系统使用时间由设备管理，不会被删除。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _bridge.deleteLocalData();
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      await _refresh();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveHourlyChart extends StatelessWidget {
  const _LiveHourlyChart({
    required this.hours,
    required this.selectedHour,
    required this.onSelect,
  });
  final List<int> hours;
  final int selectedHour;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    var peak = 0;
    var peakMinutes = -1;
    for (var index = 0; index <= 21; index++) {
      final total = hours[index] + hours[index + 1] + hours[index + 2];
      if (total > peakMinutes) {
        peak = index;
        peakMinutes = total;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardTitle('屏幕使用轨迹', Icons.waves_rounded),
        const SizedBox(height: 8),
        Text(
          '${hourLabel(peak)}–${hourLabel(peak + 3)} 最集中 · ${formatMinutes(peakMinutes)}',
          style: const TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const _Hint('一柱代表一小时 · 点按查看准确时长'),
        const SizedBox(height: 18),
        SizedBox(
          height: 78,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(
              24,
              (hour) => Expanded(
                child: Semantics(
                  button: true,
                  label: '${hourLabel(hour)}，${formatMinutes(hours[hour])}',
                  child: InkWell(
                    onTap: () => onSelect(hour),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Container(
                        height: math.max(4, hours[hour] / 60 * 72),
                        decoration: BoxDecoration(
                          color: hour == selectedHour
                              ? lime
                              : _usageColor(hours[hour]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Hint('00'),
            _Hint('06'),
            _Hint('12'),
            _Hint('18'),
            _Hint('24'),
          ],
        ),
        const Divider(color: line, height: 25),
        Text(
          '${hourLabel(selectedHour)}–${hourLabel(selectedHour + 1)} · ${formatMinutes(hours[selectedHour])}',
          style: const TextStyle(color: lime, fontSize: 12),
        ),
      ],
    );
  }
}

class _LiveAppList extends StatelessWidget {
  const _LiveAppList({
    required this.apps,
    required this.totalMinutes,
    this.onAppTap,
  });
  final List<_LiveAppUsage> apps;
  final int totalMinutes;
  final ValueChanged<_LiveAppUsage>? onAppTap;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const Text('尚无应用明细', style: TextStyle(color: sub));
    const colors = [
      Color(0xFFF6B765),
      Color(0xFF78B7F7),
      Color(0xFFAA94F3),
      Color(0xFF8DD5CB),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Hint('已记录应用时长 · 以下仅展示前 10 项'),
        const SizedBox(height: 15),
        ...apps.take(10).toList().asMap().entries.map((entry) {
          final app = entry.value;
          final color = colors[entry.key % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 17),
            child: InkWell(
              onTap: onAppTap == null ? null : () => onAppTap!(app),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: ink, fontSize: 12),
                        ),
                      ),
                      Text(
                        formatMinutes(app.minutes),
                        style: const TextStyle(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: totalMinutes == 0
                        ? 0
                        : (app.minutes / totalMinutes).clamp(0.0, 1.0),
                    color: color,
                    backgroundColor: line,
                    minHeight: 7,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _AppDetailSheet extends StatelessWidget {
  const _AppDetailSheet({required this.app, required this.days});
  final _LiveAppUsage app;
  final List<_LiveDay> days;

  @override
  Widget build(BuildContext context) {
    final values = days.map((day) {
      if (!day.available) return null;
      for (final item in day.apps) {
        if (item.id == app.id) return item.minutes;
      }
      return 0;
    }).toList();
    final known = values.whereType<int>().toList();
    final maximum = known.fold<int>(60, math.max);
    final sum = known.fold<int>(0, (a, b) => a + b);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Heading(app.label),
              const SizedBox(height: 6),
              Text(
                '${app.category} · 最近七天',
                style: const TextStyle(color: sub),
              ),
              const SizedBox(height: 20),
              Text(
                '已知日期合计 ${formatMinutes(sum)}',
                style: const TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const _Hint('缺失日期不计入合计；今天仍在进行中'),
              const SizedBox(height: 20),
              SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(days.length, (index) {
                    final value = values[index];
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            value == null ? '—' : '${value}m',
                            style: const TextStyle(color: sub, fontSize: 10),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 25,
                            height: value == null
                                ? 3
                                : math.max(4, value / maximum * 100),
                            decoration: BoxDecoration(
                              color: value == null ? line : lime,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _weekday(days[index].date),
                            style: const TextStyle(color: sub, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 18),
              ...List.generate(days.length, (index) {
                final day = days[index];
                final value = values[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${day.date.month}月${day.date.day}日',
                          style: const TextStyle(color: sub, fontSize: 12),
                        ),
                      ),
                      Text(
                        value == null ? '无数据' : formatMinutes(value),
                        style: const TextStyle(color: ink, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SevenDayHourly extends StatelessWidget {
  const _SevenDayHourly({
    required this.days,
    required this.selected,
    required this.onSelect,
  });
  final List<_LiveDay> days;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _CardTitle('七天时段条', Icons.view_week_outlined),
      const SizedBox(height: 6),
      const _Hint('一格一小时 · 颜色越亮，使用越久 · 点按选择日期'),
      const SizedBox(height: 15),
      ...List.generate(days.length, (index) {
        final day = days[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            button: true,
            selected: selected == index,
            label:
                '${day.date.month}月${day.date.day}日，${day.available ? formatMinutes(day.totalMinutes) : '无数据'}',
            child: InkWell(
              onTap: () => onSelect(index),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      _weekday(day.date),
                      style: TextStyle(
                        color: selected == index ? lime : sub,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: List.generate(24, (hour) {
                        final minutes = day.hourly?.elementAtOrNull(hour);
                        return Expanded(
                          child: Container(
                            height: 15,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: minutes == null
                                  ? line
                                  : _usageColor(minutes),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 7),
                  SizedBox(
                    width: 53,
                    child: Text(
                      day.available ? formatMinutes(day.totalMinutes) : '无数据',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: sub, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Hint('00'),
          _Hint('06'),
          _Hint('12'),
          _Hint('18'),
          _Hint('24'),
        ],
      ),
    ],
  );
}

class _LiveDailyChart extends StatelessWidget {
  const _LiveDailyChart({
    required this.days,
    required this.selected,
    required this.onSelect,
  });
  final List<_LiveDay> days;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = days
        .where((day) => day.available)
        .map((day) => day.totalMinutes)
        .fold<int>(60, math.max);
    final day = days[selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardTitle('每日累计', Icons.bar_chart_rounded),
        const SizedBox(height: 7),
        const _Hint('点按日期查看 · 今天仍在进行中'),
        const SizedBox(height: 16),
        Text(
          '${day.date.month}月${day.date.day}日 · ${day.available ? formatMinutes(day.totalMinutes) : '无数据'}${day.available && !day.complete ? '（进行中）' : ''}',
          style: const TextStyle(
            color: ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 157,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(days.length, (index) {
              final item = days[index];
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected == index,
                  label:
                      '${item.date.month}月${item.date.day}日，${item.available ? formatMinutes(item.totalMinutes) : '无数据'}',
                  child: InkWell(
                    onTap: () => onSelect(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${item.date.day}',
                          style: const TextStyle(color: sub, fontSize: 10),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: 25,
                          height: item.available
                              ? math.max(
                                  4,
                                  item.totalMinutes / maxMinutes * 104,
                                )
                              : 3,
                          decoration: BoxDecoration(
                            color: !item.available
                                ? line
                                : selected == index
                                ? lime
                                : const Color(0xFF6F91BB),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _weekday(item.date),
                          style: TextStyle(
                            color: selected == index ? lime : sub,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _LiveDayDetails extends StatelessWidget {
  const _LiveDayDetails({required this.day});
  final _LiveDay day;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _CardTitle(
        '${day.date.month}月${day.date.day}日的应用去向',
        Icons.apps_outlined,
      ),
      const SizedBox(height: 13),
      if (!day.available)
        Text(
          day.reason == 'unreliable'
              ? '系统统计与屏幕交互时长不一致，已隐藏这一天的数值。'
              : '这一天没有可核对的记录。',
          style: const TextStyle(color: sub, height: 1.5),
        )
      else
        _LiveAppList(
          apps: day.apps.take(5).toList(),
          totalMinutes: day.totalMinutes,
        ),
    ],
  );
}

class _MonthHeatmap extends StatelessWidget {
  const _MonthHeatmap({
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final List<_LiveDay> days;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = days
        .where((day) => day.available)
        .map((day) => day.totalMinutes)
        .fold<int>(60, math.max);
    final day = days[selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardTitle('月历热度', Icons.calendar_month_outlined),
        const SizedBox(height: 7),
        const _Hint('颜色越亮，应用前台使用越久 · 灰色为无数据'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            childAspectRatio: 1.05,
          ),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final item = days[index];
            final intensity = item.available
                ? (item.totalMinutes / maxMinutes).clamp(0.0, 1.0)
                : 0.0;
            return Semantics(
              button: true,
              selected: index == selected,
              label:
                  '${item.date.month}月${item.date.day}日，${item.available ? formatMinutes(item.totalMinutes) : '无数据'}',
              child: InkWell(
                onTap: () => onSelect(index),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: item.available
                        ? Color.lerp(panel2, lime, 0.18 + intensity * 0.82)
                        : line,
                    borderRadius: BorderRadius.circular(8),
                    border: index == selected
                        ? Border.all(color: ink, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${item.date.day}',
                      style: TextStyle(
                        color: item.available && intensity > 0.55 ? bg : ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 13),
        Text(
          '${day.date.month}月${day.date.day}日 · ${day.available ? formatMinutes(day.totalMinutes) : '无数据'}${day.available && !day.complete ? '（进行中）' : ''}',
          style: const TextStyle(color: ink, fontSize: 12),
        ),
      ],
    );
  }
}

class _SameWeekdayBaseline extends StatelessWidget {
  const _SameWeekdayBaseline({required this.day, required this.samples});
  final _LiveDay day;
  final List<_LiveDay> samples;

  @override
  Widget build(BuildContext context) {
    final average =
        (samples.fold<int>(0, (sum, item) => sum + item.totalMinutes) /
                samples.length)
            .round();
    final difference = day.totalMinutes - average;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardTitle('同星期基线', Icons.compare_arrows_rounded),
        const SizedBox(height: 8),
        Text(
          difference == 0
              ? '与过去同星期的平均时长相同'
              : '比过去同星期平均${difference > 0 ? '多' : '少'} ${formatMinutes(difference.abs())}',
          style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '过去 ${samples.length} 个完整${_weekday(day.date)}的平均：${formatMinutes(average)}。仅比较完整日期。',
          style: const TextStyle(color: sub, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}

class _LiveGoalEditor extends StatefulWidget {
  const _LiveGoalEditor({
    required this.existing,
    required this.apps,
    required this.onSave,
  });
  final _LiveGoal? existing;
  final List<_LiveAppUsage> apps;
  final Future<void> Function(_LiveGoal) onSave;

  @override
  State<_LiveGoalEditor> createState() => _LiveGoalEditorState();
}

class _LiveGoalEditorState extends State<_LiveGoalEditor> {
  late final TextEditingController _name;
  late Set<String> _ids;
  late int _limit;
  late String _tone;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '少一点无意识刷屏');
    _ids = widget.existing?.packageIds.toSet() ?? <String>{};
    _limit = widget.existing?.limitMinutes ?? 120;
    _tone = widget.existing?.tone ?? '直接';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Heading('设置每日目标'),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              maxLength: 32,
              decoration: const InputDecoration(
                labelText: '目标名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '选择合计计时的应用',
              style: TextStyle(color: ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (widget.apps.isEmpty)
              const Text('最近七天还没有可选择的应用记录。', style: TextStyle(color: sub)),
            SizedBox(
              height: math.min(230, widget.apps.length * 51.0),
              child: ListView.builder(
                itemCount: widget.apps.length,
                itemBuilder: (context, index) {
                  final app = widget.apps[index];
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      app.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(app.category),
                    value: _ids.contains(app.id),
                    onChanged: (selected) => setState(() {
                      if (selected == true) {
                        _ids.add(app.id);
                      } else {
                        _ids.remove(app.id);
                      }
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '每日合计上限 · ${formatMinutes(_limit)}',
              style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
            ),
            Slider(
              value: _limit.toDouble(),
              min: 15,
              max: 720,
              divisions: 47,
              onChanged: (value) => setState(
                () => _limit = ((value / 15).round() * 15).clamp(15, 720),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '提醒语气',
              style: TextStyle(color: ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['温和', '直接', '严格']
                  .map(
                    (tone) => ChoiceChip(
                      label: Text(tone),
                      selected: _tone == tone,
                      onSelected: (_) => setState(() => _tone = tone),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text(
              _previewCopy(_tone, _name.text, _limit),
              style: const TextStyle(color: sub, height: 1.45),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFF6B765)),
                ),
              ),
            const SizedBox(height: 19),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _ids.isEmpty || _saving
                    ? null
                    : () async {
                        setState(() {
                          _saving = true;
                          _error = null;
                        });
                        try {
                          await widget.onSave(
                            _LiveGoal(
                              name: _name.text.trim().isEmpty
                                  ? '我的目标'
                                  : _name.text.trim(),
                              packageIds: _ids.toList(),
                              limitMinutes: _limit,
                              tone: _tone,
                              enabled: true,
                              pausedDate: '',
                              lastCheckedAt: null,
                            ),
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (mounted) setState(() => _error = '保存失败，请重试');
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: Text(_saving ? '保存中…' : '保存目标'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _previewCopy(String tone, String name, int limit) {
  final label = name.trim().isEmpty ? '我的目标' : name.trim();
  final duration = formatMinutes(limit);
  return switch (tone) {
    '温和' => '你设置的$label 今天达到 $duration 了，休息一下吗？',
    '严格' => '你已达到自己设置的 $duration 上限。现在暂停刷屏，回到原定安排。',
    _ => '$label 已达到今天的 $duration 上限。',
  };
}

String _weekday(DateTime date) =>
    const ['一', '二', '三', '四', '五', '六', '日'][date.weekday - 1];
String _clock(DateTime? date) => date == null
    ? '未知'
    : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
