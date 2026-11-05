import 'package:flutter/material.dart';

enum ChronosThemeChoice { system, twilight, morning, sunset }

extension ChronosThemeChoiceLabel on ChronosThemeChoice {
  String get label => switch (this) {
    ChronosThemeChoice.system => '跟随系统',
    ChronosThemeChoice.twilight => '暮光星图',
    ChronosThemeChoice.morning => '晨雾纸感',
    ChronosThemeChoice.sunset => '日落脉冲',
  };

  String get description => switch (this) {
    ChronosThemeChoice.system => '深色用星图，浅色用纸感',
    ChronosThemeChoice.twilight => '安静、精密的深色仪表盘',
    ChronosThemeChoice.morning => '明亮、易读的浅色界面',
    ChronosThemeChoice.sunset => '温暖、有行动感的深色界面',
  };
}

@immutable
class ChronosPalette extends ThemeExtension<ChronosPalette> {
  const ChronosPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.positive,
    required this.caution,
    required this.danger,
    required this.usageLow,
    required this.usageMedium,
    required this.usageHigh,
    required this.social,
    required this.work,
    required this.entertainment,
    required this.other,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color positive;
  final Color caution;
  final Color danger;
  final Color usageLow;
  final Color usageMedium;
  final Color usageHigh;
  final Color social;
  final Color work;
  final Color entertainment;
  final Color other;

  Color manualCategory(String category) => switch (category) {
    '工作' => work,
    '学习' => entertainment,
    '阅读' => other,
    '运动' => social,
    '生活' => Color.lerp(social, danger, 0.55)!,
    '社交' => Color.lerp(entertainment, danger, 0.5)!,
    '休息' => usageMedium,
    _ => textSecondary,
  };

  Color categoryAt(int index) => switch (index % 4) {
    0 => social,
    1 => work,
    2 => entertainment,
    _ => other,
  };

  static const twilight = ChronosPalette(
    background: Color(0xFF0E1024),
    surface: Color(0xFF1B2040),
    surfaceRaised: Color(0xFF252B50),
    border: Color(0xFF3A4268),
    textPrimary: Color(0xFFF5F4FF),
    textSecondary: Color(0xFFB8C0D8),
    accent: Color(0xFFAA9BFF),
    positive: Color(0xFF65D6C5),
    caution: Color(0xFFF4BA6C),
    danger: Color(0xFFF08A75),
    usageLow: Color(0xFF526080),
    usageMedium: Color(0xFF8D84CE),
    usageHigh: Color(0xFFD3C5FF),
    social: Color(0xFFF4BA6C),
    work: Color(0xFF87B5FA),
    entertainment: Color(0xFFAA9BFF),
    other: Color(0xFF65D6C5),
  );

  static const morning = ChronosPalette(
    background: Color(0xFFF8F6F1),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF0F3EF),
    border: Color(0xFFD7DFDA),
    textPrimary: Color(0xFF292D2A),
    textSecondary: Color(0xFF59696D),
    accent: Color(0xFF466554),
    positive: Color(0xFF127B72),
    caution: Color(0xFF9D5D20),
    danger: Color(0xFFB74945),
    usageLow: Color(0xFFCADBD7),
    usageMedium: Color(0xFF75ADA3),
    usageHigh: Color(0xFF23877D),
    social: Color(0xFFB97821),
    work: Color(0xFF537EAE),
    entertainment: Color(0xFF8068AE),
    other: Color(0xFF338B7F),
  );

  static const sunset = ChronosPalette(
    background: Color(0xFF17131E),
    surface: Color(0xFF292230),
    surfaceRaised: Color(0xFF382B3D),
    border: Color(0xFF554253),
    textPrimary: Color(0xFFFFF8F3),
    textSecondary: Color(0xFFCCBCCB),
    accent: Color(0xFFFF967E),
    positive: Color(0xFF72D5C6),
    caution: Color(0xFFF5C66B),
    danger: Color(0xFFE85C5C),
    usageLow: Color(0xFF6C5B70),
    usageMedium: Color(0xFFB98DAB),
    usageHigh: Color(0xFFFFB9A7),
    social: Color(0xFFF5C66B),
    work: Color(0xFF93B4F3),
    entertainment: Color(0xFFC5A4F5),
    other: Color(0xFF72D5C6),
  );

  @override
  ChronosPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? positive,
    Color? caution,
    Color? danger,
    Color? usageLow,
    Color? usageMedium,
    Color? usageHigh,
    Color? social,
    Color? work,
    Color? entertainment,
    Color? other,
  }) => ChronosPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    border: border ?? this.border,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    accent: accent ?? this.accent,
    positive: positive ?? this.positive,
    caution: caution ?? this.caution,
    danger: danger ?? this.danger,
    usageLow: usageLow ?? this.usageLow,
    usageMedium: usageMedium ?? this.usageMedium,
    usageHigh: usageHigh ?? this.usageHigh,
    social: social ?? this.social,
    work: work ?? this.work,
    entertainment: entertainment ?? this.entertainment,
    other: other ?? this.other,
  );

  @override
  ChronosPalette lerp(ThemeExtension<ChronosPalette>? other, double t) {
    if (other is! ChronosPalette) return this;
    Color blend(Color a, Color b) => Color.lerp(a, b, t)!;
    return ChronosPalette(
      background: blend(background, other.background),
      surface: blend(surface, other.surface),
      surfaceRaised: blend(surfaceRaised, other.surfaceRaised),
      border: blend(border, other.border),
      textPrimary: blend(textPrimary, other.textPrimary),
      textSecondary: blend(textSecondary, other.textSecondary),
      accent: blend(accent, other.accent),
      positive: blend(positive, other.positive),
      caution: blend(caution, other.caution),
      danger: blend(danger, other.danger),
      usageLow: blend(usageLow, other.usageLow),
      usageMedium: blend(usageMedium, other.usageMedium),
      usageHigh: blend(usageHigh, other.usageHigh),
      social: blend(social, other.social),
      work: blend(work, other.work),
      entertainment: blend(entertainment, other.entertainment),
      other: blend(this.other, other.other),
    );
  }
}

ChronosPalette chronosColors(BuildContext context) =>
    Theme.of(context).extension<ChronosPalette>()!;

ThemeData chronosThemeData(ChronosPalette palette, Brightness brightness) {
  final colors =
      ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: brightness,
      ).copyWith(
        primary: palette.accent,
        onPrimary: palette.background,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        error: palette.danger,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    colorScheme: colors,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.textPrimary,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    extensions: [palette],
    dividerColor: palette.border,
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.accent,
      inactiveTrackColor: palette.border,
      thumbColor: palette.accent,
      overlayColor: palette.accent.withValues(alpha: 0.12),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: palette.surface),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.accent),
    ),
    iconTheme: IconThemeData(color: palette.textSecondary),
  );
}

class ChronosThemeScope extends InheritedWidget {
  const ChronosThemeScope({
    super.key,
    required this.choice,
    required this.onChanged,
    required this.onReset,
    required super.child,
  });

  final ChronosThemeChoice choice;
  final ValueChanged<ChronosThemeChoice> onChanged;
  final VoidCallback onReset;

  static ChronosThemeScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChronosThemeScope>()!;

  @override
  bool updateShouldNotify(ChronosThemeScope oldWidget) =>
      oldWidget.choice != choice;
}

Future<void> showChronosThemePicker(BuildContext context) {
  final scope = ChronosThemeScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '外观主题',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 5),
              const Text('选择后立即生效，重启应用也会保留。'),
              const SizedBox(height: 16),
              for (final choice in ChronosThemeChoice.values) ...[
                _ThemeChoiceTile(
                  choice: choice,
                  selected: choice == scope.choice,
                  onTap: () {
                    scope.onChanged(choice);
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ThemeChoiceTile extends StatelessWidget {
  const _ThemeChoiceTile({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final ChronosThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = chronosColors(context);
    final swatch = switch (choice) {
      ChronosThemeChoice.system =>
        Theme.of(context).brightness == Brightness.dark
            ? ChronosPalette.twilight
            : ChronosPalette.morning,
      ChronosThemeChoice.twilight => ChronosPalette.twilight,
      ChronosThemeChoice.morning => ChronosPalette.morning,
      ChronosThemeChoice.sunset => ChronosPalette.sunset,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '${choice.label}，${choice.description}',
      child: Material(
        color: selected ? current.surfaceRaised : current.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? current.accent : current.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: swatch.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: swatch.border),
                  ),
                  child: Center(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: swatch.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        choice.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        choice.description,
                        style: TextStyle(
                          color: current.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: current.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
