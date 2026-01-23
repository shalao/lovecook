import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Supported locales for the app
const supportedLocales = [
  Locale('zh', 'CN'), // Chinese (Simplified)
  Locale('en', 'US'), // English
];

/// Provider for the current locale
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

/// Notifier for managing the current locale
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(supportedLocales.first);

  void setLocale(Locale locale) {
    if (supportedLocales.contains(locale)) {
      state = locale;
    }
  }

  void setLocaleByCode(String languageCode) {
    final locale = supportedLocales.firstWhere(
      (l) => l.languageCode == languageCode,
      orElse: () => supportedLocales.first,
    );
    state = locale;
  }
}
