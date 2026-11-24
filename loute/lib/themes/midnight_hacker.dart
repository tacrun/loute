import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Midnight Hacker Theme - the only theme for LOUTE.
/// Pitch black (#000000) background, hacker green text, no rounded corners, outline-only icons.
class MidnightHacker {
  MidnightHacker._();

  // ── Color Palette ──
  static const Color background = Color(0xFF000000); // Pitch black
  static const Color primary = Color(0xFF00FF41);    // Hacker green
  static const Color negative = Color(0xFFFF3B30);   // Red
  static const Color positive = Color(0xFFFFBF00);   // Amber
  static const Color dimGreen = Color(0x8000FF41);   // 50% opacity green
  static const Color surface = Color(0xFF000000);    // Pitch black surface
  static const Color panelBg = Color(0xFF000000);    // Pitch black sidebar bg

  // ── Border helpers ──
  static const BorderSide greenBorder = BorderSide(color: primary, width: 1);
  static const BorderSide greenBorderThick = BorderSide(color: primary, width: 2);
  static const BorderSide redBorder = BorderSide(color: negative, width: 1);
  static const BorderSide amberBorder = BorderSide(color: positive, width: 1);

  static OutlineInputBorder inputBorder([Color c = primary, double w = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: c, width: w),
    );
  }

  // ── Text Styles (all monospaced hacker font) ──
  static TextStyle get monoStyle => GoogleFonts.jetBrainsMono(
        color: primary,
        fontSize: 14,
      );

  static TextStyle get monoSmall => GoogleFonts.jetBrainsMono(
        color: primary,
        fontSize: 12,
      );

  static TextStyle get heading => GoogleFonts.jetBrainsMono(
        color: primary,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get headingLarge => GoogleFonts.jetBrainsMono(
        color: primary,
        fontSize: 48,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get label => GoogleFonts.jetBrainsMono(
        color: primary,
        fontSize: 14,
      );

  static TextStyle get labelDim => GoogleFonts.jetBrainsMono(
        color: dimGreen,
        fontSize: 14,
      );

  // ── ThemeData ──
  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: positive,
        error: negative,
        surface: background,
        onPrimary: background,
        onSecondary: background,
        onError: background,
        onSurface: primary,
      ),
      fontFamily: GoogleFonts.jetBrainsMono().fontFamily,

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: primary,
        elevation: 0,
        shape: const Border(bottom: greenBorder),
        titleTextStyle: GoogleFonts.jetBrainsMono(
          color: primary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: primary),
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        color: background,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: greenBorder,
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Buttons ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: greenBorder,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: background,
          backgroundColor: primary,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),

      // ── Inputs ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        border: inputBorder(),
        enabledBorder: inputBorder(),
        focusedBorder: inputBorder(primary, 2),
        errorBorder: inputBorder(negative),
        focusedErrorBorder: inputBorder(negative, 2),
        labelStyle: GoogleFonts.jetBrainsMono(color: primary, fontSize: 14),
        hintStyle: GoogleFonts.jetBrainsMono(color: dimGreen, fontSize: 14),
        floatingLabelStyle: GoogleFonts.jetBrainsMono(color: primary, fontSize: 12),
        prefixIconColor: primary,
        suffixIconColor: primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),

      // ── Divider ──
      dividerColor: primary,
      dividerTheme: const DividerThemeData(color: primary, thickness: 1, space: 0),

      // ── Icons ──
      iconTheme: const IconThemeData(color: primary, size: 20),

      // ── Tooltips ──
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: primary, width: 1),
        ),
        textStyle: GoogleFonts.jetBrainsMono(color: primary, fontSize: 12),
      ),

      // ── Scrollbar ──
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(dimGreen),
        trackColor: WidgetStateProperty.all(background),
        radius: Radius.zero,
        thickness: WidgetStateProperty.all(4),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: greenBorder,
        ),
        titleTextStyle: GoogleFonts.jetBrainsMono(color: positive, fontSize: 20, fontWeight: FontWeight.w600),
        contentTextStyle: GoogleFonts.jetBrainsMono(color: primary, fontSize: 14),
      ),

      // ── Popup Menu ──
      popupMenuTheme: PopupMenuThemeData(
        color: background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: greenBorder,
        ),
        textStyle: GoogleFonts.jetBrainsMono(color: primary, fontSize: 14),
      ),

      // ── Drawer ──
      drawerTheme: const DrawerThemeData(
        backgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
}
