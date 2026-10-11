import 'package:flutter/material.dart';

/// Bluff's two theme faces.
///
/// The games and the first-run flow paint their own dark chrome on top of
/// [light]; the account area (Profile, Settings, Players, Privacy) runs on
/// [dark], so tapping between them never flashes a pale Material screen.
class BluffTheme {
  static const Color ink = Color(0xff09090E);
  static const Color red = Color(0xffC62828);
  static const Color gold = Color(0xffFFD166);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,

      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
      ),

      fontFamily: 'NotoSans',

      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    );
  }

  /// Dark companion used by the account screens: Bluff's ink background,
  /// red/gold accents, and white-on-dark cards with hairline borders —
  /// the same language the home header and onboarding speak.
  static ThemeData get dark {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: red,
          brightness: Brightness.dark,
        ).copyWith(
          primary: red,
          onPrimary: Colors.white,
          secondary: gold,
          onSecondary: Colors.black,
          surface: ink,
          outline: Colors.white24,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ink,
      colorScheme: scheme,
      fontFamily: 'NotoSans',

      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          fontFamily: 'NotoSans',
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
        subtitleTextStyle: TextStyle(
          color: Colors.white60,
          fontSize: 13,
          fontFamily: 'NotoSans',
        ),
      ),

      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        space: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white70,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? red : Colors.white12,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? red : Colors.white54,
        ),
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xff1C1C26),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontFamily: 'NotoSans',
        ),
        behavior: SnackBarBehavior.floating,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: red.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: 'NotoSans',
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: 'NotoSans',
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xff14141C),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          fontFamily: 'NotoSans',
        ),
        contentTextStyle: const TextStyle(
          color: Colors.white70,
          fontSize: 14.5,
          height: 1.4,
          fontFamily: 'NotoSans',
        ),
      ),

      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white, fontFamily: 'NotoSans'),
        bodySmall: TextStyle(color: Colors.white70, fontFamily: 'NotoSans'),
      ),
    );
  }
}
