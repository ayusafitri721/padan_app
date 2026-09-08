import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand palette (main_dash.md)
  static const Color primary = Color(0xFF3A5A40); // Deep sage forest green
  static const Color secondary = Color(0xFF588157); // Verdant leaf green
  static const Color accent = Color(0xFFD97706); // Warm amber (food waste alerts)
  static const Color splashBackground = Color(0xFF2A4530);

  // Neutrals & surfaces
  static const Color background = Color(0xFFF9F6F0); // Warm cream canvas
  static const Color surface = Color(0xFFFFFFFF); // Cards / elevated
  static const Color tonalBadge = Color(0xFFE8F0EA); // Matcha tinted pill/tag
  static const Color textPrimary = Color(0xFF1E293B); // Deep slate charcoal
  static const Color mutedText = Color(0xFF64748B); // Slate gray
  static const Color cream = Color(0xFFF9F6F0);

  // Borders & elevation aids
  static const Color outline = Color(0xFFE2DDD5); // Hairline/fine borders
  static const Color warningSoft = Color(0xFFFEF3C7); // Warning pill bg

  // Error / destructive
  static const Color error = Color(0xFFDC2626);

  static const Color white = Colors.white;
  static const Color black = Colors.black;
}