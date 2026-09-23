import 'package:flutter/material.dart';

/// Navy + cyan palette used across the technician side of the app
/// (dashboard, jobs, settlement, KYC, etc.) — kept separate from [AppTheme],
/// which stays teal/green for the customer app. Tech / clean / modern feel:
/// deep navy for headers and gradients, cyan for buttons and active states.
class TechTheme {
  TechTheme._();

  static const primary = Color(0xFF0891B2);
  static const primaryDark = Color(0xFF0B3B57);
  static const primarySoft = Color(0xFFE0F4F8);
  static const canvas = Color(0xFFF3F7F9);
  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0xFFE3F6EA);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFE6EEFD);
  static const amber = Color(0xFFF59E0B);
  static const amberSoft = Color(0xFFFDF3DF);
  static const error = Color(0xFFDC2626);
}
