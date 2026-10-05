import 'package:flutter/material.dart';

/// 앱 공통 색상 (기존 화면들에 흩어져 있던 값을 한곳에 모음)
class AppColors {
  static const navy = Color(0xFF1B2F6E); // 기존 kNavy
  static const navyDark = Color(0xFF1A2744); // 119·안전가이드 헤더
  static const background = Color(0xFFF2F4F8);
  static const card = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const textMuted = Color(0xFF718096);
  static const textFaint = Color(0xFF9AA5B4);
  static const danger = Color(0xFFC0392B);
  static const dangerText = Color(0xFFB12B2B);
  static const dangerBg = Color(0xFFFFEEEE);
  static const safe = Color(0xFF2E7D32);
  static const safeBg = Color(0xFFE8F5E9);
  static const warningBg = Color(0xFFFFF7E8);
  static const warningBorder = Color(0xFFFFD89C);
  static const emergencyRed = Color(0xFFDC2626);
}

/// 재난 유형별 색상·아이콘·번역 키 (서버 alert_categories 와 동일한 코드)
class CategoryStyle {
  final String code;
  final String labelKey;
  final Color color;
  final IconData icon;
  const CategoryStyle(this.code, this.labelKey, this.color, this.icon);

  static const all = CategoryStyle('ALL', 'filter_all', AppColors.navy, Icons.apps);
  static const list = <CategoryStyle>[
    CategoryStyle('RAIN', 'filter_rain', Color(0xFF1565C0), Icons.umbrella),
    CategoryStyle('FLOOD', 'filter_flood', Color(0xFF0277BD), Icons.water_drop_outlined),
    CategoryStyle('EARTHQUAKE', 'filter_earthquake', Color(0xFFBF360C), Icons.show_chart),
    CategoryStyle('FIRE', 'filter_fire', Color(0xFFE53935), Icons.local_fire_department_outlined),
    CategoryStyle('SNOW', 'filter_snow', Color(0xFF5C6BC0), Icons.ac_unit),
    CategoryStyle('LANDSLIDE', 'filter_landslide', Color(0xFF6D4C41), Icons.terrain),
    CategoryStyle('HEAT', 'filter_heat', Color(0xFFF57C00), Icons.wb_sunny_outlined),
    CategoryStyle('COLD', 'filter_cold', Color(0xFF00838F), Icons.thermostat),
    CategoryStyle('OTHER', 'filter_other', Color(0xFF546E7A), Icons.campaign_outlined),
  ];

  static CategoryStyle of(String code) =>
      list.firstWhere((c) => c.code == code, orElse: () => list.last);
}

/// 심각도 (재난문자 3단계 + 정보)
class SeverityStyle {
  static String labelKey(String code) {
    switch (code) {
      case 'CRITICAL':
        return 'severity_critical';
      case 'HIGH':
        return 'severity_high';
      case 'MEDIUM':
        return 'severity_medium';
      default:
        return 'severity_low';
    }
  }

  static Color color(String code) {
    switch (code) {
      case 'CRITICAL':
        return const Color(0xFFB71C1C);
      case 'HIGH':
        return const Color(0xFFE65100);
      case 'MEDIUM':
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF546E7A);
    }
  }
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.navy),
    scaffoldBackgroundColor: AppColors.background,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

Color hexColor(String hex, {Color fallback = AppColors.textFaint}) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return fallback;
  }
}
