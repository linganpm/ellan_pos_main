import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FontUtility {
  static TextStyle get heading => GoogleFonts.roboto(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      );

  static TextStyle get subheading => GoogleFonts.roboto(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
      );

  static TextStyle get body => GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: Colors.black87,
      );

  static TextStyle get button => GoogleFonts.roboto(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );
}
