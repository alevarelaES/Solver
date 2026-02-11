import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';

class AnalysisView extends StatelessWidget {
  const AnalysisView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Analyse',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 24),
      ),
    );
  }
}
