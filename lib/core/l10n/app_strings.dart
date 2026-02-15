/// Centralized strings for the app — facilitates future i18n migration.
/// To switch language: replace values here or plug into flutter_localizations.
class AppStrings {
  const AppStrings._();

  static const dashboard = _Dashboard();
  static const common = _Common();
}

class _Dashboard {
  const _Dashboard();

  // Balance card
  String get myBalance => 'Mon Solde';
  String get endOfMonth => 'Fin de mois';
  String get transfer => 'Transférer';
  String get received => 'Reçu';

  // KPI cards
  String get income => 'Revenus';
  String get expense => 'Dépenses';
  String get savings => 'Épargne';
  String get thisMonth => 'Ce mois';

  // Financial overview
  String get financialOverview => 'Aperçu Financier';
  String get thisYear => 'Cette année';
  String get lastYear => 'Année dernière';

  // Expense breakdown
  String get expenseBreakdown => 'Répartition Dépenses';
  String get addNew => '+ Ajouter';

  // My cards
  String get myCards => 'Mes Cartes';
  String get cardNumber => 'Numéro de carte';
  String get validFrom => 'VALIDE DÈS';
  String get validUntil => 'VALIDE JUSQU\'À';

  // Recent activities
  String get recentActivities => 'Activité Récente';
  String get description => 'Description';
  String get date => 'Date';
  String get amount => 'Montant';
  String get search => 'Rechercher';
  String get filter => 'Filtrer';
  String get filterAll => 'Toutes';
  String get filterIncome => 'Revenus';
  String get filterExpense => 'Dépenses';
  String get noTransactions => 'Aucune transaction récente';

  // Spending limit
  String get monthlySpendingLimit => 'Limite Mensuelle';
  String get setLimit => 'Définir limite';

  // Upcoming banner
  String upcomingBanner(int count) =>
      '$count échéance${count > 1 ? 's' : ''} dans les 30 prochains jours';

  // Promo cards
  String get trySolverAi => 'Essayer Solver AI';
  String get solverAiDescription => '1 mois d\'essai gratuit Solver AI';
  String get tryNow => 'Essayer';
  String get upgradeToPro => 'Passer à Pro !';
  String get upgradeDescription => 'Débloquez toutes les fonctionnalités !';
  String get upgradeNow => 'Passer Pro';

  // Year nav
  String get year => 'Année';

  // Welcome
  String welcomeBack(String name) => 'Bienvenue, $name !';

  // Empty states
  String get noAccounts =>
      'Aucun compte créé.\nCommencez par ajouter un compte.';
  String get noExpenses => 'Aucune dépense ce mois';

  // FAB
  String get newAccount => 'Nouveau compte';
  String get transaction => 'Transaction';

  // Loading & errors
  String get loadingError => 'Erreur de chargement';
}

class _Common {
  const _Common();

  String get appName => 'Solver';
  String get cancel => 'Annuler';
  String get save => 'Enregistrer';
  String get delete => 'Supprimer';
  String get edit => 'Modifier';
  String get close => 'Fermer';

  // Months
  List<String> get monthsShort => const [
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Jun',
    'Jul',
    'Aoû',
    'Sep',
    'Oct',
    'Nov',
    'Déc',
  ];
}
