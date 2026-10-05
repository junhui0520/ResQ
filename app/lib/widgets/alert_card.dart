import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/time_format.dart';
import '../providers/language_provider.dart';
import '../services/alert_service.dart';

/// 알림 카드 (홈·알림 목록 공용 — 기존 두 화면의 _AlertCard 디자인을 합침)
class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final LanguageProvider lang;
  final VoidCallback? onTap;

  const AlertCard({super.key, required this.alert, required this.lang, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = CategoryStyle.of(alert.categoryCode);
    final borderColor = hexColor(alert.colorHex, fallback: cat.color);
    final regionLabel = lang.t('region_${alert.regionCode.toLowerCase()}');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: borderColor, width: 4)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(cat.icon, size: 18, color: borderColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy, height: 1.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(timeAgo(alert.issuedAtLocal, lang),
                      style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SeverityBadge(code: alert.severityCode, lang: lang),
                  _Pill(
                    text: lang.t(cat.labelKey),
                    bg: borderColor.withValues(alpha: 0.12),
                    fg: borderColor,
                  ),
                  _Pill(
                    text: alert.isActive ? lang.t('alert_active') : lang.t('alert_resolved'),
                    bg: alert.isActive ? AppColors.dangerBg : AppColors.safeBg,
                    fg: alert.isActive ? AppColors.dangerText : AppColors.safe,
                  ),
                  if (alert.isDemo) const _Pill(text: 'DEMO', bg: Color(0xFFEDE7F6), fg: Color(0xFF5E35B1)),
                  Text(regionLabel, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              if (alert.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  alert.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568), height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SeverityBadge extends StatelessWidget {
  final String code;
  final LanguageProvider lang;
  const SeverityBadge({super.key, required this.code, required this.lang});

  @override
  Widget build(BuildContext context) {
    final color = SeverityStyle.color(code);
    return _Pill(text: lang.t(SeverityStyle.labelKey(code)), bg: color, fg: Colors.white);
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Pill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
