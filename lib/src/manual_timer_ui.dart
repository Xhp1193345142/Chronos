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

String _journalStart(ManualEntry entry, DateTime day) =>
    entry.startedAt.toLocal().isBefore(DateTime(day.year, day.month, day.day))
    ? '00:00'
    : _manualClock(entry.startedAt);

String _journalEnd(ManualEntry entry, DateTime day) {
  final boundary = DateTime(day.year, day.month, day.day + 1);
  if ((entry.endedAt ?? DateTime.now()).toLocal().compareTo(boundary) >= 0) {
    return '24:00';
  }
  return entry.isActive ? '现在' : _manualClock(entry.endedAt!);
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
      final p = chronosColors(context);
      final active = timer.active;
      return Container(
        key: const Key('timer-hero'),
        padding: const EdgeInsets.symmetric(vertical: 19),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: p.border),
            bottom: BorderSide(color: p.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (active == null) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '留下一段时间',
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          demo ? '本机计时 · 非演示记录' : '手动计时 · 仅存本机',
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    key: const Key('timer-start'),
                    onPressed: () => _start(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('开始计时', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final category in const ['工作', '学习', '阅读'])
                    Expanded(
                      child: TextButton(
                        key: Key('timer-quick-$category'),
                        onPressed: () => _start(context, category: category),
                        style: TextButton.styleFrom(
                          foregroundColor: p.textSecondary,
                          minimumSize: const Size(0, 44),
                          padding: EdgeInsets.zero,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: p.manualCategory(category),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              category,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.north_east_rounded, size: 11),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: p.manualCategory(active.category),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    active.isRunning ? '正在计时' : '已暂停',
                    style: TextStyle(color: p.accent, fontSize: 12),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        _showManualEntryEditor(context, timer, entry: active),
                    child: Text('${active.category}  ›'),
                  ),
                ],
              ),
              Text(
                _timerDuration(active.elapsed(timer.now)),
                key: const Key('timer-elapsed'),
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_manualClock(active.startedAt)} 开始${active.elapsed(timer.now).inHours >= 12 ? ' · 已超过 12 小时，请核对是否忘记结束' : ''}',
                style: TextStyle(color: p.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 16),
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
                  const SizedBox(width: 12),
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
            if (timer.error != null)
              Text(
                timer.error!,
                style: TextStyle(color: p.danger, fontSize: 12),
              ),
          ],
        ),
      );
    },
  );
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
      final p = chronosColors(context);
      final today = DateTime.now();
      final entries = timer.entriesForDay(today);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '一天的颜色',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ManualHistoryPage(timer: timer),
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: p.textSecondary),
                child: const Text('历史', style: TextStyle(fontSize: 12)),
              ),
              IconButton(
                key: const Key('timer-backfill'),
                tooltip: '补记时间',
                onPressed: () => _showManualEntryEditor(context, timer),
                icon: const Icon(Icons.add_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 3),
          _JournalLedger(
            timer: timer,
            day: today,
            entries: entries,
            onEntry: (entry) =>
                _showManualEntryEditor(context, timer, entry: entry),
          ),
          if (entries.isEmpty) ...[
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _JournalPreview(timer: timer),
                  ),
                ),
                child: const Text('看看手账样例  ↗', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _JournalLedger extends StatelessWidget {
  const _JournalLedger({
    required this.timer,
    required this.day,
    required this.entries,
    this.onEntry,
  });
  final ManualTimerController timer;
  final DateTime day;
  final List<ManualEntry> entries;
  final ValueChanged<ManualEntry>? onEntry;

  @override
  Widget build(BuildContext context) {
    final p = chronosColors(context);
    final ordered = [...entries]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final total = entries.fold(
      Duration.zero,
      (value, entry) => value + timer.entryDurationForDay(entry, day),
    );
    final categories = entries.map((entry) => entry.category).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                _timerDuration(total),
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 31,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '${entries.length} 段',
                style: TextStyle(color: p.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '手动记录 · 留白处尚未记录',
          style: TextStyle(color: p.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 22),
        _ManualDayStrip(timer: timer, day: day, entries: entries),
        const SizedBox(height: 17),
        if (categories.isNotEmpty)
          Wrap(
            spacing: 15,
            runSpacing: 8,
            children: [
              for (final category in categories)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: p.manualCategory(category),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category,
                      style: TextStyle(color: p.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
            ],
          ),
        const SizedBox(height: 22),
        if (ordered.isEmpty)
          Column(
            children: [
              for (final hour in ['08:00', '12:00', '18:00'])
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          hour,
                          style: TextStyle(
                            color: p.textSecondary.withValues(alpha: 0.65),
                            fontSize: 10,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: p.border.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              Text(
                '今天的故事，从一段记录开始。',
                style: TextStyle(color: p.textSecondary, fontSize: 12),
              ),
            ],
          )
        else ...[
          for (final entry in ordered.take(8))
            Semantics(
              button: onEntry != null,
              label:
                  '${entry.category}，${_manualClock(entry.startedAt)}开始，记录${_timerDuration(timer.entryDurationForDay(entry, day))}',
              child: InkWell(
                key: Key('timer-entry-${entry.id}'),
                onTap: onEntry == null ? null : () => onEntry!(entry),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 49,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _journalStart(entry, day),
                              style: TextStyle(
                                color: p.textPrimary,
                                fontSize: 11,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _journalEnd(entry, day),
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 3,
                        height: 62,
                        decoration: BoxDecoration(
                          color: p.manualCategory(entry.category),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: p.border.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.category,
                                      style: TextStyle(
                                        color: p.manualCategory(entry.category),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _timerDuration(
                                      timer.entryDurationForDay(entry, day),
                                    ),
                                    style: TextStyle(
                                      color: p.textSecondary,
                                      fontSize: 11,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entry.note.isEmpty
                                    ? entry.category
                                    : entry.note,
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                              if (entry.segments.length > 1)
                                Text(
                                  '含暂停 · 仅累计实际计时',
                                  style: TextStyle(
                                    color: p.textSecondary,
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
              ),
            ),
          if (ordered.length > 8) _Hint('另有 ${ordered.length - 8} 段 · 在历史中查看'),
        ],
      ],
    );
  }
}

class _JournalPreview extends StatelessWidget {
  const _JournalPreview({required this.timer});
  final ManualTimerController timer;

  @override
  Widget build(BuildContext context) {
    final day = DateTime(2026, 11, 5);
    ManualEntry sample(
      String id,
      String category,
      String note,
      int hour,
      int minute,
      int length,
    ) {
      final start = DateTime(2026, 11, 5, hour, minute).toUtc();
      final end = start.add(Duration(minutes: length));
      return ManualEntry(
        id: id,
        category: category,
        note: note,
        segments: [ManualSegment(start, end)],
        completedAt: end,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('手账样例'),
        leading: IconButton(
          tooltip: '返回今日',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement<void, void>(
                context,
                MaterialPageRoute(builder: (_) => ChronosHome(timer: timer)),
              );
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: '切换主题',
            onPressed: () => showChronosThemePicker(context),
            icon: const Icon(Icons.palette_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 610),
          child: _page([
            const _Eyebrow('只读样例 · 不保存到本机'),
            const SizedBox(height: 10),
            const _Heading('平凡的一天'),
            const SizedBox(height: 8),
            const _Hint('11月5日 · 以下活动均为示例，与真实记录分开。'),
            const SizedBox(height: 30),
            _JournalLedger(
              timer: timer,
              day: day,
              entries: [
                sample('sample-work', '工作', '给一个想法，完整的专注', 9, 0, 110),
                sample('sample-life', '生活', '做午饭，慢慢吃', 12, 10, 45),
                sample('sample-read', '阅读', '读完搁置很久的那一章', 14, 0, 50),
                sample('sample-exercise', '运动', '去河边走一走', 17, 20, 40),
              ],
            ),
            const SizedBox(height: 20),
            const _Hint('手机使用会出现在独立区域，两种时长不相加。'),
          ]),
        ),
      ),
    );
  }
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
              height: 30,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  for (var hour = 0; hour <= 24; hour++)
                    Positioned(
                      left: (constraints.maxWidth - 1) * hour / 24,
                      top: hour % 6 == 0 ? 2 : 8,
                      bottom: hour % 6 == 0 ? 2 : 8,
                      child: Container(
                        width: 1,
                        color: palette.border.withValues(alpha: 0.7),
                      ),
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
                            height: 14,
                            decoration: BoxDecoration(
                              color: palette.manualCategory(entry.category),
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
