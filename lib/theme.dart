import 'package:flutter/material.dart';

/// 앱 전체 색과 모양. 흰 바탕에 파스텔 블루, 글자는 짙은 남색, 보조 정보는 회색.
/// 집중 화면만 어두운 남색 바탕입니다 (focus_screen.dart).
class AppColors {
  static const ink = Color(0xFF2A3345); // 글자
  static const accent = Color(0xFF7D9AC4); // 시작 버튼, 고른 항목
  static const soft = Color(0xFFE0E7F1); // 연한 파랑 (숨쉬기 원 등)
  static const grey = Color(0xFF8D95A3); // 보조 글자
  static const faint = Color(0xFFC8CED8); // 고르지 않은 항목
  static const fill = Color(0xFFF2F4F7); // 입력 칸, 카드 바탕
  static const line = Color(0xFFE4E8EE); // 구분선
  static const restBg = Color(0xFFF5F7FA); // 휴식 화면 바탕

  // 집중 화면 (어두운 남색)
  static const night = Color(0xFF161B24);
  static const nightRaised = Color(0xFF222936); // 버튼, 입력 칸
  static const dim = Color(0xFF8F9DB4); // 시간, 글자
  static const nightFaint = Color(0xFF4C5568); // 안내 글자
}

ThemeData appTheme() {
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
