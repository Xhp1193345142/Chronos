import 'package:flutter/material.dart';

class UsageCategory {
  const UsageCategory(
    this.label,
    this.minutes,
    this.baselineMinutes,
    this.color,
    this.icon,
  );

  final String label;
  final int minutes;
  final int baselineMinutes;
  final Color color;
  final IconData icon;
}

class DemoData {
  static const categories = <UsageCategory>[
    UsageCategory(
      '社交与短视频',
      158,
      140,
      Color(0xFFF6B765),
      Icons.play_circle_outline,
    ),
    UsageCategory(
      '工作与学习',
      106,
      124,
      Color(0xFF78B7F7),
      Icons.auto_stories_outlined,
    ),
    UsageCategory('影音娱乐', 54, 62, Color(0xFFAA94F3), Icons.headphones_outlined),
    UsageCategory('其他', 24, 30, Color(0xFF8DD5CB), Icons.apps_rounded),
  ];

  // The seven demo dates run from Friday, October 23 through Thursday,
  // October 29. The final row is the current day shown on the Today screen.
  static const week = <int>[312, 385, 348, 396, 286, 302, 342];
  static const todayIndex = 6;
  static const lastWeekSameDayMinutes = 384;
  static int get todayMinutes =>
      categories.fold(0, (total, item) => total + item.minutes);
  static int get weekAverageMinutes =>
      (week.reduce((a, b) => a + b) / week.length).round();
  static const weekdays = <String>['五', '六', '日', '一', '二', '三', '四'];
  static const hourly = <int>[
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    4,
    10,
    18,
    22,
    16,
    12,
    18,
    26,
    34,
    28,
    21,
    30,
    36,
    34,
    19,
    11,
    3,
  ];

  // A deterministic demo fixture for the seven-day rhythm view. Each row
  // sums to the corresponding daily total; production data will come from
  // platform-specific reporting surfaces.
  static List<int> hourlyForDay(int day) {
    if (day == todayIndex) return hourly;
    const offsets = [1, 0, -1, 0, 1, -1, 0];
    final rotated = List<int>.generate(
      24,
      (hour) => hourly[(hour + offsets[day] + 24) % 24],
    );
    final sourceTotal = rotated.reduce((a, b) => a + b);
    final scaled = rotated
        .map((minutes) => minutes * week[day] / sourceTotal)
        .toList();
    final result = scaled.map((minutes) => minutes.floor()).toList();
    final order = List<int>.generate(
      24,
      (index) => index,
    )..sort((a, b) => (scaled[b] - result[b]).compareTo(scaled[a] - result[a]));
    final remaining = week[day] - result.reduce((a, b) => a + b);
    for (var index = 0; index < remaining; index++) {
      result[order[index]]++;
    }
    return result;
  }

  static int peakWindowStart(List<int> hours, {int length = 3}) {
    var bestStart = 0;
    var bestTotal = -1;
    for (var start = 0; start <= hours.length - length; start++) {
      final total = hours.skip(start).take(length).reduce((a, b) => a + b);
      if (total > bestTotal) {
        bestTotal = total;
        bestStart = start;
      }
    }
    return bestStart;
  }

  static int peakWindowMinutes(List<int> hours, {int length = 3}) {
    final start = peakWindowStart(hours, length: length);
    return hours.skip(start).take(length).reduce((a, b) => a + b);
  }
}

String hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

String formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours == 0) return '$remaining 分钟';
  if (remaining == 0) return '$hours 小时';
  return '$hours 小时 $remaining 分钟';
}
