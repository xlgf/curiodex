import 'package:flutter/material.dart';

TextStyle customFontStyle({
  double fontSize = 16.0,
  Color color = Colors.black,
  FontWeight fontWeight = FontWeight.normal,
}) {
  return TextStyle(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    fontFamily: 'primary', // Replace with your custom font family
  );
}