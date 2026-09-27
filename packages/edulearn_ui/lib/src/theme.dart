import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette sampled from the EduLearn teacher dashboard mockup.
abstract final class AppColors {
  static const sidebar = Color(0xFF1D5538);
  static const primary = Color(0xFF1B6D47);
  static const primaryDeep = Color(0xFF1E6140);
  static const primarySoft = Color(0xFFDEF5E5);

  static const background = Color(0xFFFBF7EE); // warm cream page
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFEDEAE2);
  static const divider = Color(0xFFF0EEE8);

  static const ink = Color(0xFF1B2420);
  static const inkSoft = Color(0xFF3F4945);
  static const muted = Color(0xFF6F7874);

  static const track = Color(0xFFEBECF1);
  static const chip = Color(0xFFF2F3F7);
  static const buttonGrey = Color(0xFFF3F5F9);
  static const buttonBorder = Color(0xFFDCE1EA);

  static const gold = Color(0xFFFFCE42); // logo
  static const amber = Color(0xFFD98F0E);
  static const amberSoft = Color(0xFFFFF2D1);
  static const blue = Color(0xFF2F7CF6);
  static const blueSoft = Color(0xFFE1ECFE);
  static const red = Color(0xFFDC3A3F);
  static const redSoft = Color(0xFFFFE3E2);
  static const link = Color(0xFF1A73E8);
  static const purple = Color(0xFF9B51E0); // attendance (reports)
  static const purpleSoft = Color(0xFFF1E6FD);
  static const chartGreen = Color(0xFF16704C);

  /// Series colors for classes (chart lines, legend dots, thumbnails).
  static const classPalette = <Color>[
    Color(0xFF16704C), // Grade 4 – Rizal (green)
    Color(0xFFF3C237), // Grade 5 – Bonifacio (amber)
    Color(0xFF3EB9FF), // Grade 6 – Mabini (sky)
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  static Color forClass(int index) =>
      classPalette[index.abs() % classPalette.length];
}

/// Foreground/background pairs used by icon badges, pills and avatars.
enum Tone {
  green(AppColors.primary, AppColors.primarySoft),
  blue(AppColors.blue, AppColors.blueSoft),
  amber(AppColors.amber, AppColors.amberSoft),
  red(AppColors.red, AppColors.redSoft),
  purple(AppColors.purple, AppColors.purpleSoft),
  neutral(AppColors.muted, AppColors.chip);

  const Tone(this.fg, this.bg);
  final Color fg;
  final Color bg;
}

abstract final class AppText {
  static const greeting =
      TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.2);
  static const sectionTitle =
      TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: AppColors.ink);
  static const itemTitle =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink);
  static const body =
      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink);
  static const meta =
      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.muted);
  static const label =
      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft);
  static const statValue =
      TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.15);
  static const dialogTitle =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink);
}

abstract final class AppDecorations {
  static final card = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
    boxShadow: const [
      BoxShadow(color: Color(0x0D2B2A1F), blurRadius: 20, offset: Offset(0, 6)),
    ],
  );
}

/// Layout breakpoints for the responsive shell.
abstract final class Breakpoints {
  /// Below this: drawer navigation + single column.
  static const compact = 700.0;

  /// At or above this: full sidebar with labels.
  static const wide = 1100.0;
}

abstract final class AppTheme {
  static TextStyle font({double? size, FontWeight? weight, Color? color}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final radius = BorderRadius.circular(10);
    OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
          .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      dividerColor: AppColors.divider,
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13.5),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13.5),
        border: outline(AppColors.buttonBorder),
        enabledBorder: outline(AppColors.buttonBorder),
        focusedBorder: outline(AppColors.primary, 1.6),
        errorBorder: outline(AppColors.red),
        focusedErrorBorder: outline(AppColors.red, 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: font(size: 14, weight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.buttonGrey,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: const BorderSide(color: AppColors.buttonBorder),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: font(size: 14, weight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.link,
          textStyle: font(size: 13.5, weight: FontWeight.w600),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: const Color(0x33000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: font(size: 13.5, color: AppColors.ink),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: font(size: 13.5, color: Colors.white, weight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(6)),
        textStyle: font(size: 12, color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    );
  }
}
