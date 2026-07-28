import 'package:flutter/material.dart';

abstract class LanguageEvent {}

class ChangeLanguageEvent extends LanguageEvent {
  final Locale locale;
  ChangeLanguageEvent(this.locale);
}
