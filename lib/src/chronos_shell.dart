part of '../main.dart';

class ChronosHome extends StatefulWidget {
  const ChronosHome({super.key});

  @override
  State<ChronosHome> createState() => _ChronosHomeState();
}

class _ChronosHomeState extends State<ChronosHome> {
  int tab = 0;
  int selectedDay = DemoData.todayIndex;
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

  Widget _today() => _page([
    const _Eyebrow('星期四  /  10月29日'),
    const SizedBox(height: 6),
    const _Heading('今天，时间去了哪里？'),
    const SizedBox(height: 5),
    const _Hint('把每一段投入，变成看得见的选择。'),
    const SizedBox(height: 21),
    _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: lime, size: 16),
              const SizedBox(width: 7),
              const Text(
                '今日屏幕使用',
                style: TextStyle(
                  color: ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => tab = 1),
                style: TextButton.styleFrom(foregroundColor: sub),
                child: const Text('看趋势  →', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: SizedBox(
              width: 212,
              height: 212,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(212, 212),
                    painter: _RingPainter(),
                  ),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '5',
                        style: TextStyle(
                          color: ink,
                          fontSize: 68,
                          height: 0.95,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '小时 42 分钟',
                        style: TextStyle(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '比上周同日少 42 分钟',
                        style: TextStyle(color: sub, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _accentNote('今天的屏幕时间，正在往你想要的方向走。'),
        ],
      ),
      padding: const EdgeInsets.all(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF202D3B), panel, panel],
      ),
    ),
    const SizedBox(height: 15),
    _card(const _HourlyChart()),
    const SizedBox(height: 24),
    const _Section('时间分布', '今天的使用构成'),
    const SizedBox(height: 12),
    _card(const _CategoryBreakdown()),
    const SizedBox(height: 23),
    const _Section('你的目标', '按你设定的标准提醒'),
    const SizedBox(height: 12),
    _goalCard(() => setState(() => tab = 2)),
  ]);

  Widget _trends() => _page([
    const _Eyebrow('你的时间趋势'),
    const SizedBox(height: 6),
    const _Heading('看见变化，才有方向。'),
    const SizedBox(height: 6),
    const _Hint('本周使用时间 · 点击柱形查看每天'),
    const SizedBox(height: 22),
    _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '周${DemoData.weekdays[selectedDay]}',
                    style: const TextStyle(color: sub, fontSize: 11),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formatMinutes(DemoData.week[selectedDay]),
                    key: const Key('selected-day-duration'),
                    style: const TextStyle(
                      color: ink,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const _Badge('↓ 42 分钟'),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final active = index == selectedDay;
                final minutes = DemoData.week[index];
                return Expanded(
                  child: Semantics(
                    button: true,
                    label:
                        '周${DemoData.weekdays[index]}，${formatMinutes(minutes)}',
                    child: InkWell(
                      onTap: () => setState(() => selectedDay = index),
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: 27,
                            height: minutes / 420 * 155,
                            decoration: BoxDecoration(
                              color: active ? lime : panel2,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: active ? lime : line),
                            ),
                          ),
                          const SizedBox(height: 11),
                          Text(
                            DemoData.weekdays[index],
                            style: TextStyle(
                              color: active ? ink : sub,
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.w800
                                  : FontWeight.w500,
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
          const Divider(color: line, height: 28),
          _Hint('示例中的周平均为 ${formatMinutes(DemoData.weekAverageMinutes)}'),
        ],
      ),
    ),
    const SizedBox(height: 22),
    const _Section('这一周的发现', '基于演示数据的事实'),
    const SizedBox(height: 12),
    _insight(
      Icons.trending_down_rounded,
      lime,
      '屏幕时间正在下降',
      '今天比上周同日少了 42 分钟。持续观察，找到有效的改变。',
    ),
    const SizedBox(height: 11),
    _insight(
      Icons.bolt_rounded,
      const Color(0xFFF6B765),
      '傍晚是使用高峰',
      '18:00–21:00 的使用最集中。目标提醒可放在这段时间之前。',
    ),
    const SizedBox(height: 22),
    const _Section('类别占比', '今天的使用构成'),
    const SizedBox(height: 12),
    _card(const _CategoryBreakdown()),
  ]);

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
