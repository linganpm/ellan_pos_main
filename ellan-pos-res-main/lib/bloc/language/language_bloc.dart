import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'language_event.dart';
import 'language_state.dart';

class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  static const localePreferenceKey = 'posPreferredLocale';

  LanguageBloc({SharedPreferences? prefs, Locale? initialLocale})
    : _prefs = prefs,
      super(LanguageState(initialLocale ?? const Locale('en'))) {
    on<ChangeLanguageEvent>(_onChangeLanguage);
  }

  final SharedPreferences? _prefs;

  factory LanguageBloc.fromPrefs(SharedPreferences prefs) {
    final saved = (prefs.getString(localePreferenceKey) ?? '').trim();
    final initial = saved == 'ta' ? const Locale('ta') : const Locale('en');
    return LanguageBloc(prefs: prefs, initialLocale: initial);
  }

  Future<void> _onChangeLanguage(
    ChangeLanguageEvent event,
    Emitter<LanguageState> emit,
  ) async {
    emit(LanguageState(event.locale));
    final code = event.locale.languageCode;
    if (code == 'en' || code == 'ta') {
      await _prefs?.setString(localePreferenceKey, code);
    }
  }
}
