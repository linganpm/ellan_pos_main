import 'package:flutter/material.dart';

class FontUtility {
  static TextStyle get heading => const TextStyle(
    fontFamily: 'Roboto',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  static TextStyle get subheading => const TextStyle(
    fontFamily: 'Roboto',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: Colors.black87,
  );

  static TextStyle get body => const TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: Colors.black87,
  );

  static TextStyle get button => const TextStyle(
    fontFamily: 'Roboto',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}