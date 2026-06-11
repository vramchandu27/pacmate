import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand palette
  static const Color primary      = Color(0xFF378ADD);
  static const Color success      = Color(0xFF639922);
  static const Color danger       = Color(0xFFE24B4A);
  static const Color warning      = Color(0xFFBA7517);
  static const Color teal         = Color(0xFF1D9E75);
  static const Color purple       = Color(0xFF534AB7);
  static const Color navy         = Color(0xFF0F172A);

  // Light surface palette
  static const Color lightBackground   = Color(0xFFF8FAFC);
  static const Color lightSurface      = Color(0xFFFFFFFF);
  static const Color lightSurfaceVar   = Color(0xFFEFF6FF);
  static const Color lightOnSurface    = Color(0xFF0F172A);
  static const Color lightOnSurfaceVar = Color(0xFF475569);
  static const Color lightOutline      = Color(0xFFCBD5E1);
  static const Color lightOutlineVar   = Color(0xFFE2E8F0);

  // Dark surface palette
  static const Color darkBackground   = Color(0xFF0F172A);
  static const Color darkSurface      = Color(0xFF1E293B);
  static const Color darkSurfaceVar   = Color(0xFF334155);
  static const Color darkOnSurface    = Color(0xFFF1F5F9);
  static const Color darkOnSurfaceVar = Color(0xFF94A3B8);
  static const Color darkOutline      = Color(0xFF334155);
  static const Color darkOutlineVar   = Color(0xFF1E293B);

  // Semantic aliases
  static const Color error    = danger;
  static const Color info     = primary;
  static const Color positive = success;

  // Transparent helpers
  static const Color primaryAlpha10 = Color(0x1A378ADD);
  static const Color primaryAlpha20 = Color(0x33378ADD);
  static const Color dangerAlpha10  = Color(0x1AE24B4A);
  static const Color successAlpha10 = Color(0x1A639922);
  static const Color warningAlpha10 = Color(0x1ABA7517);
  static const Color tealAlpha10    = Color(0x1A1D9E75);
  static const Color purpleAlpha10  = Color(0x1A534AB7);
}

class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'Poppins';

  // ─── COLOR SCHEMES ────────────────────────────────────────────────────────

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,

    primary:          AppColors.primary,
    onPrimary:        Colors.white,
    primaryContainer: AppColors.lightSurfaceVar,
    onPrimaryContainer: AppColors.navy,

    secondary:          AppColors.teal,
    onSecondary:        Colors.white,
    secondaryContainer: Color(0xFFD1FAE5),
    onSecondaryContainer: Color(0xFF064E3B),

    tertiary:          AppColors.purple,
    onTertiary:        Colors.white,
    tertiaryContainer: Color(0xFFEDE9FE),
    onTertiaryContainer: Color(0xFF2E1065),

    error:          AppColors.danger,
    onError:        Colors.white,
    errorContainer: Color(0xFFFFE4E4),
    onErrorContainer: Color(0xFF7F1D1D),

    surface:          AppColors.lightSurface,
    onSurface:        AppColors.lightOnSurface,
    surfaceContainerHighest: AppColors.lightSurfaceVar,
    onSurfaceVariant: AppColors.lightOnSurfaceVar,

    outline:        AppColors.lightOutline,
    outlineVariant: AppColors.lightOutlineVar,

    shadow:           Color(0xFF000000),
    scrim:            Color(0xFF000000),
    inverseSurface:   AppColors.navy,
    onInverseSurface: AppColors.darkOnSurface,
    inversePrimary:   AppColors.primary,
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,

    primary:          AppColors.primary,
    onPrimary:        Colors.white,
    primaryContainer: Color(0xFF1E3A5F),
    onPrimaryContainer: Color(0xFFBFDBFE),

    secondary:          AppColors.teal,
    onSecondary:        Colors.white,
    secondaryContainer: Color(0xFF064E3B),
    onSecondaryContainer: Color(0xFFD1FAE5),

    tertiary:          AppColors.purple,
    onTertiary:        Colors.white,
    tertiaryContainer: Color(0xFF2E1065),
    onTertiaryContainer: Color(0xFFEDE9FE),

    error:          AppColors.danger,
    onError:        Colors.white,
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFFE4E4),

    surface:          AppColors.darkSurface,
    onSurface:        AppColors.darkOnSurface,
    surfaceContainerHighest: AppColors.darkSurfaceVar,
    onSurfaceVariant: AppColors.darkOnSurfaceVar,

    outline:        AppColors.darkOutline,
    outlineVariant: AppColors.darkOutlineVar,

    shadow:           Color(0xFF000000),
    scrim:            Color(0xFF000000),
    inverseSurface:   AppColors.lightSurface,
    onInverseSurface: AppColors.lightOnSurface,
    inversePrimary:   AppColors.primary,
  );

  // ─── TEXT THEME ───────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(Color onSurface, Color onSurfaceVar) {
    return TextTheme(
      // Display
      displayLarge:  TextStyle(fontFamily: _fontFamily, fontSize: 57, fontWeight: FontWeight.w700, color: onSurface, letterSpacing: -0.25),
      displayMedium: TextStyle(fontFamily: _fontFamily, fontSize: 45, fontWeight: FontWeight.w700, color: onSurface),
      displaySmall:  TextStyle(fontFamily: _fontFamily, fontSize: 36, fontWeight: FontWeight.w600, color: onSurface),
      // Headline
      headlineLarge:  TextStyle(fontFamily: _fontFamily, fontSize: 32, fontWeight: FontWeight.w700, color: onSurface),
      headlineMedium: TextStyle(fontFamily: _fontFamily, fontSize: 28, fontWeight: FontWeight.w600, color: onSurface),
      headlineSmall:  TextStyle(fontFamily: _fontFamily, fontSize: 24, fontWeight: FontWeight.w600, color: onSurface),
      // Title
      titleLarge:  TextStyle(fontFamily: _fontFamily, fontSize: 22, fontWeight: FontWeight.w600, color: onSurface),
      titleMedium: TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: onSurface, letterSpacing: 0.15),
      titleSmall:  TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: onSurface, letterSpacing: 0.1),
      // Body
      bodyLarge:   TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w400, color: onSurface, letterSpacing: 0.5),
      bodyMedium:  TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: onSurface, letterSpacing: 0.25),
      bodySmall:   TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: onSurfaceVar, letterSpacing: 0.4),
      // Label
      labelLarge:  TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: onSurface, letterSpacing: 0.1),
      labelMedium: TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: onSurface, letterSpacing: 0.5),
      labelSmall:  TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w500, color: onSurfaceVar, letterSpacing: 0.5),
    );
  }

  // ─── LIGHT THEME ──────────────────────────────────────────────────────────

  static ThemeData get light {
    final cs = _lightColorScheme;
    return ThemeData(
      useMaterial3:   true,
      colorScheme:    cs,
      fontFamily:     _fontFamily,
      textTheme:      _buildTextTheme(AppColors.lightOnSurface, AppColors.lightOnSurfaceVar),
      scaffoldBackgroundColor: AppColors.lightBackground,
      brightness:     Brightness.light,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor:    AppColors.lightSurface,
        foregroundColor:    AppColors.lightOnSurface,
        elevation:          0,
        scrolledUnderElevation: 1,
        centerTitle:        false,
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize:   18,
          fontWeight: FontWeight.w600,
          color:      AppColors.lightOnSurface,
        ),
        iconTheme: const IconThemeData(color: AppColors.lightOnSurface),
        surfaceTintColor: Colors.transparent,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:      AppColors.lightSurface,
        selectedItemColor:    AppColors.primary,
        unselectedItemColor:  AppColors.lightOnSurfaceVar,
        type:                 BottomNavigationBarType.fixed,
        elevation:            8,
        selectedLabelStyle:   const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400),
      ),

      // Navigation Bar (M3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:        AppColors.lightSurface,
        indicatorColor:         AppColors.primaryAlpha20,
        iconTheme:              WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.lightOnSurfaceVar, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary);
          }
          return const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.lightOnSurfaceVar);
        }),
        elevation: 8,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:   AppColors.primary,
          foregroundColor:   Colors.white,
          disabledBackgroundColor: AppColors.lightOutline,
          disabledForegroundColor: AppColors.lightOnSurfaceVar,
          elevation:         0,
          shadowColor:       Colors.transparent,
          padding:           const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:             RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:         const TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side:            const BorderSide(color: AppColors.primary, width: 1.5),
          padding:         const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:       const TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding:         const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:       const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor:  AppColors.primary,
        foregroundColor:  Colors.white,
        elevation:        4,
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),

      // Input / TextField
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   AppColors.lightSurfaceVar,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.lightOutline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.lightOutline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.danger, width: 2),
        ),
        hintStyle:  const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.lightOnSurfaceVar),
        labelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.lightOnSurfaceVar),
        errorStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.danger),
        prefixIconColor: AppColors.lightOnSurfaceVar,
        suffixIconColor: AppColors.lightOnSurfaceVar,
      ),

      // Card
      cardTheme: CardThemeData(
        color:        AppColors.lightSurface,
        elevation:    0,
        shadowColor:  Colors.transparent,
        shape:        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:         const BorderSide(color: AppColors.lightOutlineVar, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor:      AppColors.lightSurfaceVar,
        selectedColor:        AppColors.primaryAlpha20,
        disabledColor:        AppColors.lightOutlineVar,
        labelStyle:           const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.lightOnSurface),
        secondaryLabelStyle:  const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary),
        padding:              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape:                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side:                 const BorderSide(color: AppColors.lightOutline, width: 1),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor:  AppColors.lightSurface,
        elevation:        8,
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle:   const TextStyle(fontFamily: _fontFamily, fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.lightOnSurface),
        contentTextStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.lightOnSurfaceVar),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor:  AppColors.navy,
        contentTextStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white),
        actionTextColor:  AppColors.primary,
        behavior:         SnackBarBehavior.floating,
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation:        4,
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:       AppColors.lightSurface,
        modalBackgroundColor:  AppColors.lightSurface,
        elevation:             8,
        modalElevation:        16,
        shape:                 RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color:     AppColors.lightOutlineVar,
        thickness: 1,
        space:     1,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.lightOutline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryAlpha20;
          return AppColors.lightOutlineVar;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side:       const BorderSide(color: AppColors.lightOutline, width: 2),
        shape:      RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.lightOnSurfaceVar;
        }),
      ),

      // Tab Bar
      tabBarTheme: const TabBarThemeData(
        labelColor:         AppColors.primary,
        unselectedLabelColor: AppColors.lightOnSurfaceVar,
        indicatorColor:     AppColors.primary,
        indicatorSize:      TabBarIndicatorSize.tab,
        labelStyle:         TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400),
        dividerColor:       AppColors.lightOutlineVar,
      ),

      // List Tile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor:      AppColors.lightOnSurfaceVar,
        titleTextStyle: TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.lightOnSurface),
        subtitleTextStyle: TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.lightOnSurfaceVar),
        shape:          RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),

      // Icon
      iconTheme: const IconThemeData(color: AppColors.lightOnSurface, size: 24),
      primaryIconTheme: const IconThemeData(color: Colors.white, size: 24),
    );
  }

  // ─── DARK THEME ───────────────────────────────────────────────────────────

  static ThemeData get dark {
    final cs = _darkColorScheme;
    return ThemeData(
      useMaterial3:   true,
      colorScheme:    cs,
      fontFamily:     _fontFamily,
      textTheme:      _buildTextTheme(AppColors.darkOnSurface, AppColors.darkOnSurfaceVar),
      scaffoldBackgroundColor: AppColors.darkBackground,
      brightness:     Brightness.dark,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor:    AppColors.darkSurface,
        foregroundColor:    AppColors.darkOnSurface,
        elevation:          0,
        scrolledUnderElevation: 1,
        centerTitle:        false,
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize:   18,
          fontWeight: FontWeight.w600,
          color:      AppColors.darkOnSurface,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkOnSurface),
        surfaceTintColor: Colors.transparent,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:      AppColors.darkSurface,
        selectedItemColor:    AppColors.primary,
        unselectedItemColor:  AppColors.darkOnSurfaceVar,
        type:                 BottomNavigationBarType.fixed,
        elevation:            8,
        selectedLabelStyle:   const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400),
      ),

      // Navigation Bar (M3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:  AppColors.darkSurface,
        indicatorColor:   AppColors.primaryAlpha20,
        iconTheme:        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.darkOnSurfaceVar, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary);
          }
          return const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.darkOnSurfaceVar);
        }),
        elevation: 8,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:   AppColors.primary,
          foregroundColor:   Colors.white,
          disabledBackgroundColor: AppColors.darkSurfaceVar,
          disabledForegroundColor: AppColors.darkOnSurfaceVar,
          elevation:         0,
          shadowColor:       Colors.transparent,
          padding:           const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:             RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:         const TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side:            const BorderSide(color: AppColors.primary, width: 1.5),
          padding:         const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:       const TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding:         const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:       const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor:  AppColors.primary,
        foregroundColor:  Colors.white,
        elevation:        4,
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),

      // Input / TextField
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   AppColors.darkSurfaceVar,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.darkOutline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.darkOutline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.danger, width: 2),
        ),
        hintStyle:  const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.darkOnSurfaceVar),
        labelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.darkOnSurfaceVar),
        errorStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.danger),
        prefixIconColor: AppColors.darkOnSurfaceVar,
        suffixIconColor: AppColors.darkOnSurfaceVar,
      ),

      // Card
      cardTheme: CardThemeData(
        color:       AppColors.darkSurface,
        elevation:   0,
        shadowColor: Colors.transparent,
        shape:       RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:         const BorderSide(color: AppColors.darkOutlineVar, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor:      AppColors.darkSurfaceVar,
        selectedColor:        AppColors.primaryAlpha20,
        disabledColor:        AppColors.darkOutline,
        labelStyle:           const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.darkOnSurface),
        secondaryLabelStyle:  const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary),
        padding:              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape:                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side:                 const BorderSide(color: AppColors.darkOutline, width: 1),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor:  AppColors.darkSurface,
        elevation:        8,
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle:   const TextStyle(fontFamily: _fontFamily, fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkOnSurface),
        contentTextStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.darkOnSurfaceVar),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor:  AppColors.darkSurfaceVar,
        contentTextStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.darkOnSurface),
        actionTextColor:  AppColors.primary,
        behavior:         SnackBarBehavior.floating,
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation:        4,
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:       AppColors.darkSurface,
        modalBackgroundColor:  AppColors.darkSurface,
        elevation:             8,
        modalElevation:        16,
        shape:                 RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color:     AppColors.darkOutlineVar,
        thickness: 1,
        space:     1,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.darkOutline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryAlpha20;
          return AppColors.darkSurfaceVar;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side:       const BorderSide(color: AppColors.darkOutline, width: 2),
        shape:      RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.darkOnSurfaceVar;
        }),
      ),

      // Tab Bar
      tabBarTheme: const TabBarThemeData(
        labelColor:           AppColors.primary,
        unselectedLabelColor: AppColors.darkOnSurfaceVar,
        indicatorColor:       AppColors.primary,
        indicatorSize:        TabBarIndicatorSize.tab,
        labelStyle:           TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400),
        dividerColor:         AppColors.darkOutlineVar,
      ),

      // List Tile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor:      AppColors.darkOnSurfaceVar,
        titleTextStyle: TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.darkOnSurface),
        subtitleTextStyle: TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.darkOnSurfaceVar),
        shape:          RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),

      // Icon
      iconTheme: const IconThemeData(color: AppColors.darkOnSurface, size: 24),
      primaryIconTheme: const IconThemeData(color: Colors.white, size: 24),
    );
  }
}
