part of '../main.dart';

class ChronosHome extends StatefulWidget {
  const ChronosHome({super.key});

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
              const _Header(),
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
      const _Eyebrow('星期四  /  10月29日'),
      const SizedBox(height: 6),
      _Heading('今天少用 ${formatMinutes(change)}'),
      const SizedBox(height: 5),
      const _Hint('与上周同日相比 · 以下为演示数据'),
      const SizedBox(height: 20),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _CardTitle('今日屏幕使用', Icons.phone_iphone_rounded),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => tab = 1),
                  style: TextButton.styleFrom(foregroundColor: sub),
                  child: const Text('看趋势  →', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
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
                          style: const TextStyle(
                            color: ink,
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      const _Hint('今天的累计使用时长'),
                      const SizedBox(height: 15),
                      _Badge('↓ 比上周少 ${formatMinutes(change)}'),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  label: '今日使用类别占比，社交与短视频最多',
                  child: CustomPaint(
                    size: const Size(94, 94),
                    painter: _RingPainter(),
                  ),
                ),
              ],
            ),
            const Divider(color: line, height: 32),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: topCategory.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '最多：${topCategory.label}',
                    style: const TextStyle(color: sub, fontSize: 12),
                  ),
                ),
                Text(
                  formatMinutes(topCategory.minutes),
                  style: const TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        padding: const EdgeInsets.all(19),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF202D3B), panel, panel],
        ),
      ),
      const SizedBox(height: 14),
      _card(
        _HourlyChart(
          selectedHour: selectedHour,
          onSelect: (hour) => setState(() => selectedHour = hour),
        ),
      ),
      const SizedBox(height: 24),
      const _Section('时间去了哪里', '对比前三周同日平均'),
      const SizedBox(height: 12),
      _card(const _CategoryBreakdown()),
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
      const _Eyebrow('最近七天的屏幕节奏'),
      const SizedBox(height: 6),
      _Heading(
        '周${DemoData.weekdays[maxDay]}最多，周${DemoData.weekdays[minDay]}最少',
      ),
      const SizedBox(height: 6),
      _Hint('相差 ${formatMinutes(maxMinutes - minMinutes)} · 点按某天查看'),
      const SizedBox(height: 20),
      _card(
        _WeekRhythm(
          selectedDay: selectedDay,
          onSelect: (day) => setState(() => selectedDay = day),
        ),
      ),
      const SizedBox(height: 15),
      _card(
        _WeeklyBars(
          selectedDay: selectedDay,
          onSelect: (day) => setState(() => selectedDay = day),
        ),
      ),
      const SizedBox(height: 22),
      const _Section('最近七天的发现', '基于演示数据'),
      const SizedBox(height: 12),
      _insight(
        Icons.calendar_view_week_rounded,
        lime,
        '周${DemoData.weekdays[maxDay]}使用最多',
        '使用 ${formatMinutes(maxMinutes)}，比周${DemoData.weekdays[minDay]}多 ${formatMinutes(maxMinutes - minMinutes)}。点按上方日期，查看每一天的高峰时段。',
      ),
    ]);
  }

  Widget _goals() => _page([
    const _Eyebrow('目标与提醒'),
    const SizedBox(height: 6),
    const _Heading('由你定义，更好的节奏。'),
    const SizedBox(height: 6),
    const _Hint('数字是参考，决定权始终在你。'),
    const SizedBox(height: 22),
    _goalCard(null),
    const SizedBox(height: 17),
    _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('每天的时长上限', Icons.timer_outlined),
          const SizedBox(height: 18),
          Center(
            child: Text(
              formatMinutes(goalMinutes),
              key: const Key('goal-limit'),
              style: const TextStyle(
                color: lime,
                fontSize: 28,
                fontWeight: FontWeight.w800,
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
      Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: lime,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '超时提醒',
                  style: TextStyle(
                    color: ink,
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
            activeThumbColor: bg,
            activeTrackColor: lime,
          ),
        ],
      ),
    ),
    const SizedBox(height: 22),
    const _Section('提醒语气', '用你喜欢的方式提醒'),
    const SizedBox(height: 12),
    _card(
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
                selectedColor: lime,
                backgroundColor: panel2,
                side: BorderSide(color: active ? lime : line),
                labelStyle: TextStyle(
                  color: active ? bg : sub,
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
              color: panel2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(switch (tone) {
              '温和' => '今天已经达到你设定的时长啦。要不要休息一下？',
              '严格' => '你已超过自己设定的上限。现在放下手机，回到计划。',
              _ => '抖音和小红书已达到今天的使用上限。',
            }, style: const TextStyle(color: ink, fontSize: 12)),
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
      InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.track_changes_rounded, color: lime),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '少一点无意识刷屏',
                    style: TextStyle(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: sub,
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
                const Text(
                  '1 小时 38 分钟',
                  style: TextStyle(
                    color: ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '/ ${formatMinutes(goalMinutes)}',
                  style: const TextStyle(color: sub, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: (used / goalMinutes).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: line,
                valueColor: AlwaysStoppedAnimation<Color>(
                  used >= goalMinutes ? const Color(0xFFF6B765) : lime,
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
              style: const TextStyle(color: sub, fontSize: 11),
            ),
          ],
        ),
      ),
      color: const Color(0xFF1A2430),
    );
  }
}
