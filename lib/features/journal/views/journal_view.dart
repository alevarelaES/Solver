import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';

class JournalView extends StatelessWidget {
  const JournalView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Journal',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 24),
      ),
    );
  }
}
