import 'package:flutter/material.dart';

extension BuildContextX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
