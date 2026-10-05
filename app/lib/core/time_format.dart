import '../providers/language_provider.dart';

/// "5분 전 / 5 min ago" 처럼 현재 언어로 상대 시간 표시 (기존: 영어 고정)
String timeAgo(DateTime? time, LanguageProvider lang, {DateTime? now}) {
  if (time == null) return '';
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return lang.t('time_just_now');
  if (diff.inMinutes < 60) return lang.tf('time_min_ago', {'n': diff.inMinutes});
  if (diff.inHours < 24) return lang.tf('time_hour_ago', {'n': diff.inHours});
  if (diff.inDays == 1) return lang.t('time_yesterday');
  return lang.tf('time_days_ago', {'n': diff.inDays});
}

/// 2026-10-05 14:05 형식 (현지 시각)
String formatDateTime(DateTime? t) {
  if (t == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}
