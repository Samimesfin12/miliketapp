import 'package:flutter/material.dart';

const kPrimary = Color(0xFF00502A);
const kPrimaryDark = Color(0xFF0F6A3C);
const kAccent = Color(0xFFFFC107);
const kDanger = Color(0xFFBA1A1A);
const kBackground = Color(0xFFFCF9F8);
const kSurface = Color(0xFFFCF9F8);
const kSurfaceDim = Color(0xFFDCD9D9);
const kSurfaceBright = Color(0xFFFCF9F8);
const kSurfaceContainerLowest = Color(0xFFFFFFFF);
const kSurfaceContainerLow = Color(0xFFF6F3F2);
const kSurfaceContainer = Color(0xFFF0EDED);
const kSurfaceContainerHigh = Color(0xFFEAE7E7);
const kSurfaceContainerHighest = Color(0xFFE5E2E1);
const kOnSurface = Color(0xFF1B1B1C);
const kOnSurfaceVariant = Color(0xFF3F4941);
const kInverseSurface = Color(0xFF303030);
const kInverseOnSurface = Color(0xFFF3F0EF);
const kOutline = Color(0xFF6F7A70);
const kOutlineVariant = Color(0xFFBFC9BE);
const kSurfaceTint = Color(0xFF136C3E);
const kSecondary = Color(0xFF006D3E);
const kTertiary = Color(0xFF584100);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kBackground,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: kPrimary,
      onPrimary: Colors.white,
      secondary: kSecondary,
      onSecondary: Colors.white,
      error: kDanger,
      onError: Colors.white,
      surface: kSurface,
      onSurface: kOnSurface,
    ),
    fontFamily: 'Lexend',
  );
}
