import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';

class ScheduleView extends StatelessWidget {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Échéancier',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 24),
      ),
    );
  }
}
