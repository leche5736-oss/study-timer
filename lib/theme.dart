import 'package:flutter/material.dart';

/// 설정에서 고르는 색 테마. 강조색과 휴식·집중 화면 색이 함께 바뀝니다.
class ColorTheme {
  final String id;
  final String label;
  final Color accent; // 시작 버튼, 고른 항목
  final Color soft; // 연한 색 (숨쉬기 원 등)
  final Color restBg; // 휴식 화면 바탕
  final Color night; // 집중 화면 바탕
  final Color nightRaised; // 집중 화면 버튼, 입력 칸
  final Color dim; // 집중 화면 시간, 글자
  final Color nightFaint; // 집중 화면 안내 글자
  const ColorTheme({
    required this.id,
    required this.label,
    required this.accent,
    required this.soft,
    required this.restBg,
    required this.night,
    required this.nightRaised,
    required this.dim,
    required this.nightFaint,
  });
}

const colorThemes = [
  ColorTheme(
    id: 'blue',
    label: '차분한 파랑',
    accent: Color(0xFF7D9AC4),
    soft: Color(0xFFE0E7F1),
    restBg: Color(0xFFF5F7FA),
    night: Color(0xFF161B24),
    nightRaised: Color(0xFF222936),
    dim: Color(0xFF8F9DB4),
    nightFaint: Color(0xFF4C5568),
  ),
  ColorTheme(
    id: 'sage',
    label: '세이지 그린',
    accent: Color(0xFF86A895),
    soft: Color(0xFFE2EBE5),
    restBg: Color(0xFFF5F8F6),
    night: Color(0xFF171D1A),
    nightRaised: Color(0xFF232B27),
    dim: Color(0xFF93A99C),
    nightFaint: Color(0xFF4E5A53),
  ),
  ColorTheme(
    id: 'lavender',
    label: '라벤더',
    accent: Color(0xFF9B91C2),
    soft: Color(0xFFE7E4F2),
    restBg: Color(0xFFF7F6FA),
    night: Color(0xFF1A1824),
    nightRaised: Color(0xFF272435),
    dim: Color(0xFFA19BB9),
    nightFaint: Color(0xFF555068),
  ),
  ColorTheme(
    id: 'rose',
    label: '로즈',
    accent: Color(0xFFC4949A),
    soft: Color(0xFFF2E5E7),
    restBg: Color(0xFFFAF6F6),
    night: Color(0xFF221A1B),
    nightRaised: Color(0xFF322627),
    dim: Color(0xFFB59DA0),
    nightFaint: Color(0xFF65524F),
  ),
];

ColorTheme colorThemeById(String id) =>
    colorThemes.firstWhere((t) => t.id == id, orElse: () => colorThemes.first);

/// 앱 전체 색. 흰 바탕에 차분한 강조색(기본 파랑), 글자는 짙은 남색, 보조 정보는 회색.
/// 강조색과 휴식·집중 화면 색은 설정의 색 테마([current])를 따릅니다.
class AppColors {
  static ColorTheme current = colorThemes.first;

  static const ink = Color(0xFF2A3345); // 글자
  static const grey = Color(0xFF8D95A3); // 보조 글자
  static const faint = Color(0xFFC8CED8); // 고르지 않은 항목
  static const fill = Color(0xFFF2F4F7); // 입력 칸, 카드 바탕
  static const line = Color(0xFFE4E8EE); // 구분선

  static Color get accent => current.accent;
  static Color get soft => current.soft;
  static Color get restBg => current.restBg;
  static Color get night => current.night;
  static Color get nightRaised => current.nightRaised;
  static Color get dim => current.dim;
  static Color get nightFaint => current.nightFaint;
}

ThemeData appTheme([ColorTheme? colors]) {
  AppColors.current = colors ?? colorThemes.first;
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent).copyWith(
    primary: AppColors.accent,
    onSurface: AppColors.ink,
    onPrimary: Colors.white,
    surface: Colors.white,
    surfaceContainerHighest: AppColors.fill,
    outlineVariant: AppColors.line,
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    splashFactory: NoSplash.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      actionsIconTheme: IconThemeData(color: AppColors.grey),
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 60,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          color: s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.grey,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.faint,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
    cardTheme: CardThemeData(
      color: AppColors.fill,
      elevation: 0,
      shape: rounded,
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: rounded,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        shape: rounded,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.ink),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.fill,
      selectedColor: AppColors.accent,
      labelStyle: TextStyle(
        color: WidgetStateColor.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.white : AppColors.ink,
        ),
      ),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accent : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.white : AppColors.ink,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.grey),
  );
}

ThemeData? _cached;
String? _cachedId;

/// 색 테마 id에 맞는 ThemeData. 같은 테마면 만들어 둔 것을 다시 씁니다.
ThemeData themeFor(String id) {
  final colors = colorThemeById(id);
  if (_cachedId != colors.id) {
    _cached = appTheme(colors);
    _cachedId = colors.id;
  }
  return _cached!;
}
