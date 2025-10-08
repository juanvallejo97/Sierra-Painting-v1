import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme appTextTheme(Brightness b) =>
    GoogleFonts.interTextTheme(ThemeData(brightness: b).textTheme);
