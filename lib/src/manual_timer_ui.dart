part of '../main.dart';

String _timerDuration(Duration duration) {
  final seconds = math.max(0, duration.inSeconds);
  final hours = seconds ~/ 3600;
  final minutes = (seconds ~/ 60) % 60;
  final remaining = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
}

String _manualClock(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _manualDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month}月${local.day}日';
}

class _TimerHero extends StatelessWidget {
  const _TimerHero({required this.timer, this.demo = false});

  final ManualTimerController timer;
  final bool demo;

  Future<void> _start(BuildContext context, {String category = '未分类'}) async {
    HapticFeedback.lightImpact();
    if (!await timer.start(category: category) && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(timer.error ?? '计时已在进行中')));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: timer,
    builder: (context, _) {
      final palette = chronosColors(context);
      final active = timer.active;
      return Container(
        key: const Key('timer-hero'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(21, 20, 21, 20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: palette.border.withValues(alpha: 0.65)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  active == null
                      ? '手动计时'
                      : active.isRunning
                      ? '正在计时'
                      : '已暂停',
                  style: TextStyle(
                    color: active == null
                        ? palette.textSecondary
                        : palette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  demo ? '本机记录 · 非演示' : '仅存本机',
                  style: TextStyle(color: palette.textSecondary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 19),
            if (active == null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '为此刻计时',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.9,
                      ),
                    ),
                  ),
                  _ChronosDial(color: palette.accent, track: palette.border),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '记录你正在做的事，稍后也能补充分类。',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 53,
                child: FilledButton.icon(
                  key: const Key('timer-start'),
                  onPressed: () => _start(context),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('开始计时'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 17),
                child: Divider(color: palette.border, height: 1),
              ),
              Row(
                children: [
                  for (final preset in const [
                    ('工作', Icons.work_outline_rounded),
                    ('学习', Icons.auto_stories_outlined),
                    ('阅读', Icons.menu_book_outlined),
                  ]) ...[
                    if (preset.$1 != '工作') const SizedBox(width: 7),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: Key('timer-quick-${preset.$1}'),
                        onPressed: () => _start(context, category: preset.$1),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 10,
                          ),
                          minimumSize: Size.zero,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: palette.border),
                          backgroundColor: palette.surfaceRaised.withValues(
                            alpha: 0.55,
                          ),
                          foregroundColor: palette.textPrimary,
                        ),
                        icon: Icon(
                          preset.$2,
                          size: 15,
                          color: palette.textSecondary,
                        ),
                        label: Text(
                          preset.$1,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              InkWell(
                onTap: () =>
                    _showManualEntryEditor(context, timer, entry: active),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        active.category,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      size: 17,
                      color: palette.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _timerDuration(active.elapsed(timer.now)),
                key: const Key('timer-elapsed'),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 39,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.8,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_manualClock(active.startedAt)} 开始${active.elapsed(timer.now).inHours >= 12 ? ' · 已超过 12 小时，请核对是否忘记结束' : ''}',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('timer-pause-resume'),
                      onPressed: active.isRunning ? timer.pause : timer.resume,
                      icon: Icon(
                        active.isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(active.isRunning ? '暂停' : '继续'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('timer-stop'),
                      onPressed: timer.stop,
                      child: const Text('结束'),
                    ),
                  ),
                ],
              ),
            ],
            if (timer.error != null) ...[
              const SizedBox(height: 10),
              Text(
                timer.error!,
                style: TextStyle(color: palette.danger, fontSize: 12),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _ChronosDial extends StatelessWidget {
  const _ChronosDial({required this.color, required this.track});

  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 49,
      height: 49,
      child: CustomPaint(painter: _ChronosDialPainter(color, track)),
    ),
  );
}

class _ChronosDialPainter extends CustomPainter {
  const _ChronosDialPainter(this.color, this.track);

  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.72,
      math.pi * 1.82,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    for (var tick = 0; tick < 12; tick++) {
      final angle = tick * math.pi / 6 - math.pi / 2;
      final outer =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 5);
      final inner =
          center +
          Offset(math.cos(angle), math.sin(angle)) *
              (radius - (tick % 3 == 0 ? 9 : 7));
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = tick % 3 == 0 ? color : track
          ..strokeWidth = tick % 3 == 0 ? 1.5 : 1,
      );
    }
    canvas.drawLine(
      center,
      center + Offset(0, -(radius - 11)),
      Paint()
        ..color = color
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 2.3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ChronosDialPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.track != track;
}

class _TimerDockAction extends StatelessWidget {
  const _TimerDockAction({required this.timer, required this.onOpen});

  final ManualTimerController timer;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: timer,
    builder: (context, _) {
      final active = timer.active;
      return Padding(
        padding: const EdgeInsets.only(left: 8, right: 18),
        child: Semantics(
          button: true,
          label: active == null ? '开始计时' : '打开正在进行的计时',
          child: InkWell(
            key: const Key('timer-dock'),
            customBorder: const CircleBorder(),
            onTap: () {
              if (active == null) {
                timer.start().then((started) {
                  if (!started && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(timer.error ?? '计时已在进行中')),
                    );
                  }
                });
              } else {
                onOpen();
              }
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: chronosColors(context).accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                active == null ? Icons.add_rounded : Icons.timer_outlined,
                color: chronosColors(context).background,
                size: 25,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ManualToday extends StatelessWidget {
  const _ManualToday({required this.timer});

  final ManualTimerController timer;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: timer,
    builder: (context, _) {
      final palette = chronosColors(context);
      final today = DateTime.now();
      final entries = timer.entriesForDay(today);
      final total = timer.durationForDay(today);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _Section('今日记录', '${_manualDate(today)} · 手动计时')),
              TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ManualHistoryPage(timer: timer),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: palette.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: const Text('全部'),
              ),
              TextButton.icon(
                key: const Key('timer-backfill'),
                onPressed: () => _showManualEntryEditor(context, timer),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('补记'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _chartPanel(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entries.isEmpty
                          ? '还没有手动记录'
                          : '已记录 ${_timerDuration(total)}',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${entries.length} 段',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (entries.isEmpty) ...[
                  const SizedBox(height: 9),
                  const _Hint('点击上方开始，或补记已经做过的事。'),
                ] else ...[
                  const SizedBox(height: 17),
                  _ManualDayStrip(timer: timer, day: today, entries: entries),
                ],
                for (final entry in entries.take(5)) ...[
                  const SizedBox(height: 14),
                  InkWell(
                    key: Key('timer-entry-${entry.id}'),
                    onTap: () =>
                        _showManualEntryEditor(context, timer, entry: entry),
                    child: Row(
                      children: [
                        Container(width: 2, height: 32, color: palette.accent),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.category,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_manualClock(entry.startedAt)}–${entry.isActive ? '现在' : _manualClock(entry.endedAt!)}${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _timerDuration(
                            timer.entryDurationForDay(entry, today),
                          ),
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 12,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: palette.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
                if (entries.length > 5) ...[
                  const SizedBox(height: 13),
                  Text(
                    '另有 ${entries.length - 5} 段记录',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _ManualDayStrip extends StatelessWidget {
  const _ManualDayStrip({
    required this.timer,
    required this.day,
    required this.entries,
  });

  final ManualTimerController timer;
  final DateTime day;
  final List<ManualEntry> entries;

  @override
  Widget build(BuildContext context) {
    final palette = chronosColors(context);
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final span = end.difference(start).inMilliseconds;
    return Semantics(
      label: '${_manualDate(day)}的手动记录时间分布，共 ${entries.length} 段',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: 12,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    width: constraints.maxWidth,
                    color: palette.border,
                  ),
                  for (final entry in entries)
                    for (final segment in entry.segments)
                      if ((segment.end ?? timer.now).toLocal().isAfter(start) &&
                          segment.start.toLocal().isBefore(end))
                        Positioned(
                          left:
                              constraints.maxWidth *
                              (segment.start.toLocal().isBefore(start)
                                  ? 0
                                  : segment.start
                                        .toLocal()
                                        .difference(start)
                                        .inMilliseconds) /
                              span,
                          width: math.max(
                            2,
                            constraints.maxWidth *
                                ((segment.end ?? timer.now).toLocal().isAfter(
                                          end,
                                        )
                                        ? end
                                        : (segment.end ?? timer.now).toLocal())
                                    .difference(
                                      segment.start.toLocal().isBefore(start)
                                          ? start
                                          : segment.start.toLocal(),
                                    )
                                    .inMilliseconds /
                                span,
                          ),
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              color: palette.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in ['00', '06', '12', '18', '24'])
                Text(
                  label,
                  style: TextStyle(color: palette.textSecondary, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualHistoryPage extends StatefulWidget {
  const _ManualHistoryPage({required this.timer});

  final ManualTimerController timer;

  @override
  State<_ManualHistoryPage> createState() => _ManualHistoryPageState();
}

class _ManualHistoryPageState extends State<_ManualHistoryPage> {
  DateTime day = DateTime.now();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('手动记录')),
    body: AnimatedBuilder(
      animation: widget.timer,
      builder: (context, _) {
        final palette = chronosColors(context);
        final entries = widget.timer.entriesForDay(day);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 610),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '前一天',
                      onPressed: () => setState(
                        () => day = DateTime(day.year, day.month, day.day - 1),
                      ),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: day,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (selected != null) setState(() => day = selected);
                        },
                        child: Text('${day.year}年${_manualDate(day)}'),
                      ),
                    ),
                    IconButton(
                      tooltip: '后一天',
                      onPressed: DateUtils.isSameDay(day, DateTime.now())
                          ? null
                          : () => setState(
                              () => day = DateTime(
                                day.year,
                                day.month,
                                day.day + 1,
                              ),
                            ),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '已记录 ${_timerDuration(widget.timer.durationForDay(day))}',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 18),
                if (entries.isEmpty)
                  const _Hint('这一天没有手动记录。')
                else ...[
                  _ManualDayStrip(
                    timer: widget.timer,
                    day: day,
                    entries: entries,
                  ),
                  const SizedBox(height: 20),
                  for (final entry in entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.category),
                      subtitle: Text(
                        '${_manualClock(entry.startedAt)}–${entry.isActive ? '现在' : _manualClock(entry.endedAt!)}${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
                      ),
                      trailing: Text(
                        _timerDuration(
                          widget.timer.entryDurationForDay(entry, day),
                        ),
                      ),
                      onTap: () => _showManualEntryEditor(
                        context,
                        widget.timer,
                        entry: entry,
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _showManualEntryEditor(
                    context,
                    widget.timer,
                    initialDay: day,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('补记时间'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ManualWeek extends StatelessWidget {
  const _ManualWeek({required this.timer});

  final ManualTimerController timer;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: timer,
    builder: (context, _) {
      final palette = chronosColors(context);
      final today = DateTime.now();
      final days = [
        for (var offset = 6; offset >= 0; offset--)
          DateTime(today.year, today.month, today.day - offset),
      ];
      final durations = [for (final day in days) timer.durationForDay(day)];
      final total = durations.fold(Duration.zero, (a, b) => a + b);
      final maxMinutes = math.max(
        1,
        durations.map((d) => d.inMinutes).reduce(math.max),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Section('手动记录趋势', '近七天 · 本机记录'),
          const SizedBox(height: 12),
          if (total == Duration.zero)
            _chartPanel(context, const _Hint('还没有手动记录。开始计时后，这里会显示七天变化。'))
          else if (total < const Duration(minutes: 1))
            _chartPanel(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '七天共记录 ${_timerDuration(total)}',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      for (var index = 0; index < 7; index++)
                        Expanded(
                          child: Semantics(
                            label:
                                '${_manualDate(days[index])} 手动记录 ${_timerDuration(durations[index])}',
                            child: Column(
                              children: [
                                Container(
                                  width: 20,
                                  height: durations[index] > Duration.zero
                                      ? 12
                                      : 2,
                                  decoration: BoxDecoration(
                                    color: durations[index] > Duration.zero
                                        ? palette.accent
                                        : palette.border,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _weekday(days[index]),
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                if (durations[index] > Duration.zero)
                                  Text(
                                    '${durations[index].inSeconds}s',
                                    style: TextStyle(
                                      color: palette.accent,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            )
          else
            _chartPanel(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '七天共记录 ${_timerDuration(total)}',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 17),
                  SizedBox(
                    height: 114,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var index = 0; index < 7; index++)
                          Expanded(
                            child: Semantics(
                              label:
                                  '${_manualDate(days[index])} 手动记录 ${_timerDuration(durations[index])}',
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    durations[index].inMinutes == 0
                                        ? '—'
                                        : '${durations[index].inMinutes ~/ 60}h${(durations[index].inMinutes % 60).toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 18,
                                    height: durations[index].inMinutes == 0
                                        ? 2
                                        : math.max(
                                            6,
                                            71 *
                                                durations[index].inMinutes /
                                                maxMinutes,
                                          ),
                                    decoration: BoxDecoration(
                                      color: durations[index].inMinutes == 0
                                          ? palette.border
                                          : palette.accent,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${days[index].month}/${days[index].day}',
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

void _showManualEntryEditor(
  BuildContext context,
  ManualTimerController timer, {
  ManualEntry? entry,
  DateTime? initialDay,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: chronosColors(context).surface,
    builder: (_) =>
        _ManualEntryEditor(timer: timer, entry: entry, initialDay: initialDay),
  );
}

class _ManualEntryEditor extends StatefulWidget {
  const _ManualEntryEditor({required this.timer, this.entry, this.initialDay});

  final ManualTimerController timer;
  final ManualEntry? entry;
  final DateTime? initialDay;

  @override
  State<_ManualEntryEditor> createState() => _ManualEntryEditorState();
}

class _ManualEntryEditorState extends State<_ManualEntryEditor> {
  late DateTime start;
  late DateTime end;
  late String category;
  late TextEditingController note;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final defaultEnd =
        widget.initialDay == null || DateUtils.isSameDay(widget.initialDay, now)
        ? now
        : DateTime(
            widget.initialDay!.year,
            widget.initialDay!.month,
            widget.initialDay!.day,
            9,
            30,
          );
    start =
        widget.entry?.startedAt.toLocal() ??
        defaultEnd.subtract(const Duration(minutes: 30));
    end = widget.entry?.endedAt?.toLocal() ?? defaultEnd;
    category = widget.entry?.category ?? '未分类';
    note = TextEditingController(text: widget.entry?.note ?? '');
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool starting) async {
    final initial = starting ? start : end;
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (starting) {
        start = value;
      } else {
        end = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = chronosColors(context);
    final active = widget.entry?.isActive == true;
    return SafeArea(
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
              Text(
                active
                    ? '正在记录'
                    : widget.entry == null
                    ? '补记时间'
                    : '编辑记录',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                active ? '分类和备注可以随时调整。' : '这段时间会计入手动记录，不与屏幕使用时间相加。',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 7,
                runSpacing: 3,
                children: [
                  for (final value in manualCategories)
                    ChoiceChip(
                      label: Text(value),
                      selected: category == value,
                      onSelected: (_) {
                        setState(() => category = value);
                        if (active) {
                          widget.timer.setCategory(widget.entry!.id, value);
                        }
                      },
                    ),
                ],
              ),
              if (!active &&
                  (widget.entry == null ||
                      (widget.entry!.segments.length == 1 &&
                          widget.entry!.segments.last.end ==
                              widget.entry!.endedAt))) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(true),
                        child: Text(
                          '开始 ${_manualDate(start)} ${_manualClock(start)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(false),
                        child: Text(
                          '结束 ${_manualDate(end)} ${_manualClock(end)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (!active &&
                  widget.entry != null &&
                  (widget.entry!.segments.length > 1 ||
                      widget.entry!.segments.last.end !=
                          widget.entry!.endedAt)) ...[
                const SizedBox(height: 14),
                const _Hint('这段记录含有暂停，当前可修改分类和备注。要调整时间，请删除后补记。'),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: note,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('timer-save-entry'),
                  onPressed: () async {
                    String? error;
                    if (active) {
                      await widget.timer.setNote(widget.entry!.id, note.text);
                    } else {
                      error = await widget.timer.saveInterval(
                        id: widget.entry?.id,
                        start: start,
                        end: end,
                        category: category,
                        note: note.text,
                      );
                    }
                    if (!context.mounted) return;
                    if (error == null) {
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(error)));
                    }
                  },
                  child: Text(active ? '保存分类与备注' : '保存记录'),
                ),
              ),
              if (widget.entry != null) ...[
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('删除这段记录？'),
                          content: const Text('这段手动记录将从本机删除。'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await widget.timer.delete(widget.entry!.id);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: Text(
                      '删除记录',
                      style: TextStyle(color: palette.danger),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
