import 'package:flutter/material.dart';
import 'package:solver/core/constants/group_colors.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';

/// Pill-shaped badge displaying a transaction group label.
/// Color is derived centrally from [GroupColors.forGroup] — never hardcoded.
class GroupBadge extends StatelessWidget {
  final String label;

  /// Optional color override. If null, resolved via [GroupColors.forGroup].
  final Color? color;

  const GroupBadge({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? GroupColors.forGroup(label);

    return PremiumCardBase(
      variant: PremiumCardVariant.chip,
      overrideSurface: resolved.withAlpha(28),
      overrideBorder: resolved.withAlpha(70),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: resolved,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
