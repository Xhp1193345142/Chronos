import 'package:flutter/material.dart';

class UsageCategory {
  const UsageCategory(this.label, this.minutes, this.color, this.icon);

  final String label;
  final int minutes;
  final Color color;
  final IconData icon;
}

class DemoData {
  static const categories = <UsageCategory>[
    UsageCategory('社交与短视频', 158, Color(0xFFF6B765), Icons.play_circle_outline),
    UsageCategory('工作与学习', 106, Color(0xFF78B7F7), Icons.auto_stories_outlined),
    UsageCategory('影音娱乐', 54, Color(0xFFAA94F3), Icons.headphones_outlined),
    UsageCategory('其他', 24, Color(0xFF8DD5CB), Icons.apps_rounded),
  ];

  static const week = <int>[312, 385, 348, 342, 396, 286, 302];
  static const todayIndex = 3;
  static const lastWeekSameDayMinutes = 384;
  static int get todayMinutes =>
      categories.fold(0, (total, item) => total + item.minutes);
  static int get weekAverageMinutes =>
      (week.reduce((a, b) => a + b) / week.length).round();
  static const weekdays = <String>['一', '二', '三', '四', '五', '六', '日'];
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
}

String formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours == 0) return '$remaining 分钟';
  if (remaining == 0) return '$hours 小时';
  return '$hours 小时 $remaining 分钟';
}
