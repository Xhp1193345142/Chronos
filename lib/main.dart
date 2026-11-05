import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chronos_theme.dart';
import 'demo_data.dart';
import 'manual_timer.dart';

part 'src/chronos_shell.dart';
part 'src/live_data.dart';
part 'src/live_shell.dart';
part 'src/manual_timer_ui.dart';
part 'src/visuals.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChronosApp());
}

class ChronosApp extends StatefulWidget {
  const ChronosApp({super.key, this.demoOnly = false});

  final bool demoOnly;

  @override
  State<ChronosApp> createState() => _ChronosAppState();
}

class _ChronosAppState extends State<ChronosApp> {
  static const _preferenceKey = 'chronos_theme';
  final ManualTimerController _manualTimer = ManualTimerController();
  ChronosThemeChoice _choice = ChronosThemeChoice.system;
  bool _changedByUser = false;

  @override
  void initState() {
    super.initState();
    _manualTimer.load();
    _loadChoice();
  }

  @override
  void dispose() {
    _manualTimer.dispose();
    super.dispose();
  }

  Future<void> _loadChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_preferenceKey);
      final choice = ChronosThemeChoice.values.where(
        (value) => value.name == saved,
      );
      if (mounted && !_changedByUser && choice.isNotEmpty) {
        setState(() => _choice = choice.first);
      }
    } catch (_) {
      // The system theme remains usable if local preferences are unavailable.
    }
  }

  void _selectChoice(ChronosThemeChoice choice) {
    _changedByUser = true;
    setState(() => _choice = choice);
    SharedPreferences.getInstance()
        .then((prefs) {
          return prefs.setString(_preferenceKey, choice.name);
        })
        .catchError((Object _) => false);
  }

  void _resetChoice() {
    _changedByUser = true;
    setState(() => _choice = ChronosThemeChoice.system);
    SharedPreferences.getInstance()
        .then((prefs) {
          return prefs.remove(_preferenceKey);
        })
        .catchError((Object _) => false);
  }

  @override
  Widget build(BuildContext context) {
    final selected = switch (_choice) {
      ChronosThemeChoice.system || ChronosThemeChoice.morning =>
        chronosThemeData(ChronosPalette.morning, Brightness.light),
      ChronosThemeChoice.twilight => chronosThemeData(
        ChronosPalette.twilight,
        Brightness.dark,
      ),
      ChronosThemeChoice.sunset => chronosThemeData(
        ChronosPalette.sunset,
        Brightness.dark,
      ),
    };
    return ChronosThemeScope(
      choice: _choice,
      onChanged: _selectChoice,
      onReset: _resetChoice,
      child: MaterialApp(
        title: 'Chronos · 柯罗诺斯',
        debugShowCheckedModeBanner: false,
        theme: selected,
        darkTheme: _choice == ChronosThemeChoice.system
            ? chronosThemeData(ChronosPalette.twilight, Brightness.dark)
            : null,
        themeMode: _choice == ChronosThemeChoice.system
            ? ThemeMode.system
            : ThemeMode.light,
        themeAnimationDuration: Duration.zero,
        builder: (context, child) {
          final colors = chronosColors(context);
          final dark = Theme.of(context).brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: dark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarColor: colors.background,
              systemNavigationBarIconBrightness: dark
                  ? Brightness.light
                  : Brightness.dark,
            ),
            child: child!,
          );
        },
        home: kIsWeb && Uri.base.queryParameters['preview'] == 'journal'
            ? _JournalPreview(timer: _manualTimer)
            : widget.demoOnly || kIsWeb
            ? ChronosHome(timer: _manualTimer)
            : _LiveExperience(timer: _manualTimer),
      ),
    );
  }
}
