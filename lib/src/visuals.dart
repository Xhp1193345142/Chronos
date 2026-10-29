part of '../main.dart';

Widget _page(List<Widget> children) => ListView(
  padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
  children: children,
);

Widget _card(
  Widget child, {
  EdgeInsets padding = const EdgeInsets.all(17),
  Color color = panel,
  Gradient? gradient,
}) => Container(
  width: double.infinity,
  padding: padding,
  decoration: BoxDecoration(
    color: gradient == null ? color : null,
    gradient: gradient,
    borderRadius: BorderRadius.circular(19),
    border: Border.all(color: line),
  ),
  child: child,
);

Widget _accentNote(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  decoration: BoxDecoration(
    color: lime.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      const Icon(Icons.trending_down_rounded, color: lime, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: const TextStyle(color: lime, fontSize: 11.5)),
      ),
    ],
  ),
);

Widget _insight(IconData icon, Color color, String title, String body) => _card(
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
              style: const TextStyle(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(color: sub, fontSize: 11.5, height: 1.45),
            ),
          ],
        ),
      ),
    ],
  ),
);

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: 89,
    );
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16,
    );
    const gap = 0.055;
    var start = -math.pi / 2;
    for (final item in DemoData.categories) {
      final sweep = item.minutes / DemoData.todayMinutes * math.pi * 2;
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep - gap,
        false,
        Paint()
          ..color = item.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => false;
}

class _HourlyChart extends StatelessWidget {
  const _HourlyChart();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          Icon(Icons.waves_rounded, color: sub, size: 17),
          SizedBox(width: 8),
          Text(
            '一天的节奏',
            style: TextStyle(
              color: ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Spacer(),
          Text('每小时活跃时长', style: TextStyle(color: sub, fontSize: 11)),
        ],
      ),
      const SizedBox(height: 21),
      SizedBox(
        height: 70,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(24, (index) {
            final minutes = DemoData.hourly[index];
            final color = index < 15
                ? const Color(0xFF78B7F7)
                : index < 21
                ? const Color(0xFFF6B765)
                : const Color(0xFFAA94F3);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.6),
                child: Container(
                  height: math.max(4, minutes / 40 * 66),
                  decoration: BoxDecoration(
                    color: minutes == 0 ? line : color,
                    borderRadius: BorderRadius.circular(4),
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
          _Hint('00:00'),
          _Hint('06:00'),
          _Hint('12:00'),
          _Hint('18:00'),
          _Hint('24:00'),
        ],
      ),
    ],
  );
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 9,
          child: Row(
            children: DemoData.categories
                .map(
                  (item) => Expanded(
                    flex: item.minutes,
                    child: Container(color: item.color),
                  ),
                )
                .toList(),
          ),
        ),
      ),
      const SizedBox(height: 19),
      ...DemoData.categories.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 17, color: item.color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(color: ink, fontSize: 12.5),
                ),
              ),
              Text(
                formatMinutes(item.minutes),
                style: const TextStyle(
                  color: ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(23, 18, 23, 15),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: lime,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.access_time_filled_rounded,
            color: bg,
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CHRONOS',
              style: TextStyle(
                color: ink,
                fontSize: 15,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text('看见时间的形状', style: TextStyle(color: sub, fontSize: 10.5)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: lime.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: lime.withValues(alpha: 0.27)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 6, color: lime),
              SizedBox(width: 6),
              Text(
                '演示数据',
                style: TextStyle(
                  color: lime,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
      Icons.dashboard_rounded,
      Icons.bar_chart_rounded,
      Icons.track_changes_rounded,
    ];
    const labels = ['今日', '趋势', '目标'];
    return Container(
      height: 67,
      decoration: const BoxDecoration(
        color: panel,
        border: Border(top: BorderSide(color: line)),
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
                    Icon(icons[index], color: active ? lime : sub, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: active ? lime : sub,
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
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
    style: const TextStyle(
      color: lime,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: ink,
      fontSize: 27,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: sub, fontSize: 11));
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: ink,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      const Spacer(),
      Text(subtitle, style: const TextStyle(color: sub, fontSize: 11)),
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
      Icon(icon, color: lime, size: 18),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          color: ink,
          fontSize: 14,
          fontWeight: FontWeight.w700,
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
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: lime.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: lime,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
