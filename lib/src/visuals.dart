part of '../main.dart';

Widget _page(List<Widget> children) => ListView(
  padding: const EdgeInsets.fromLTRB(22, 17, 22, 38),
  children: children,
);

Widget _card(
  BuildContext context,
  Widget child, {
  EdgeInsets padding = const EdgeInsets.all(17),
  Color? color,
  Gradient? gradient,
}) => Container(
  width: double.infinity,
  padding: padding,
  decoration: BoxDecoration(
    color: gradient == null ? color ?? chronosColors(context).surface : null,
    gradient: gradient,
    borderRadius: BorderRadius.circular(23),
    border: Border.all(
      color: chronosColors(context).border.withValues(alpha: 0.74),
    ),
  ),
  child: child,
);

Widget _insight(
  BuildContext context,
  IconData icon,
  Color color,
  String title,
  String body,
) => _card(
  context,
  Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: chronosColors(context).textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: TextStyle(
                color: chronosColors(context).textSecondary,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);

class _RingPainter extends CustomPainter {
  const _RingPainter(this.palette);

  final ChronosPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) / 2 - 9,
    );
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = palette.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11,
    );
    const gap = 0.055;
    var start = -math.pi / 2;
    for (final entry in DemoData.categories.asMap().entries) {
      final item = entry.value;
      final sweep = item.minutes / DemoData.todayMinutes * math.pi * 2;
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep - gap,
        false,
        Paint()
          ..color = palette.categoryAt(entry.key)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.selectedHour, required this.onSelect});

  final int selectedHour;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final peak = DemoData.peakWindowStart(DemoData.hourly);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${hourLabel(peak)}–${hourLabel(peak + 3)} 最集中，使用 ${formatMinutes(DemoData.peakWindowMinutes(DemoData.hourly))}',
          style: TextStyle(
            color: chronosColors(context).textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        const _Hint('一柱代表一小时 · 点按查看时长'),
        const SizedBox(height: 24),
        SizedBox(
          height: 78,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(24, (index) {
              final minutes = DemoData.hourly[index];
              final active = index == selectedHour;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: active,
                  label:
                      '${hourLabel(index)}到${hourLabel(index + 1)}，${formatMinutes(minutes)}',
                  child: InkWell(
                    key: Key('hour-$index'),
                    onTap: () => onSelect(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.4),
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        height: math.max(5, minutes / 40 * 72),
                        decoration: BoxDecoration(
                          color: active
                              ? chronosColors(context).accent
                              : _usageColor(context, minutes),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 9),
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
          '${hourLabel(selectedHour)}–${hourLabel(selectedHour + 1)}  ·  ${formatMinutes(DemoData.hourly[selectedHour])}',
          key: const Key('selected-hour-detail'),
          style: TextStyle(
            color: chronosColors(context).accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Hint('彩色 = 今天 · 竖线 = 前三周同日平均'),
      const SizedBox(height: 18),
      ...DemoData.categories.asMap().entries.map((entry) {
        final item = entry.value;
        final color = chronosColors(context).categoryAt(entry.key);
        final change = item.minutes - item.baselineMinutes;
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Semantics(
            label:
                '${item.label}今天${formatMinutes(item.minutes)}，比平均${change >= 0 ? '多' : '少'}${formatMinutes(change.abs())}',
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(item.icon, size: 17, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: chronosColors(context).textPrimary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Text(
                      '${change >= 0 ? '↑' : '↓'}${formatMinutes(change.abs())}',
                      style: TextStyle(
                        color: change > 0
                            ? color
                            : chronosColors(context).textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatMinutes(item.minutes),
                      style: TextStyle(
                        color: chronosColors(context).textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ComparisonBar(item: item, color: color),
              ],
            ),
          ),
        );
      }),
    ],
  );
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({required this.item, required this.color});
  final UsageCategory item;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = math.max(
        180,
        math.max(item.minutes, item.baselineMinutes) + 20,
      );
      final width = constraints.maxWidth;
      return SizedBox(
        height: 13,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: chronosColors(context).border,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 2,
              bottom: 2,
              width: width * item.minutes / scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
            Positioned(
              left: width * item.baselineMinutes / scale - 1,
              top: 0,
              bottom: 0,
              width: 2,
              child: ColoredBox(color: chronosColors(context).textPrimary),
            ),
          ],
        ),
      );
    },
  );
}

Color _usageColor(BuildContext context, int minutes) {
  if (minutes == 0) return chronosColors(context).border;
  if (minutes < 15) return chronosColors(context).usageLow;
  if (minutes < 30) return chronosColors(context).usageMedium;
  return chronosColors(context).usageHigh;
}

class _WeekRhythm extends StatelessWidget {
  const _WeekRhythm({required this.selectedDay, required this.onSelect});

  final int selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final selectedHours = DemoData.hourlyForDay(selectedDay);
    final peak = DemoData.peakWindowStart(selectedHours);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Hint('颜色越亮，使用越久'),
        const SizedBox(height: 17),
        ...List.generate(7, (day) {
          final selected = day == selectedDay;
          final hours = DemoData.hourlyForDay(day);
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Semantics(
              button: true,
              selected: selected,
              label:
                  '周${DemoData.weekdays[day]}，${formatMinutes(DemoData.week[day])}，点按查看高峰时段',
              child: InkWell(
                key: Key('week-day-$day'),
                onTap: () => onSelect(day),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? chronosColors(context).surfaceRaised
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: selected
                          ? chronosColors(context).border
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 17,
                        child: Text(
                          DemoData.weekdays[day],
                          style: TextStyle(
                            color: selected
                                ? chronosColors(context).accent
                                : chronosColors(context).textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(child: _IntensityStrip(hours: hours)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 55,
                        child: Text(
                          '${DemoData.week[day] ~/ 60}h${(DemoData.week[day] % 60).toString().padLeft(2, '0')}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: selected
                                ? chronosColors(context).textPrimary
                                : chronosColors(context).textSecondary,
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const Padding(
          padding: EdgeInsets.only(left: 32, right: 63, top: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Hint('00'),
              _Hint('06'),
              _Hint('12'),
              _Hint('18'),
              _Hint('24'),
            ],
          ),
        ),
        Divider(color: chronosColors(context).border, height: 27),
        Text(
          '周${DemoData.weekdays[selectedDay]} ${hourLabel(peak)}–${hourLabel(peak + 3)} 最集中 · ${formatMinutes(DemoData.peakWindowMinutes(selectedHours))}',
          key: const Key('selected-day-peak'),
          style: TextStyle(
            color: chronosColors(context).accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _IntensityStrip extends StatelessWidget {
  const _IntensityStrip({required this.hours});
  final List<int> hours;

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      24,
      (hour) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.7),
          child: Container(
            height: 17,
            decoration: BoxDecoration(
              color: _usageColor(context, hours[hour]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    ),
  );
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.selectedDay, required this.onSelect});

  final int selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final difference = DemoData.week[selectedDay] - DemoData.weekAverageMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '周${DemoData.weekdays[selectedDay]}  ${formatMinutes(DemoData.week[selectedDay])}',
              key: const Key('selected-day-duration'),
              style: TextStyle(
                color: chronosColors(context).textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${difference >= 0 ? '高于' : '低于'}周均 ${formatMinutes(difference.abs())}',
              style: TextStyle(
                color: chronosColors(context).textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        SizedBox(
          height: 128,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (day) {
              final selected = day == selectedDay;
              final minutes = DemoData.week[day];
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: '周${DemoData.weekdays[day]}，${formatMinutes(minutes)}',
                  child: InkWell(
                    onTap: () => onSelect(day),
                    borderRadius: BorderRadius.circular(7),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 27,
                          height: minutes / 420 * 99,
                          decoration: BoxDecoration(
                            color: selected
                                ? chronosColors(context).accent
                                : chronosColors(context).usageLow,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DemoData.weekdays[day],
                          style: TextStyle(
                            color: selected
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
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onExitDemo});

  final VoidCallback? onExitDemo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(23, 17, 20, 11),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: chronosColors(context).accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.access_time_rounded,
            color: chronosColors(context).accent,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Chronos',
          style: TextStyle(
            color: chronosColors(context).textPrimary,
            fontSize: 16,
            letterSpacing: -0.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: '切换主题',
          onPressed: () => showChronosThemePicker(context),
          icon: Icon(
            Icons.palette_outlined,
            color: chronosColors(context).textSecondary,
          ),
        ),
        InkWell(
          onTap: onExitDemo,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: chronosColors(context).accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: chronosColors(context).accent.withValues(alpha: 0.27),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 6,
                  color: chronosColors(context).accent,
                ),
                SizedBox(width: 6),
                Text(
                  '演示数据',
                  style: TextStyle(
                    color: chronosColors(context).accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Nav extends StatelessWidget {
  const _Nav({required this.tab, required this.onTap});

  final int tab;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.today_outlined,
      Icons.bar_chart_outlined,
      Icons.track_changes_outlined,
    ];
    const activeIcons = [
      Icons.today_rounded,
      Icons.bar_chart_rounded,
      Icons.track_changes_rounded,
    ];
    const labels = ['今日', '趋势', '目标'];
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: chronosColors(context).surface,
        border: Border(top: BorderSide(color: chronosColors(context).border)),
      ),
      child: Row(
        children: List.generate(3, (index) {
          final active = tab == index;
          return Expanded(
            child: Semantics(
              button: true,
              selected: active,
              child: InkWell(
                onTap: () => onTap(index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      active ? activeIcons[index] : icons[index],
                      color: active
                          ? chronosColors(context).accent
                          : chronosColors(context).textSecondary,
                      size: 21,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: active
                            ? chronosColors(context).accent
                            : chronosColors(context).textSecondary,
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: chronosColors(context).textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: chronosColors(context).textPrimary,
      fontSize: 31,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: chronosColors(context).textSecondary,
      fontSize: 12,
      height: 1.35,
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Flexible(
        child: Text(
          title,
          style: TextStyle(
            color: chronosColors(context).textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          subtitle,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: chronosColors(context).textSecondary,
            fontSize: 11.5,
          ),
        ),
      ),
    ],
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title, this.icon);
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: chronosColors(context).accent, size: 18),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          color: chronosColors(context).textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: chronosColors(context).accent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: chronosColors(context).accent,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
