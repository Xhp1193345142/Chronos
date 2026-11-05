part of '../main.dart';

class _LiveExperience extends StatefulWidget {
  const _LiveExperience({required this.timer});

  final ManualTimerController timer;

  @override
  State<_LiveExperience> createState() => _LiveExperienceState();
}

class _LiveExperienceState extends State<_LiveExperience>
    with WidgetsBindingObserver {
  final _bridge = _NativeBridge();
  _NativeStatus? _status;
  _LiveSnapshot? _snapshot;
  List<_LiveGoal> _goals = [];
  _LiveGoal? get _goal => _goals.isEmpty ? null : _goals.first;
  _InsightPreferences? _insightPrefs;
  Map<String, int?> _goalUsedMinutes = {};
  String? _error;
  bool _loading = true;
  bool _demo = false;
  bool _manualOnly = false;
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
    _loadMode();
  }

  Future<void> _loadMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _manualOnly = prefs.getBool('chronos_manual_only') ?? false;
    } catch (_) {
      _manualOnly = false;
    }
    if (!mounted) return;
    if (_manualOnly) {
      setState(() => _loading = false);
    } else {
      await _refresh();
    }
  }

  Future<void> _setManualOnly(bool value) async {
    try {
      final saved = await (await SharedPreferences.getInstance()).setBool(
        'chronos_manual_only',
        value,
      );
      if (!saved) throw StateError('Mode preference write failed');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('切换未保存，请检查设备空间后重试。')));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _manualOnly = value);
    if (!value) _refresh();
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
    if (!mounted || _demo || _manualOnly) return;
    final version = ++_refreshVersion;
    if (_snapshot == null) setState(() => _loading = true);
    try {
      final status = await _bridge.status();
      final goals = await _bridge.goals();
      final insightPrefs = await _bridge.insightPreferences();
      final snapshot = status.usageGranted ? await _bridge.snapshot() : null;
      final used = <String, int?>{};
      if (status.usageGranted) {
        for (final goal in goals) {
          if (goal.id != null) {
            used[goal.id!] = await _bridge.selectedGoalMinutes(goal.id!);
          }
        }
      }
      if (!mounted || _demo || version != _refreshVersion) return;
      setState(() {
        _status = status;
        if (status.openGoal) _tab = 2;
        if (status.usageGranted) _hadUsageAccess = true;
        _goals = goals;
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
    if (_manualOnly) {
      return _ManualExperience(
        timer: widget.timer,
        onConnect: () => _setManualOnly(false),
      );
    }
    if (_demo) return ChronosHome(timer: widget.timer, onExitDemo: _exitDemo);
    if (_loading) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 610),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const _Heading('今天的手账'),
                  const SizedBox(height: 18),
                  _TimerHero(timer: widget.timer),
                  const SizedBox(height: 30),
                  Center(
                    child: CircularProgressIndicator(
                      color: chronosColors(context).accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(child: _Hint('正在读取设备使用时间')),
                ],
              ),
            ),
          ),
        ),
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
          constraints: const BoxConstraints(maxWidth: 610),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _Eyebrow('本机手动计时'),
              const SizedBox(height: 7),
              const _Heading('今天的手账'),
              const SizedBox(height: 18),
              _TimerHero(timer: widget.timer),
              const SizedBox(height: 24),
              _ManualToday(timer: widget.timer),
              const SizedBox(height: 30),
              OutlinedButton(
                onPressed: () => _setManualOnly(true),
                child: const Text('只用时间手账'),
              ),
              const SizedBox(height: 24),
              const _Section('屏幕使用时间', '连接设备后显示'),
              const SizedBox(height: 12),
              _card(
                context,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.access_time_filled_rounded,
                      color: chronosColors(context).accent,
                      size: 46,
                    ),
                    const SizedBox(height: 28),
                    _Heading(title),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      style: TextStyle(
                        color: chronosColors(context).textSecondary,
                        height: 1.5,
                      ),
                    ),
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
            ],
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
                padding: const EdgeInsets.fromLTRB(24, 20, 17, 9),
                child: Row(
                  children: [
                    Text(
                      'CHRONOS',
                      style: TextStyle(
                        color: chronosColors(context).textPrimary,
                        fontSize: 13,
                        letterSpacing: 2.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '设备数据',
                      style: TextStyle(
                        color: chronosColors(context).textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      tooltip: '设置',
                      onPressed: _showSettings,
                      icon: Icon(
                        Icons.settings_outlined,
                        color: chronosColors(context).textSecondary,
                      ),
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
            timer: widget.timer,
            onTimerOpen: () => _showManualEntryEditor(
              context,
              widget.timer,
              entry: widget.timer.active,
            ),
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
      final unreliable = today?.reason == 'unreliable';
      final now = DateTime.now();
      return _page([
        _Eyebrow('星期${_weekday(now)} · ${now.month}月${now.day}日'),
        const SizedBox(height: 8),
        const _Heading('今天的手账'),
        const SizedBox(height: 18),
        _TimerHero(timer: widget.timer),
        const SizedBox(height: 25),
        _ManualToday(timer: widget.timer),
        const SizedBox(height: 29),
        _Section('屏幕使用时间', unreliable ? '设备数据暂无法核对' : '尚无可展示的设备记录'),
        const SizedBox(height: 14),
        _card(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 21,
                color: chronosColors(context).textSecondary,
              ),
              const SizedBox(height: 15),
              Text(
                unreliable
                    ? '设备返回的应用时长与屏幕交互时长不一致，暂不展示今日总量。可稍后刷新，并对照系统使用时间报告。'
                    : '设备已授权。使用手机一段时间后再刷新；这里不会把缺失数据算成 0 分钟。',
                style: TextStyle(
                  color: chronosColors(context).textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('刷新设备数据'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
              ),
            ],
          ),
        ),
      ]);
    }
    final top = today.apps.isEmpty ? null : today.apps.first;
    return _page([
      _Eyebrow(
        '星期${_weekday(today.date)} · ${today.date.month}月${today.date.day}日',
      ),
      const SizedBox(height: 7),
      const _Heading('今天的手账'),
      const SizedBox(height: 4),
      const _Hint('手动记录与屏幕使用分别查看'),
      const SizedBox(height: 19),
      _TimerHero(timer: widget.timer),
      const SizedBox(height: 25),
      _ManualToday(timer: widget.timer),
      const SizedBox(height: 29),
      _Section('屏幕使用时间', '最近读取 ${_clock(snapshot.readAt)} · 不与手动记录相加'),
      const SizedBox(height: 12),
      _card(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '屏幕使用时间',
              style: TextStyle(
                color: chronosColors(context).textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 17),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMinutes(today.totalMinutes),
                key: const Key('live-today-total'),
                style: TextStyle(
                  color: chronosColors(context).textPrimary,
                  fontSize: 37,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _Hint('已记录应用的前台使用时长'),
            if (top != null) ...[
              Divider(color: chronosColors(context).border, height: 34),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '使用最多 · ${top.label}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: chronosColors(context).textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatMinutes(top.minutes),
                    style: TextStyle(
                      color: chronosColors(context).textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      ),
      const SizedBox(height: 27),
      const _Section('一天的节奏', '点按查看每小时'),
      const SizedBox(height: 12),
      if (today.hourly != null && today.hourly!.length == 24)
        _chartPanel(
          context,
          _LiveHourlyChart(
            hours: today.hourly!,
            selectedHour: _selectedHour,
            onSelect: (value) => setState(() => _selectedHour = value),
          ),
        )
      else
        _card(
          context,
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 19,
                color: chronosColors(context).textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '设备尚未提供可核对的小时分布，可继续查看应用去向。',
                  style: TextStyle(
                    color: chronosColors(context).textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          color: chronosColors(context).surfaceRaised,
        ),
      const SizedBox(height: 27),
      const _Section('时间去了哪里', '按应用时长排序'),
      const SizedBox(height: 12),
      _chartPanel(
        context,
        _LiveAppList(
          apps: today.apps,
          totalMinutes: today.totalMinutes,
          onAppTap: _showAppDetails,
        ),
      ),
      const SizedBox(height: 23),
      _Section(
        '你的目标',
        _goals.length > 1 ? '共 ${_goals.length} 个目标 · 在目标页管理' : '按自己设定的标准提醒',
      ),
      const SizedBox(height: 12),
      _goalSummary(onTap: () => setState(() => _tab = 2)),
    ]);
  }

  Widget _trendsPage() {
    final days = _snapshot!.days;
    if (days.isEmpty) {
      return _page([
        _ManualWeek(timer: widget.timer),
        const SizedBox(height: 27),
        const _Eyebrow('最近七天的屏幕节奏'),
        const SizedBox(height: 8),
        const _Heading('还没有可展示的趋势'),
        const SizedBox(height: 14),
        _card(
          context,
          Text(
            '使用记录载入后，这里会显示每日累计。',
            style: TextStyle(color: chronosColors(context).textSecondary),
          ),
        ),
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
      const _Eyebrow('最近七天'),
      const SizedBox(height: 7),
      const _Heading('趋势'),
      const SizedBox(height: 4),
      const _Hint('本机计时与设备使用分开统计'),
      const SizedBox(height: 23),
      _ManualWeek(timer: widget.timer),
      const SizedBox(height: 27),
      const _Section('屏幕使用趋势', '来自设备 · 仅比较完整日期'),
      const SizedBox(height: 17),
      if (days.any((day) => day.hourly?.length == 24)) ...[
        _chartPanel(
          context,
          _SevenDayHourly(
            days: days,
            selected: _selectedDay,
            onSelect: (value) => setState(() => _selectedDay = value),
          ),
        ),
        const SizedBox(height: 15),
      ],
      _chartPanel(
        context,
        _LiveDailyChart(
          days: days,
          selected: _selectedDay.clamp(0, days.length - 1),
          onSelect: (value) => setState(() => _selectedDay = value),
        ),
      ),
      if (maxDay != null && minDay != null && complete.length >= 2) ...[
        const SizedBox(height: 22),
        _chartPanel(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '完整日期的最大差异',
                style: TextStyle(
                  color: chronosColors(context).textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                formatMinutes(maxDay.totalMinutes - minDay.totalMinutes),
                style: TextStyle(
                  color: chronosColors(context).textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${maxDay.date.month}月${maxDay.date.day}日最多 · ${minDay.date.month}月${minDay.date.day}日最少 · 样本 ${complete.length} 天',
                style: TextStyle(
                  color: chronosColors(context).textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 15),
      _card(context, _LiveDayDetails(day: selectedDay)),
      if (selectedDay.complete && baselineSamples.length >= 2) ...[
        const SizedBox(height: 15),
        _card(
          context,
          _SameWeekdayBaseline(day: selectedDay, samples: baselineSamples),
        ),
      ],
      if (complete.length >= 2 &&
          maxDay!.totalMinutes - minDay!.totalMinutes >= 30 &&
          _insightPrefs?.showWeekRange == true) ...[
        const SizedBox(height: 22),
        const _Section('可核查的发现', '仅基于完整日期'),
        const SizedBox(height: 12),
        _insight(
          context,
          Icons.insights_rounded,
          chronosColors(context).accent,
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
      if (complete.length >= 3) ...[
        const SizedBox(height: 22),
        const _Section('周回顾', '仅统计可核对的完整日期'),
        const SizedBox(height: 12),
        _card(context, _WeeklyReview(days: complete)),
      ],
      if (_snapshot!.monthDays.isNotEmpty) ...[
        const SizedBox(height: 22),
        const _Section('近 30 天', '屏幕使用强度'),
        const SizedBox(height: 12),
        _chartPanel(
          context,
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
    const _Eyebrow('目标与提醒 · 设备数据'),
    const SizedBox(height: 7),
    const _Heading('目标'),
    const SizedBox(height: 4),
    const _Hint('提醒只针对你设置的上限。'),
    const SizedBox(height: 27),
    _Section('使用目标', _goals.isEmpty ? '由你决定提醒时机' : '共 ${_goals.length} 个目标'),
    const SizedBox(height: 12),
    if (_goals.isEmpty) _goalSummary(onTap: () => _showGoalEditor(null)),
    for (final goal in _goals) ...[
      _goalSummary(goal: goal, onTap: () => _showGoalEditor(goal)),
      const SizedBox(height: 10),
      _goalControls(goal),
      const SizedBox(height: 15),
    ],
    if (_goals.isNotEmpty) ...[
      OutlinedButton.icon(
        onPressed: () => _showGoalEditor(null),
        icon: const Icon(Icons.add),
        label: const Text('新增目标'),
      ),
      const SizedBox(height: 15),
      _card(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle('通知状态', Icons.notifications_outlined),
            const SizedBox(height: 10),
            Text(
              _status?.notificationsGranted == true
                  ? '系统通知已允许；每个目标每天最多提醒一次。'
                  : '系统通知未开启。目标已保存，但暂不能发送系统提醒。',
              style: TextStyle(
                color: chronosColors(context).textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
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

  Widget _goalControls(_LiveGoal goal) => _card(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '启用目标',
              style: TextStyle(color: chronosColors(context).textPrimary),
            ),
            value: goal.enabled,
            onChanged: (value) async {
              await _bridge.setGoalEnabled(goal.id!, value);
              await _refresh();
            },
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(
              onPressed: () => _showGoalEditor(goal),
              child: const Text('编辑'),
            ),
            TextButton(
              onPressed: () async {
                if (goal.pausedDate == _dateKey(DateTime.now())) {
                  await _bridge.setGoalEnabled(goal.id!, true);
                } else {
                  await _bridge.pauseGoalToday(goal.id!);
                }
                await _refresh();
              },
              child: Text(
                goal.pausedDate == _dateKey(DateTime.now()) ? '立即恢复' : '暂停至明天',
              ),
            ),
            TextButton(
              onPressed: () => _confirmDeleteGoal(goal),
              child: Text(
                '删除',
                style: TextStyle(color: chronosColors(context).danger),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _confirmDeleteGoal(_LiveGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除「${goal.name}」？'),
        content: const Text('这会删除目标及其提醒记录，不会删除系统使用时间。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
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
      await _bridge.deleteGoal(goal.id!);
      await _refresh();
    }
  }

  Widget _goalSummary({required VoidCallback onTap, _LiveGoal? goal}) {
    goal ??= _goal;
    if (goal == null) {
      return _card(
        context,
        InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                color: chronosColors(context).accent,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '为想减少使用的应用设一个每日上限',
                  style: TextStyle(color: chronosColors(context).textPrimary),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: chronosColors(context).textSecondary,
              ),
            ],
          ),
        ),
      );
    }
    final today = _snapshot?.today;
    final paused = goal.pausedDate == _dateKey(DateTime.now());
    final usedMinutes = _goalUsedMinutes[goal.id];
    final limit = goal.limitFor(DateTime.now());
    final selectedNames = goal.packageIds
        .map((id) {
          for (final app in today?.apps ?? <_LiveAppUsage>[]) {
            if (app.id == id) return app.label;
          }
          return id.split('.').last;
        })
        .join(' + ');
    return _card(
      context,
      InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.track_changes_rounded,
                  color: chronosColors(context).accent,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    goal.name,
                    style: TextStyle(
                      color: chronosColors(context).textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: chronosColors(context).textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              selectedNames,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: chronosColors(context).textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              usedMinutes == null
                  ? '等待使用数据'
                  : '${formatMinutes(usedMinutes)} / ${formatMinutes(limit)}',
              style: TextStyle(
                color: chronosColors(context).textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: usedMinutes == null
                  ? 0
                  : (usedMinutes / limit).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: chronosColors(context).border,
              color: chronosColors(context).accent,
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
              style: TextStyle(
                color: chronosColors(context).textSecondary,
                fontSize: 11,
              ),
            ),
            if (goal.lastCheckedAt != null) ...[
              const SizedBox(height: 5),
              Text(
                '后台上次检查 ${_clock(goal.lastCheckedAt)}',
                style: TextStyle(
                  color: chronosColors(context).textSecondary,
                  fontSize: 11,
                ),
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
    for (final goal in _goals) {
      for (final id in goal.packageIds) {
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
    }
    return byId.values.toList()..sort((a, b) => b.minutes.compareTo(a.minutes));
  }

  void _showGoalEditor(_LiveGoal? existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      backgroundColor: chronosColors(context).surface,
      builder: (sheetContext) => _LiveGoalEditor(
        existing: existing,
        apps: _availableApps(),
        onSave: (value) async {
          await _bridge.saveGoal(value);
          if (value.enabled && _status?.notificationsGranted != true) {
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
      backgroundColor: chronosColors(context).surface,
      isScrollControlled: true,
      builder: (_) => _AppDetailSheet(app: app, days: days),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: chronosColors(context).surface,
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
                Text(
                  '设备使用数据只在本机展示。手动记录、目标与偏好保存在本机，不上传到服务器。',
                  style: TextStyle(
                    color: chronosColors(context).textSecondary,
                    height: 1.5,
                  ),
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
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('外观主题'),
                  subtitle: Text(ChronosThemeScope.of(context).choice.label),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showChronosThemePicker(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('手账备份与隐私'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openJournalSettings(context, widget.timer);
                  },
                ),
                ListTile(
                  title: const Text('只用时间手账'),
                  subtitle: const Text('仅切换界面，已启用的设备目标保持原设置'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _setManualOnly(true);
                  },
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
                  title: Text(
                    '删除本地记录、目标与偏好',
                    style: TextStyle(color: chronosColors(context).danger),
                  ),
                  onTap: () async {
                    final resetAppearance = ChronosThemeScope.of(context)
                        .onReset;
                    final confirmed = await showDialog<bool>(
                      context: sheetContext,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('删除本地数据？'),
                        content: const Text(
                          '将删除手动计时记录、目标、提醒记录与洞察偏好，外观恢复为跟随系统。系统使用时间由设备管理，不会被删除。',
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
                      if (!await widget.timer.clear()) {
                        if (mounted) _message(widget.timer.error ?? '手动记录删除失败');
                        return;
                      }
                      await _bridge.deleteLocalData();
                      resetAppearance();
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
        Text(
          '${hourLabel(peak)}–${hourLabel(peak + 3)} 最集中 · ${formatMinutes(peakMinutes)}',
          style: TextStyle(
            color: chronosColors(context).textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        const _Hint('一柱代表一小时 · 点按查看准确时长'),
        const SizedBox(height: 24),
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
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        height: math.max(4, hours[hour] / 60 * 72),
                        decoration: BoxDecoration(
                          color: hour == selectedHour
                              ? chronosColors(context).accent
                              : _usageColor(context, hours[hour]),
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
        Divider(color: chronosColors(context).border, height: 25),
        Text(
          '${hourLabel(selectedHour)}–${hourLabel(selectedHour + 1)} · ${formatMinutes(hours[selectedHour])}',
          style: TextStyle(color: chronosColors(context).accent, fontSize: 12),
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
    if (apps.isEmpty) {
      return Text(
        '尚无应用明细',
        style: TextStyle(color: chronosColors(context).textSecondary),
      );
    }
    final colors = chronosColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Hint('已记录应用时长 · 以下仅展示前 10 项'),
        const SizedBox(height: 15),
        ...apps.take(10).toList().asMap().entries.map((entry) {
          final app = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: InkWell(
              onTap: onAppTap == null ? null : () => onAppTap!(app),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${entry.key + 1}'.padLeft(2, '0'),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 10,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: chronosColors(context).textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        formatMinutes(app.minutes),
                        style: TextStyle(
                          color: chronosColors(context).textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: totalMinutes == 0
                            ? 0
                            : (app.minutes / totalMinutes).clamp(0.0, 1.0),
                        color: colors.accent,
                        backgroundColor: colors.border.withValues(alpha: 0.65),
                        minHeight: 3,
                      ),
                    ),
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
                style: TextStyle(color: chronosColors(context).textSecondary),
              ),
              const SizedBox(height: 20),
              Text(
                '已知日期合计 ${formatMinutes(sum)}',
                style: TextStyle(
                  color: chronosColors(context).textPrimary,
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
                            style: TextStyle(
                              color: chronosColors(context).textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 25,
                            height: value == null
                                ? 3
                                : math.max(4, value / maximum * 100),
                            decoration: BoxDecoration(
                              color: value == null
                                  ? chronosColors(context).border
                                  : chronosColors(context).accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _weekday(days[index].date),
                            style: TextStyle(
                              color: chronosColors(context).textSecondary,
                              fontSize: 11,
                            ),
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
                          style: TextStyle(
                            color: chronosColors(context).textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        value == null ? '无数据' : formatMinutes(value),
                        style: TextStyle(
                          color: chronosColors(context).textPrimary,
                          fontSize: 12,
                        ),
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
                        color: selected == index
                            ? chronosColors(context).accent
                            : chronosColors(context).textSecondary,
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
                                  ? chronosColors(context).border
                                  : _usageColor(context, minutes),
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
                      day.available
                          ? _compactChartMinutes(day.totalMinutes)
                          : '无数据',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      style: TextStyle(
                        color: chronosColors(context).textSecondary,
                        fontSize: 10,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
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
        const _Hint('点按日期查看 · 无数据不计入日均 · 细线为已知日均'),
        const SizedBox(height: 16),
        Text(
          '${day.date.month}月${day.date.day}日 · ${day.available ? formatMinutes(day.totalMinutes) : '无数据'}${day.available && !day.complete ? '（进行中）' : ''}',
          style: TextStyle(
            color: chronosColors(context).textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 157,
          child: Stack(
            children: [
              if (days.where((item) => item.available).isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom:
                      22 +
                      days
                              .where((item) => item.available)
                              .map((item) => item.totalMinutes)
                              .reduce((a, b) => a + b) /
                          days.where((item) => item.available).length /
                          maxMinutes *
                          104,
                  child: Container(
                    height: 1,
                    color: chronosColors(context).textSecondary
                        .withValues(alpha: 0.58),
                  ),
                ),
              Row(
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
                              style: TextStyle(
                                color: chronosColors(context).textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 18,
                              height: item.available
                                  ? math.max(
                                      4,
                                      item.totalMinutes / maxMinutes * 104,
                                    )
                                  : 3,
                              decoration: BoxDecoration(
                                color: !item.available
                                    ? chronosColors(context).border
                                    : selected == index
                                    ? chronosColors(context).accent
                                    : chronosColors(context).accent
                                          .withValues(alpha: 0.26),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _weekday(item.date),
                              style: TextStyle(
                                color: selected == index
                                    ? chronosColors(context).accent
                                    : chronosColors(context).textSecondary,
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
            ],
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
          style: TextStyle(
            color: chronosColors(context).textSecondary,
            height: 1.5,
          ),
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
                        ? Color.lerp(
                            chronosColors(context).surfaceRaised,
                            chronosColors(context).accent,
                            0.18 + intensity * 0.82,
                          )
                        : chronosColors(context).border,
                    borderRadius: BorderRadius.circular(8),
                    border: index == selected
                        ? Border.all(
                            color: chronosColors(context).textPrimary,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${item.date.day}',
                      style: TextStyle(
                        color: item.available && intensity > 0.55
                            ? chronosColors(context).background
                            : chronosColors(context).textPrimary,
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
          style: TextStyle(
            color: chronosColors(context).textPrimary,
            fontSize: 12,
          ),
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
          style: TextStyle(
            color: chronosColors(context).textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '过去 ${samples.length} 个完整${_weekday(day.date)}的平均：${formatMinutes(average)}。仅比较完整日期。',
          style: TextStyle(
            color: chronosColors(context).textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _WeeklyReview extends StatelessWidget {
  const _WeeklyReview({required this.days});
  final List<_LiveDay> days;

  @override
  Widget build(BuildContext context) {
    final total = days.fold<int>(0, (sum, day) => sum + day.totalMinutes);
    final average = (total / days.length).round();
    final weekdays = days.where((day) => day.date.weekday <= 5).toList();
    final weekends = days.where((day) => day.date.weekday >= 6).toList();
    final weekdayAverage = weekdays.isEmpty
        ? null
        : (weekdays.fold<int>(0, (sum, day) => sum + day.totalMinutes) /
                  weekdays.length)
              .round();
    final weekendAverage = weekends.isEmpty
        ? null
        : (weekends.fold<int>(0, (sum, day) => sum + day.totalMinutes) /
                  weekends.length)
              .round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardTitle('本周已知时间', Icons.summarize_outlined),
        const SizedBox(height: 12),
        Text(
          formatMinutes(total),
          style: TextStyle(
            color: chronosColors(context).textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${days.length} 个完整日 · 日均 ${formatMinutes(average)}',
          style: TextStyle(
            color: chronosColors(context).textSecondary,
            fontSize: 12,
          ),
        ),
        if (weekdayAverage != null && weekendAverage != null) ...[
          Divider(color: chronosColors(context).border, height: 25),
          Text(
            '工作日均值 ${formatMinutes(weekdayAverage)} · 周末均值 ${formatMinutes(weekendAverage)}',
            style: TextStyle(
              color: chronosColors(context).textPrimary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '工作日 ${weekdays.length} 天，周末 ${weekends.length} 天；今天不计入。',
            style: TextStyle(
              color: chronosColors(context).textSecondary,
              fontSize: 11,
            ),
          ),
        ],
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
  int? _weekendLimit;
  late String _tone;
  late bool _enabled;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '少一点无意识刷屏');
    _ids = widget.existing?.packageIds.toSet() ?? <String>{};
    _limit = widget.existing?.limitMinutes ?? 120;
    _weekendLimit = widget.existing?.weekendLimitMinutes;
    _tone = widget.existing?.tone ?? '直接';
    _enabled = widget.existing?.enabled ?? true;
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
            Text(
              '选择合计计时的应用',
              style: TextStyle(
                color: chronosColors(context).textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (widget.apps.isEmpty)
              Text(
                '最近七天还没有可选择的应用记录。',
                style: TextStyle(color: chronosColors(context).textSecondary),
              ),
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
              '${_weekendLimit == null ? '每日' : '工作日'}合计上限 · ${formatMinutes(_limit)}',
              style: TextStyle(
                color: chronosColors(context).textPrimary,
                fontWeight: FontWeight.w700,
              ),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('周末使用不同上限'),
              value: _weekendLimit != null,
              onChanged: (enabled) =>
                  setState(() => _weekendLimit = enabled ? _limit : null),
            ),
            if (_weekendLimit != null) ...[
              Text(
                '周末合计上限 · ${formatMinutes(_weekendLimit!)}',
                style: TextStyle(
                  color: chronosColors(context).textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Slider(
                value: _weekendLimit!.toDouble(),
                min: 15,
                max: 720,
                divisions: 47,
                onChanged: (value) => setState(
                  () => _weekendLimit = ((value / 15).round() * 15).clamp(
                    15,
                    720,
                  ),
                ),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用目标提醒'),
              subtitle: const Text('关闭后保留目标，不检查阈值'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 10),
            Text(
              '提醒语气',
              style: TextStyle(
                color: chronosColors(context).textPrimary,
                fontWeight: FontWeight.w700,
              ),
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
              _previewCopy(
                _tone,
                _name.text,
                DateTime.now().weekday >= 6 ? _weekendLimit ?? _limit : _limit,
              ),
              style: TextStyle(
                color: chronosColors(context).textSecondary,
                height: 1.45,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: chronosColors(context).danger),
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
                              id: widget.existing?.id,
                              name: _name.text.trim().isEmpty
                                  ? '我的目标'
                                  : _name.text.trim(),
                              packageIds: _ids.toList(),
                              limitMinutes: _limit,
                              weekendLimitMinutes: _weekendLimit,
                              tone: _tone,
                              enabled: _enabled,
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
    '严格' => '$label 已达到今天的 $duration 上限。现在暂停刷屏，回到原定安排。',
    _ => '$label 已达到今天的 $duration 上限。',
  };
}

String _weekday(DateTime date) =>
    const ['一', '二', '三', '四', '五', '六', '日'][date.weekday - 1];
String _compactChartMinutes(int minutes) => minutes < 60
    ? '${minutes}m'
    : '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';
String _clock(DateTime? date) => date == null
    ? '未知'
    : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
