import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../../providers/language_provider.dart';
import '../../providers/settings_provider.dart';

/// 첫 실행: 언어 선택 (한국어를 모르는 사용자가 처음부터 자기 언어로 시작)
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.health_and_safety, color: AppColors.navy, size: 34),
                  ),
                  const SizedBox(height: 20),
                  Text(lang.t('welcome_title'),
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(lang.t('welcome_sub'), style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
                  const SizedBox(height: 24),
                  Text(lang.t('choose_language'),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: AppStrings.languageNames.entries.map((e) {
                        final selected = lang.currentLang == e.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: selected ? AppColors.navy.withValues(alpha: 0.08) : const Color(0xFFF6F7FA),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: lang.isLoading ? null : () => lang.setLanguage(e.key),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(children: [
                                  Text(AppStrings.languageFlags[e.key] ?? '', style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(e.value,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                                            color: AppColors.navy)),
                                  ),
                                  if (selected) const Icon(Icons.check_circle, color: AppColors.navy),
                                ]),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: lang.isLoading
                              ? null
                              : () {
                                  context.read<SettingsProvider>().syncLanguage(lang.currentLang);
                                  lang.completeOnboarding();
                                },
                          child: lang.isLoading
                              ? const SizedBox(
                                  width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(lang.t('continue'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
