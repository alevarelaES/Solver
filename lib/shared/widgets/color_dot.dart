import 'package:flutter/material.dart';

class ColorDot extends StatelessWidget {
  final Color color;
  final double size;

  const ColorDot({
    super.key,
    required this.color,
    this.size = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
