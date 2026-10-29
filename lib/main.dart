import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'demo_data.dart';

part 'src/chronos_shell.dart';
part 'src/live_data.dart';
part 'src/live_shell.dart';
part 'src/visuals.dart';

const bg = Color(0xFF0B1020);
const panel = Color(0xFF151C2E);
const panel2 = Color(0xFF1D2739);
const line = Color(0xFF2C374B);
const ink = Color(0xFFF6F7FB);
const sub = Color(0xFF9BA8BF);
const lime = Color(0xFFA7F070);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChronosApp());
}

class ChronosApp extends StatelessWidget {
  const ChronosApp({super.key, this.demoOnly = false});

  final bool demoOnly;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Chronos · 柯罗诺斯',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: lime,
        surface: panel,
        onSurface: ink,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: lime,
        inactiveTrackColor: line,
        thumbColor: lime,
        overlayColor: lime.withValues(alpha: 0.12),
      ),
    ),
    home: demoOnly || kIsWeb ? const ChronosHome() : const _LiveExperience(),
  );
}
