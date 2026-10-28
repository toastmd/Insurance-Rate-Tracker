import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors one per carrier in charts and legends.
const carrierPalette = <Color>[
  Color(0xFF1E5B4E), Color(0xFFC2702A), Color(0xFF3E6FB0), Color(0xFF9A4A8F),
  Color(0xFF5E8F2E), Color(0xFFB5404E), Color(0xFF2E8C93), Color(0xFF7A6230),
  Color(0xFF5A5FB8), Color(0xFFA06A00),
];

Color carrierColor(int index) => carrierPalette[index % carrierPalette.length];

/// App-specific colors for price increases, decreases and bars.
@immutable
class RateColors extends ThemeExtension<RateColors> {
  const RateColors({
    required this.up,
    required this.upSoft,
    required this.down,
    required this.downSoft,
    required this.bar,
    required this.brandSoft,
  });

  final Color up, upSoft, down, downSoft, bar, brandSoft;

  @override
  RateColors copyWith({Color? up, Color? upSoft, Color? down, Color? downSoft, Color? bar, Color? brandSoft}) =>
      RateColors(
        up: up ?? this.up,
        upSoft: upSoft ?? this.upSoft,
        down: down ?? this.down,
        downSoft: downSoft ?? this.downSoft,
        bar: bar ?? this.bar,
        brandSoft: brandSoft ?? this.brandSoft,
      );

  @override
  RateColors lerp(ThemeExtension<RateColors>? other, double t) {
    if (other is! RateColors) return this;
    return RateColors(
      up: Color.lerp(up, other.up, t)!,
      upSoft: Color.lerp(upSoft, other.upSoft, t)!,
      down: Color.lerp(down, other.down, t)!,
      downSoft: Color.lerp(downSoft, other.downSoft, t)!,
      bar: Color.lerp(bar, other.bar, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
    );
  }
}

extension RateColorsX on BuildContext {
  RateColors get rc => Theme.of(this).extension<RateColors>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E5B4E),
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xFF62B8A0) : const Color(0xFF1E5B4E),
    onPrimary: dark ? const Color(0xFF0C1613) : Colors.white,
    surface: dark ? const Color(0xFF18211E) : Colors.white,
    onSurface: dark ? const Color(0xFFE6EEEA) : const Color(0xFF16211D),
    onSurfaceVariant: dark ? const Color(0xFF97A8A0) : const Color(0xFF56665F),
    outlineVariant: dark ? const Color(0xFF2B3833) : const Color(0xFFD2DBD4),
    surfaceContainerLow: dark ? const Color(0xFF1E2925) : const Color(0xFFF5F8F4),
    error: dark ? const Color(0xFFF08591) : const Color(0xFFA3303D),
  );
  final background = dark ? const Color(0xFF101614) : const Color(0xFFEDF1EC);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  TextTheme text;
  try {
    // Downloaded on first run and cached; falls back to the system font offline.
    text = GoogleFonts.getTextTheme('Bricolage Grotesque', base.textTheme);
  } catch (_) {
    text = base.textTheme;
  }

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );

  return base.copyWith(
    scaffoldBackgroundColor: background,
    canvasColor: background,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: dark ? const Color(0xFF1F3A33) : const Color(0xFFDAEAE3),
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: background,
      indicatorColor: dark ? const Color(0xFF1F3A33) : const Color(0xFFDAEAE3),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: scheme.primary, width: 2)),
    ),
    extensions: [
      RateColors(
        up: scheme.error,
        upSoft: dark ? const Color(0xFF3A2025) : const Color(0xFFF6E1E3),
        down: dark ? const Color(0xFF6FCE96) : const Color(0xFF2A764A),
        downSoft: dark ? const Color(0xFF1C3527) : const Color(0xFFDCEFE2),
        bar: dark ? const Color(0xFF33433D) : const Color(0xFFC9D4CD),
        brandSoft: dark ? const Color(0xFF1F3A33) : const Color(0xFFDAEAE3),
      ),
    ],
  );
}
