part of 'journal_view.dart';

class _JournalHeader extends ConsumerWidget {
  final bool isMobile;
  const _JournalHeader({required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPageHeader(
      title: 'Journal des Transactions',
      subtitle: 'Suivre les transactions, puis ouvrir le detail au clic.',
      trailing: isMobile
          ? _AddEntryButton(compact: true)
          : SizedBox(
              width: 640,
              child: Row(
                children: [
                  const Expanded(child: _SearchBar()),
                  const SizedBox(width: AppSpacing.md),
                  _AddEntryButton(compact: false),
                ],
              ),
            ),
      bottom: isMobile ? const _SearchBar() : null,
    );
  }
}

class _SearchBar extends ConsumerWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextField(
      onChanged: (v) {
        ref.read(journalSearchProvider.notifier).state = v;
      },
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: AppInputStyles.search(
        hintText: 'Rechercher une transaction...',
        suffixIcon: Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderSubtle),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Text(
            'K',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddEntryButton extends ConsumerWidget {
  final bool compact;
  const _AddEntryButton({required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      onPressed: () => showTransactionFormModal(context, ref),
      icon: const Icon(Icons.add, color: Colors.white, size: 16),
      label: Text(compact ? 'Ajouter' : 'Nouvelle ecriture'),
    );
  }
}

