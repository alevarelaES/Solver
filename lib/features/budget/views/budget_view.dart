import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';

class BudgetView extends StatelessWidget {
  const BudgetView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Budget',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 24),
      ),
    );
  }
}
