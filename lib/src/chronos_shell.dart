part of '../main.dart';

class ChronosHome extends StatefulWidget {
  const ChronosHome({super.key, this.onExitDemo});

  final VoidCallback? onExitDemo;

  @override
  State<ChronosHome> createState() => _ChronosHomeState();
}

class _ChronosHomeState extends State<ChronosHome> {
  int tab = 0;
  int selectedDay = DemoData.todayIndex;
  int selectedHour = 19;
  int goalMinutes = 120;
  bool reminders = true;
  String tone = '直接';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 610),
          child: Column(
            children: [
              _Header(onExitDemo: widget.onExitDemo),
              Expanded(
                child: IndexedStack(
                  index: tab,
                  children: [_today(), _trends(), _goals()],
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
            tab: tab,
            onTap: (value) {
              HapticFeedback.selectionClick();
              setState(() => tab = value);
            },
          ),
        ),
      ),
    ),
  );

  Widget _today() {
    final change = DemoData.lastWeekSameDayMinutes - DemoData.todayMinutes;
    final topCategory = DemoData.categories.first;
    return _page([
      const _Eyebrow('星期四 · 10月29日'),
      const SizedBox(height: 7),
      const _Heading('今天'),
      const SizedBox(height: 4),
      const _Hint('应用与时段 · 以下为演示数据'),
      const SizedBox(height: 23),
      _card(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '屏幕使用时间',
                  style: TextStyle(
                    color: chronosColors(context).textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => tab = 1),
                  style: TextButton.styleFrom(
                    foregroundColor: chronosColors(context).textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('查看趋势  ›', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatMinutes(DemoData.todayMinutes),
                          key: const Key('today-duration'),
                          style: TextStyle(
                            color: chronosColors(context).textPrimary,
                            fontSize: 37,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.4,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Badge('今天少用 ${formatMinutes(change)}'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  label: '今日使用类别占比，${topCategory.label}最多',
                  child: CustomPaint(
                    size: const Size(88, 88),
                    painter: _RingPainter(chronosColors(context)),
                  ),
                ),
              ],
            ),
            Divider(color: chronosColors(context).border, height: 34),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: chronosColors(context).social,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '使用最多 · ${topCategory.label}',
                    style: TextStyle(
                      color: chronosColors(context).textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Text(
                  formatMinutes(topCategory.minutes),
                  style: TextStyle(
                    color: chronosColors(context).textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 17, 22, 20),
      ),
      const SizedBox(height: 27),
      const _Section('一天的节奏', '点按查看每小时'),
      const SizedBox(height: 12),
      _chartPanel(
        context,
        _HourlyChart(
          selectedHour: selectedHour,
          onSelect: (hour) => setState(() => selectedHour = hour),
        ),
      ),
      const SizedBox(height: 27),
      const _Section('时间去了哪里', '对比前三周同日平均'),
      const SizedBox(height: 12),
      _chartPanel(context, const _CategoryBreakdown()),
      const SizedBox(height: 23),
      const _Section('你的目标', '按你设定的标准提醒'),
      const SizedBox(height: 12),
      _goalCard(() => setState(() => tab = 2)),
    ]);
  }

  Widget _trends() {
    final maxMinutes = DemoData.week.reduce(math.max);
    final minMinutes = DemoData.week.reduce(math.min);
    final maxDay = DemoData.week.indexOf(maxMinutes);
    final minDay = DemoData.week.indexOf(minMinutes);
    return _page([
      const _Eyebrow('最近七天 · 演示数据'),
      const SizedBox(height: 7),
      const _Heading('趋势'),
      const SizedBox(height: 4),
      const _Hint('选择一天，查看它的使用节奏'),
      const SizedBox(height: 23),
      _card(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本周日均',
              style: TextStyle(
                color: chronosColors(context).textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              formatMinutes(DemoData.weekAverageMinutes),
              style: TextStyle(
                color: chronosColors(context).textPrimary,
                fontSize: 35,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Divider(color: chronosColors(context).border, height: 34),
            Text(
              '周${DemoData.weekdays[maxDay]}最多，周${DemoData.weekdays[minDay]}最少 · 相差 ${formatMinutes(maxMinutes - minMinutes)}',
              style: TextStyle(
                color: chronosColors(context).textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      ),
      const SizedBox(height: 27),
      const _Section('七天节奏', '每格 1 小时；颜色表示使用时长'),
      const SizedBox(height: 12),
      _chartPanel(
        context,
        _WeekRhythm(
          selectedDay: selectedDay,
          onSelect: (day) => setState(() => selectedDay = day),
        ),
      ),
      const SizedBox(height: 27),
      const _Section('每日累计', '点按查看当天'),
      const SizedBox(height: 12),
      _chartPanel(
        context,
        _WeeklyBars(
          selectedDay: selectedDay,
          onSelect: (day) => setState(() => selectedDay = day),
        ),
      ),
      const SizedBox(height: 22),
      const _Section('最近七天的发现', '基于演示数据'),
      const SizedBox(height: 12),
      _insight(
        context,
        Icons.calendar_view_week_rounded,
        chronosColors(context).accent,
        '周${DemoData.weekdays[maxDay]}使用最多',
        '使用 ${formatMinutes(maxMinutes)}，比周${DemoData.weekdays[minDay]}多 ${formatMinutes(maxMinutes - minMinutes)}。点按上方日期，查看每一天的高峰时段。',
      ),
    ]);
  }

  Widget _goals() => _page([
    const _Eyebrow('目标与提醒 · 演示数据'),
    const SizedBox(height: 7),
    const _Heading('目标'),
    const SizedBox(height: 4),
    const _Hint('提醒只针对你设置的上限。'),
    const SizedBox(height: 27),
    const _Section('使用目标', '抖音与小红书'),
    const SizedBox(height: 12),
    _goalCard(null),
    const SizedBox(height: 27),
    const _Section('每日上限', '选择你愿意接受的时长'),
    const SizedBox(height: 12),
    _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hint('抖音 + 小红书'),
          const SizedBox(height: 15),
          Center(
            child: Text(
              formatMinutes(goalMinutes),
              key: const Key('goal-limit'),
              style: TextStyle(
                color: chronosColors(context).accent,
                fontSize: 33,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Slider(
            value: goalMinutes.toDouble(),
            min: 30,
            max: 240,
            divisions: 14,
            label: formatMinutes(goalMinutes),
            onChanged: (value) => setState(() => goalMinutes = value.round()),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_Hint('30 分钟'), _Hint('4 小时')],
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    _card(
      context,
      Row(
        children: [
          Icon(
            Icons.notifications_active_outlined,
            color: chronosColors(context).accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '超时提醒',
                  style: TextStyle(
                    color: chronosColors(context).textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                _Hint('达到每日上限后提醒一次'),
              ],
            ),
          ),
          Switch(
            value: reminders,
            onChanged: (value) => setState(() => reminders = value),
            activeThumbColor: chronosColors(context).background,
            activeTrackColor: chronosColors(context).accent,
          ),
        ],
      ),
    ),
    const SizedBox(height: 22),
    const _Section('提醒语气', '用你喜欢的方式提醒'),
    const SizedBox(height: 12),
    _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['温和', '直接', '严格'].map((option) {
              final active = option == tone;
              return ChoiceChip(
                label: Text(option),
                selected: active,
                onSelected: (_) => setState(() => tone = option),
                selectedColor: chronosColors(context).accent,
                backgroundColor: chronosColors(context).surfaceRaised,
                side: BorderSide(
                  color: active
                      ? chronosColors(context).accent
                      : chronosColors(context).border,
                ),
                labelStyle: TextStyle(
                  color: active
                      ? chronosColors(context).background
                      : chronosColors(context).textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: chronosColors(context).surfaceRaised,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              switch (tone) {
                '温和' => '今天已经达到你设定的时长啦。要不要休息一下？',
                '严格' => '你已超过自己设定的上限。现在放下手机，回到计划。',
                _ => '抖音和小红书已达到今天的使用上限。',
              },
              style: TextStyle(
                color: chronosColors(context).textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    const Center(child: _Hint('演示版中的修改只在本次运行期间保留。')),
  ]);

  Widget _goalCard(VoidCallback? onTap) {
    const used = 98;
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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '少一点无意识刷屏',
                    style: TextStyle(
                      color: chronosColors(context).textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: chronosColors(context).textSecondary,
                    size: 14,
                  ),
              ],
            ),
            const SizedBox(height: 5),
            const Padding(
              padding: EdgeInsets.only(left: 32),
              child: _Hint('抖音 + 小红书 · 每天'),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '1 小时 38 分钟',
                  style: TextStyle(
                    color: chronosColors(context).textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '/ ${formatMinutes(goalMinutes)}',
                  style: TextStyle(
                    color: chronosColors(context).textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: (used / goalMinutes).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: chronosColors(context).border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  used >= goalMinutes
                      ? chronosColors(context).danger
                      : chronosColors(context).accent,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              !reminders
                  ? '提醒已暂停'
                  : used >= goalMinutes
                  ? '已达到今天的提醒阈值'
                  : '距离提醒还有 ${formatMinutes(goalMinutes - used)}',
              style: TextStyle(
                color: chronosColors(context).textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      color: chronosColors(context).surfaceRaised,
    );
  }
}
