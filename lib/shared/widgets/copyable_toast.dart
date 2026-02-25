import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solver/core/theme/app_theme.dart';

/// Shows a copyable SnackBar overlay with [message].
/// Tapping the Copy button copies [message] (or [copyText] if provided)
/// to the clipboard.
void showCopyableToast(
  BuildContext context, {
  required String message,
  String? copyText,
  Color? iconColor,
  IconData icon = Icons.error_outline_rounded,
  Duration duration = const Duration(seconds: 8),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r12),
      ),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor ?? AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: 'Copier',
        onPressed: () {
          Clipboard.setData(ClipboardData(text: copyText ?? message));
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Copié !'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.r12),
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// A compact banner widget that shows an error with a copy button.
/// Use inside any Column/ListView when you want an inline error display.
class CopyableErrorBanner extends StatelessWidget {
  final String message;
  final String? copyText;
  final VoidCallback? onDismiss;

  const CopyableErrorBanner({
    super.key,
    required this.message,
    this.copyText,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Copier l\'erreur',
            child: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              color: AppColors.danger,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: copyText ?? message));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Erreur copiée dans le presse-papiers'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                    ),
                  ),
                );
              },
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              color: AppColors.textSecondary,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
