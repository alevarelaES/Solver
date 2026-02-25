/// Centralized strings for the app — facilitates future i18n migration.
/// To switch language: replace values here or plug into flutter_localizations.
class AppStrings {
  const AppStrings._();

  static const dashboard = _Dashboard();
  static const common = _Common();
  static const nav = _Nav();
  static const journal = _Journal();
  static const budget = _Budget();
  static const goals = _Goals();
  static const schedule = _Schedule();
  static const spreadsheet = _Spreadsheet();
  static const analysis = _Analysis();
  static const portfolio = _Portfolio();
  static const auth = _Auth();
  static const forms = _Forms();
  static const ui = _UI();
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
  String get recentActivities => 'Transactions recentes';
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

  // Page header
  String get dashboardTitle => 'Tableau de bord';
  String get dashboardSubtitle => 'Suivi global de vos finances en temps réel.';

  // Balance card
  String get monthlySpendingRatio => 'Dépenses du mois';

  // KPI cards
  String get totalObjectives => 'Total objectifs';

  // Pending invoices
  String get pendingInvoices => 'Factures à traiter';
  String get showAll => 'Tout afficher';
  String get manualOnly => 'Manuelles seulement';
  String get pendingInvoicesHint =>
      'Tout afficher inclut les factures manuelles et automatiques.';
  String overdueAlert(int count) =>
      'ALERTE: $count facture${count > 1 ? 's' : ''} en retard';
  String todayAlert(int count) =>
      'Attention: $count facture${count > 1 ? 's' : ''} échéance aujourd\'hui';
  String get invoicesLoadError => 'Impossible de charger les factures';
  String get noPending => 'Aucune facture en attente';
  String get nothingToDo => 'Rien à traiter pour le moment';
  String invoicesPriority(int urgent, int total) =>
      '$urgent prioritaire${urgent > 1 ? 's' : ''} sur $total facture${total > 1 ? 's' : ''}';
  String get settleInvoice => 'Régler';
  String get openTransactions => 'Ouvrir transactions';
  String get settleError => 'Impossible de régler la facture.';
  String get autoDebit => 'Prélèvement auto';
  String get manualInvoice => 'Facture manuelle';
  String get statusPending => 'À payer';
  String get statusPaid => 'Payée';

  // Financial overview range
  String get rangeMonth => 'Mois';
  String get rangeQuarter => 'Trimestre';
  String get rangeYear => 'Année';

  // Expense breakdown detail
  String get expenseBreakdownDetail => 'Détails dépenses du mois';

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
  String get confirm => 'Confirmer';
  String get loading => 'Chargement...';
  String get error => 'Erreur';
  String get retry => 'Réessayer';
  String get yes => 'Oui';
  String get no => 'Non';

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

  List<String> get monthsFull => const [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];
}

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------
class _Nav {
  const _Nav();

  String get dashboard => 'Dashboard';
  String get activity => 'Transactions';
  String get journal => 'Journal';
  String get schedule => 'Échéancier';
  String get budget => 'Budget';
  String get goals => 'Objectifs';
  String get portfolio => 'Portfolio';
  String get analysis => 'Analyse';
  String get spreadsheet => 'Tableur';
  String get more => 'Plus';
}

// ---------------------------------------------------------------------------
// Journal
// ---------------------------------------------------------------------------
class _Journal {
  const _Journal();

  String get title => 'Journal';
  String get titleFull => 'Journal des Transactions';
  String get subtitle => 'Historique de toutes vos transactions';
  String get subtitleFull =>
      'Suivre les transactions, puis ouvrir le détail au clic.';
  String get noTransactions => 'Aucune transaction ce mois';
  String get noTransactionsFilter => 'Aucune transaction sur ce filtre';
  String error(Object e) => 'Erreur: $e';

  // Header
  String get searchHint => 'Rechercher une transaction...';
  String get addButton => 'Ajouter';
  String get newEntry => 'Nouvelle écriture';

  // Table headers (display)
  String get colDate => 'DATE';
  String get colTransaction => 'TRANSACTION';
  String get colAccount => 'Compte';
  String get colCategory => 'Catégorie';
  String get colGroup => 'GROUPE';
  String get colDescription => 'DESCRIPTION';
  String get colAmount => 'MONTANT';
  String get colLabel => 'LIBELLÉ';
  String get colStatus => 'Statut';

  // Month/year row totals
  String earned(String amount) => 'Gagné $amount';
  String spent(String amount) => 'Dépensé $amount';

  // Filter chips - year/month
  String get yearPickerTitle => 'Année';
  String get monthPickerTitle => 'Mois';
  String get currentMonth => 'Mois courant';
  String currentMonthLabel(String month) => 'Mois courant ($month)';

  // Filter chips - labels
  String get allLabels => 'Tous libellés';
  String labelFilter(String text) => 'Libellé: $text';
  String get allAccounts => 'Tous les comptes';
  String get allStatuses => 'Tous statuts';
  String get resetLabel => 'Réinitialiser';
  String get hideVoidedLabel => 'Masquer annulées';
  String get showVoidedLabel => 'Afficher annulées';
  String get accountPickerTitle => 'Compte';
  String get all => 'Tous';
  String get statusPickerTitle => 'Statut';
  String get filterToPay => 'À payer';
  String get filterPaidPlural => 'Payées';

  // Date filter labels
  String get allDates => 'Toutes dates';
  String dateExact(String date) => 'Date: $date';
  String dateRange(String from, String to) => 'Du $from au $to';
  String dateFrom(String from) => 'À partir du $from';
  String dateTo(String to) => "Jusqu'au $to";

  // Amount filter labels
  String get allAmounts => 'Tous montants';
  String amountMin(String amount) => '>= $amount';
  String amountMax(String amount) => '<= $amount';

  // Filter dialogs
  String get filterByDate => 'Filtrer par date';
  String get dateMin => 'Date min';
  String get dateMax => 'Date max';
  String get clearFilter => 'Effacer';
  String get clearFilterTooltip => 'Effacer';
  String get applyFilter => 'Appliquer';
  String get filterByLabel => 'Filtrer par libellé';
  String get labelContains => 'Libellé contient...';
  String get filterByAmount => 'Filtrer par montant';
  String get invalidAmount => 'Montant invalide';
  String get amountMaxLtMin => 'Montant max < montant min';
  String get advancedFilters => 'Filtres avancés';
  String get dateRangeLabel => 'Plage de dates';
  String get labelFieldLabel => 'Libellé';
  String get amountFieldLabel => 'Montant';
  String get clearAll => 'Effacer tout';
  String get amountMinHint => 'Min';
  String get amountMaxHint => 'Max';
  String get amountMinLabel => 'Montant min';
  String get amountMaxLabel => 'Montant max';

  // Filters
  String get filtersTitle => 'Filtres';
  String get filterAllStatuses => 'Tous statuts';
  String get filterPaid => 'Payé';
  String get filterPending => 'En attente';
  String get filterAllAmounts => 'Tous montants';
  String get filterAllCategories => 'Toutes catégories';
  String get filterAllAccounts => 'Tous comptes';
  String get filterAllTypes => 'Tous types';
  String get filterIncome => 'Revenus';
  String get filterExpense => 'Dépenses';
  String get filterSearch => 'Rechercher...';
  String get resetFilters => 'Réinitialiser';

  // Status labels
  String get statusPaid => 'Payé';
  String get statusPending => 'En attente';
  String get statusAuto => 'Auto';
  String get statusToPay => 'À payer';
  String get statusAutoUpcoming => 'Auto à venir';

  // Detail panel
  String get detailTitle => 'Détail transaction';
  String get detailAccount => 'Compte';
  String get detailCategory => 'Catégorie';
  String get detailDate => 'Date';
  String get detailAmount => 'Montant';
  String get detailNote => 'Note';
  String get detailStatus => 'Statut';
  String get detailType => 'Type';
  String get detailIncome => 'Revenu';
  String get detailExpense => 'Dépense';
  String get typeAuto => 'Automatique';
  String get typeManual => 'Manuel';
  String transactionRef(String id) => 'Transaction #$id';

  // Detail actions
  String get markAsPaid => 'Marquer comme payée';
  String get confirmAction => 'Confirmer';
  String get editTransaction => 'Modifier la transaction';
  String get actionPay => 'Payer';
  String get actionPayTooltip => 'Marquer payée';
  String get actionEdit => 'Modifier';
  String get actionPrint => 'Imprimer';
  String get actionDelete => 'Supprimer';
  String get amountLabel => 'Montant';
  String amountLabelCode(String code) => 'Montant ($code)';
}

// ---------------------------------------------------------------------------
// Budget
// ---------------------------------------------------------------------------
class _Budget {
  const _Budget();

  String get title => 'Budget';
  String get subtitle => 'Planification mensuelle';
  String get save => 'Sauvegarder le plan';
  String get saving => 'Sauvegarde...';
  String get reload => 'Recharger';
  String get unsavedChanges => 'Modifications non sauvegardées';

  String get step1 => 'Étape 1';
  String get step2 => 'Étape 2';
  String get step3 => 'Étape 3';

  String get basePlan => 'Mon budget mensuel';
  String get modeNet => 'Revenu disponible après dépenses connues';
  String get modeGross => 'Revenu brut (sans déduction de dépenses)';
  String get showGross => 'Afficher le revenu brut';

  String get alreadyAllocated => 'du budget planifié';
  String get autoReserved => 'Prélèvements automatiques';
  String get autoReservedDesc =>
      'Déjà comptés automatiquement – rien à saisir manuellement.';

  String get savingsMonthly => 'Épargne mensuelle';
  String get savingsMonthlyDesc =>
      'Définis un % du revenu disponible pour créer un objectif d\'épargne.';
  String get savingsMonthlyNoIncome =>
      'Définis le revenu disponible du mois pour activer l\'épargne mensuelle.';
  String get goToGoals => 'Objectifs';
  String get createSavings => 'Créer épargne';

  String get noExpenses => 'Budget non défini';
  String get lockedByCommitted =>
      'On a automatiquement mis ce plan au minimum pour ne pas descendre sous le déjà engagé.';

  String copiedFrom(String month, int year) => 'Plan copié depuis $month $year';
  String autoReservedAmount(String amount, String pct) =>
      'Réservé automatiquement : $amount ($pct%)';
  String allowedRange(String name, String min, String max) =>
      'Plage autorisée pour $name: $min - $max';

  // budget_view.dart
  String get subtitleFull =>
      'Planifiez vos allocations mensuelles et suivez vos marges.';
  String errorBudget(Object e) => 'Erreur budget: $e';
  String allocationByGroup(int n) => 'ALLOCATION PAR GROUPE ($n)';
  String get overLimitMsg => 'Budget dépassé';
  String manualPctLabel(String a, String b) => 'Planifié : $a% / $b%';

  // budget_view.summary.part.dart
  String step1Desc(String netRec, String gross, String manual, String auto) =>
      'Suggestion : $netRec (revenu $gross – dépenses fixes $manual – prélèvements $auto)';
  String alreadyDistributed(String amount) => '$amount planifiés';
  String stillFree(String amount) => '$amount disponibles';
  String step2Desc(String capacity, String distributed) =>
      'Planifié : $distributed sur $capacity disponibles';
  String get step2Deficit => ' – dépassement';
  String step3Desc(String available) =>
      'Solde estimé fin de mois : $available';
  String moreOthers(int n) => '+$n autres';

  // budget_view.groups.part.dart
  String paidLabel(String amount) => 'Payées: $amount';
  String pendingLabel(String amount) => 'À payer: $amount';
  String categoriesInfo(int n, bool isFixed) =>
      '$n catégories - ${isFixed ? 'Fixe' : 'Variable/Mixte'}';
  String get amountChipLabel => 'Montant';
  String committedThisMonth(String amount) => 'Dépensé ce mois : $amount';
  String committedPct(String pct) => 'Utilisé : $pct%';
  String get noBudgetPlanned => 'Non planifié';
  String freeRemaining(String amount) => 'Restant : $amount';
  String overdraftEngaged(String amount) => 'Dépassement : $amount';
  String redLabel(String amount) => 'Payé $amount';
  String yellowLabel(String amount) => 'À payer $amount';
  String greenLabel(String amount) => 'Disponible $amount';
  String lockedByCommittedMin(String min) =>
      'Budget verrouillé à $min (dépenses déjà engagées ce mois).';
  String overflowEngaged(String amount) => 'Budget dépassé de $amount';

  // budget_view.logic.part.dart
  String get saveError => 'Erreur de sauvegarde du plan.';
  String get saveErrorServer =>
      'Serveur temporairement indisponible. Réessayez dans quelques secondes.';
  String get totalExceeds => 'Le total dépasse 100%.';
  String get planSaved => 'Plan budget enregistré';
  String get changeMonthTitle => 'Modifier le mois';
  String get unsavedChangesLost =>
      'Des changements non sauvegardés seront perdus. Continuer ?';
  String get continueAction => 'Continuer';
  String get createSavingsGoalTitle => 'Créer une épargne mensuelle';
  String get savingsBudgetDesc =>
      'Le Budget gère les dépenses. L\'épargne est gérée via Objectifs.';
  String get goalNameLabel => 'Nom de l\'objectif';
  String get goalPercentLabel => 'Pourcentage du revenu disponible (%)';
  String get goalHorizonLabel => 'Horizon (mois)';
  String monthlyAmountLabel(String amount, String pct) =>
      'Mensuel: $amount ($pct%)';
  String goalTargetLabel(
    String amount,
    int months,
    String monthName,
    int year,
  ) => 'Objectif cible: $amount sur $months mois (jusqu\'à $monthName $year)';
  String get needPositiveIncome =>
      'Définis d\'abord un revenu disponible positif pour ce mois.';
  String get needPositivePercent => 'Le pourcentage doit être supérieur à 0%.';
  String goalCreated(String name, String amount) =>
      'Objectif "$name" créé ($amount/mois).';
  String get openGoals => 'Ouvrir Objectifs';
  String get createGoalError => 'Erreur de création de l\'objectif.';
  String get defaultGoalName => 'Épargne mensuelle';
}

// ---------------------------------------------------------------------------
// Goals
// ---------------------------------------------------------------------------
class _Goals {
  const _Goals();

  String get title => 'Objectifs';
  String get subtitle => 'Suivez vos objectifs d\'épargne';
  String get createGoal => 'Créer un objectif';
  String get noGoals => 'Aucun objectif créé';

  // Status chips
  String get statusReached => 'Atteint';
  String get statusOnTrack => 'En bonne voie';
  String get statusLate => 'En retard';
  String get statusUrgent => 'Urgent';
  String get statusToPlan => 'À planifier';
  String get statusPaused => 'En pause';
  String get statusOverdue => 'Dépassé';

  // Goal types
  String get typeEmergency => 'Urgence';
  String get typeSavings => 'Épargne';
  String get typeProject => 'Projet';
  String get typeDebt => 'Dette';
  String get typeInvestment => 'Investissement';
  String get typeRetirement => 'Retraite';

  // Labels
  String get targetAmount => 'Montant cible';
  String get currentAmount => 'Capital actuel';
  String get monthlyContribution => 'Contribution mensuelle';
  String get targetDate => 'Date cible';
  String get remainingAmount => 'Reste à épargner';
  String get progressLabel => 'Progression';
  String get monthsRemaining => 'Mois restants';

  String get depositAction => 'Déposer';
  String get withdrawAction => 'Retirer';
  String get editAction => 'Modifier';
  String get deleteAction => 'Supprimer';

  // Recommendation
  String recommendedMonthly(String amount) =>
      'Recommandé pour la date cible: $amount / mois';

  // Type labels (for display)
  String get typeLabelGoal => 'Objectif';
  String get typeLabelDebt => 'Remboursement';

  // Alert labels
  String get alertUrgentSoon => 'Urgent';
  String get alertAttentionSoon => 'Bientôt';
  String get alertUrgentAdjustment => 'Urgent';
  String get alertAttentionAdjust => 'À ajuster';
  String get alertAttentionApproach => 'Approche';
  String get alertAttentionLowRhythm => 'Rythme faible';
  String get alertToPlan => 'À planifier';
  String get alertToAdjust => 'À ajuster';
  String get alertOnTrack => 'En cours';
  String get alertOverdueDeadline => 'Dépassé';

  // Deadline labels
  String achievedDeadline(String date) => 'Cible $date';
  String overdueByDays(int days) => '$days j de retard';
  String get deadlineToday => 'Aujourd\'hui';
  String get deadlineTomorrow => 'Demain';
  String deadlineInDays(int days) => 'Dans $days j';

  // Goal card
  String get completedLabel => 'complété';
  String currentVsTarget(String current, String target) =>
      'Actuel $current / Cible $target';
  String remainingToRepay(String amount) => 'Reste à rembourser $amount';
  String remainingGoal(String amount) => 'Reste $amount';
  String get delayUnknown => 'Retard prévisionnel: indéterminé';
  String delayMonths(int months) => 'Retard prévisionnel: $months mois';
  String get marginUnavailable =>
      'Marge restante après mensualité: indisponible';
  String marginAfterPayment(String amount) =>
      'Marge restante après mensualité: $amount';
  String get monthlyRepayment => 'Mensuel remboursement';
  String get monthlyCurrent => 'Mensuel actuel';
  String get autoPaymentActive => 'Paiement auto actif';
  String get autoDepositActive => 'Dépôt auto actif';
  String autoPaymentDay(int day) => 'Auto le $day de chaque mois';
  String autoDepositDay(int day) => 'Dépôt le $day de chaque mois';
  String recommended(String amount) => 'Recommandé: $amount';
  String monthsRemainingCount(int months) => 'Mois restants: $months';
  String get projectionUnknown => 'Projection: non calculée';
  String projection(String date) => 'Projection: $date';
  String get payment => 'Paiement';
  String get depositWithdraw => 'Dépôt / Retrait';
  String get historyAction => 'Historique';
  String get archiveAction => 'Archiver';
  String get unarchiveAction => 'Désarchiver';

  // Overview panel
  String get panelTitleGoals => 'Tableau de pilotage des objectifs';
  String get panelTitleDebts => 'Pilotage des remboursements';
  String cardCount(int n) => '$n carte${n > 1 ? 's' : ''}';
  String get metricTotalTarget => 'Cible totale';
  String get metricCurrentCapital => 'Capital actuel';
  String get metricAverageProgress => 'Progression moyenne';
  String get metricMonthlyTotal => 'Mensuel cumulé';
  String get metricAlerts => 'Alertes';
  String alertSummary(int overdue, int urgent, int attention) =>
      '$overdue en retard / $urgent urgents / $attention attention';
  String get metricAchieved => 'Atteints';
  String get marginUnavailableMsg =>
      'Marge mensuelle restante: indisponible (ouvre Budget pour initialiser le mois).';
  String monthlyMarginMsg(String amount) =>
      'Marge mensuelle restante après allocations: $amount';
  String get noDebts => 'Aucun remboursement pour le moment.';
  String get noGoalsList => 'Aucun objectif pour le moment.';
  String get panelHeaderTitle => 'OBJECTIFS & REMBOURSEMENTS';
  String get panelHeaderSubtitle =>
      'Trié automatiquement par échéance la plus proche';

  // Section titles
  String get sectionUrgent => 'Urgence';
  String get sectionUrgentDesc => 'Échéance très proche ou dépassée.';
  String get sectionAttention => 'Attention';
  String get sectionAttentionDesc => 'Ajustement conseillé.';
  String get sectionInProgress => 'En cours';
  String get sectionInProgressDesc => '';
  String get sectionAchieved => 'Atteints';
  String get sectionAchievedDesc => '';
  String get newGoalBtn => 'Objectifs';
  String get newDebtBtn => 'Remboursements';

  // Dialog: editor
  String get newGoalTitle => 'Nouvel objectif';
  String get newDebtTitle => 'Nouveau remboursement';
  String get editGoalTitle => 'Modifier objectif';
  String get editDebtTitle => 'Modifier remboursement';
  String targetAmountLabel(String code) => 'Montant cible ($code)';
  String debtAmountLabel(String code) => 'Montant total de la dette ($code)';
  String alreadyRepaidLabel(String code) => 'Déjà remboursé ($code)';
  String initialAmountLabel(String code) => 'Montant initial ($code)';
  String monthlyRepaymentLabel(String code) => 'Remboursement mensuel ($code)';
  String monthlyContributionLabel(String code) =>
      'Contribution mensuelle ($code)';
  String get autoPaymentMonthly => 'Paiement automatique mensuel';
  String get autoDepositMonthly => 'Dépôt automatique mensuel';
  String get autoDesc =>
      'Si activé, une entrée auto est ajoutée chaque mois selon le montant mensuel.';
  String get firstAutoDate => 'Date du premier dépôt auto';
  String get chooseDate => 'Choisir une date';
  String get priorityLabel => 'Priorité (0 = plus prioritaire)';
  String get targetDateLabel => 'Date cible';
  String get namePlaceholder => 'Nom';
  String recommendedForTarget(String amount) =>
      'Recommandé pour la date cible: $amount / mois';
  String projectedWithMonthly(String date) =>
      'Avec ton montant mensuel: fin estimée $date';
  String get projectedUnavailable =>
      'Avec ton montant mensuel: projection indisponible (0/mois)';

  // Dialog: movement
  String movementTitle(String name) => 'Mouvement - $name';
  String get deposit => 'Dépôt';
  String get withdrawal => 'Retrait';
  String amountLabel(String code) => 'Montant ($code)';
  String availableNow(String amount) => 'Disponible actuel: $amount';
  String afterDeposit(String amount) => 'Après dépôt: $amount';
  String afterWithdrawal(String amount) => 'Après retrait: $amount';
  String get noteOptional => 'Note (optionnel)';
  String get validate => 'Valider';

  // Dialog: history
  String historyTitle(String name) => 'Historique - $name';
  String get noMovements => 'Aucun mouvement pour cet élément.';
  String get autoEntry => 'Auto';
  String get manualEntry => 'Manuel';

  // Snackbars
  String get saved => 'Enregistré';
  String get saveErrorMsg => 'Erreur de sauvegarde';
  String get invalidAmount => 'Montant invalide';
  String get withdrawalExceedsAvailable => 'Retrait supérieur au disponible';
  String get movementSaved => 'Mouvement enregistré';
  String get movementError => 'Erreur de mouvement';
  String historyError(Object e) => 'Erreur: $e';
}

// ---------------------------------------------------------------------------
// Schedule (Échéancier)
// ---------------------------------------------------------------------------
class _Schedule {
  const _Schedule();

  String get title => 'Échéancier';
  String get subtitle => 'Prélèvements et factures à venir';

  String get sectionAuto => 'Prélèvements auto';
  String get sectionManual => 'Factures manuelles';

  String get viewList => 'Liste';
  String get viewCalendar => 'Calendrier';

  String get periodMonth => 'Mois';
  String get periodAll => 'Toutes';
  String get periodLabel => 'Période';
  String get viewLabel => 'Vue';

  String get totalToPay => 'TOTAL À PAYER';
  String get allPeriods => 'TOUTES PÉRIODES';
  String get calendarMonth => 'Calendrier du mois';
  String get monthInvoices => 'Factures du mois';
  String get allInvoices => 'Toutes les factures';
  String get visibleWithTotal =>
      'Factures affichées (total complet entre parenthèses)';

  String get noDeadlines => 'Aucune échéance';
  String get paid => 'Payé';
  String get pay => 'Payer';
  String get validate => 'Valider';

  String overdueLabel(int days) =>
      'En retard de $days jour${days > 1 ? 's' : ''}';
  String dueToday() => 'Échéance aujourd\'hui';
  String daysUntil(int days) => 'Dans $days jour${days > 1 ? 's' : ''}';
  String hiddenCount(int count) =>
      '+$count échéance${count > 1 ? 's' : ''} suivante${count > 1 ? 's' : ''} plus tard';
}

// ---------------------------------------------------------------------------
// Spreadsheet (Tableur)
// ---------------------------------------------------------------------------
class _Spreadsheet {
  const _Spreadsheet();

  String get title => 'Tableur';
  String get subtitle => 'Vue annuelle revenus / dépenses';
  String get pageTitle => 'Plan stratégique';
  String yearSubtitle(int year) => '$year – Prévision annuelle';
  String get loadError => 'Erreur lors du chargement du tableau';

  String get modePrudent => 'Prudent';
  String get modePrevision => 'Prévision';

  String get hintPrudent => 'Mode prudent: revenus non confirmés exclus.';
  String get hintPrevision =>
      'Mode prévision: les revenus estimés sont inclus (préfixe ~).';

  String get colCategory => 'Category';
  String get colTotal => 'Total';
  String totalSection(String label) => 'TOTAL ${label.toUpperCase()}';

  String get netCashFlow => 'NET CASH FLOW';
  String get totalIncome => 'Total Revenus';
  String get totalExpense => 'Total Dépenses';
}

// ---------------------------------------------------------------------------
// Analysis
// ---------------------------------------------------------------------------
class _Analysis {
  const _Analysis();

  String get title => 'Analyse';
  String get subtitle => 'Vue consolidée des tendances et performances.';
  String error(Object e) => 'Erreur: $e';

  // KPI cards
  String get growthLabel => 'GROWTH VS PREV. YEAR';
  String get savingsVelocityLabel => 'SAVINGS VELOCITY';
  String get freedomDateLabel => 'FINANCIAL FREEDOM DATE';
  String get incomeMomentum => 'Income Momentum';
  String get savingsTarget => 'Target: 60%';
  String get kpiFreedomValue => 'Sept 2038';
  String get kpiFreedomSub => '-2 Years vs Jan Estimate';

  // Chart
  String get yoyChartTitle => 'Year-over-Year Income vs Expense Growth';
  String get yoyChartSubtitle =>
      'Strategic view of wealth accumulation efficiency';
  String get netIncomeGrowth => 'NET INCOME GROWTH';
  String get expenseTrend => 'EXPENSE TREND';
  String spreadGrowthBadge(String pct) => '+$pct% Spread Growth';

  // Tooltips
  String get incomeLabel => 'Revenus';
  String get expenseLabel => 'Dépenses';

  // Projected savings card
  String get projectedSavingsTitle => 'PROJECTED SAVINGS GROWTH (5YR)';
  String get aggressiveStrategy => 'Aggressive Strategy';
  String get monthlyYield => 'MONTHLY YIELD';
  String get projectedRoi => 'PROJECTED ROI';
  String get compoundEffect => 'Compound Effect';
  String compoundNote(String amount) =>
      'Current trajectory adds $amount in passive appreciation by 2030.';

  // Peer comparison card
  String get peerComparisonTitle => 'PEER COMPARISON INDEX';
  String get topSegment => 'TOP 10% SEGMENT';
  String get efficiencyScore => 'EFFICIENCY INDEX SCORE';
  String vsMedianPeers(String amount) => 'Vs. ${amount}k median peers';
  String get peerOptimal => 'Optimal';
  String get peerAbove => 'Above';
}

// ---------------------------------------------------------------------------
// Portfolio
// ---------------------------------------------------------------------------
class _Portfolio {
  const _Portfolio();

  String get title => 'Portfolio';
  String get subtitle => 'Suivi de vos investissements';

  String get tabHoldings => 'Positions';
  String get tabWatchlist => 'Watchlist';
  String get tabTrending => 'Tendances';

  String get totalValue => 'Valeur totale';
  String get totalGainLoss => 'Gain / Perte';
  String get invested => 'Investi';
  String get currentPrice => 'Prix actuel';
  String get performance => 'Performance totale';

  String get addToWatchlist => 'Ajouter à la watchlist';
  String get removeFromWatchlist => 'Retirer de la watchlist';
  String get searchAsset => 'Rechercher un actif...';
  String get noHoldings => 'Aucune position';
  String get noWatchlist => 'Watchlist vide';

  String get plTotal => 'P/L total';
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------
class _Auth {
  const _Auth();

  String get title => 'Connexion';
  String get subtitle => 'Connectez-vous à votre compte Solver';
  String get emailLabel => 'Adresse e-mail';
  String get emailHint => 'votre@email.com';
  String get passwordLabel => 'Mot de passe';
  String get passwordHint => 'Votre mot de passe';
  String get loginButton => 'Se connecter';
  String get loggingIn => 'Connexion...';

  String get errorInvalidCredentials => 'Email ou mot de passe incorrect.';
  String get errorNetwork => 'Erreur réseau. Vérifiez votre connexion.';
  String get errorUnknown => 'Une erreur est survenue. Réessayez.';
  String get errorEmailRequired => 'L\'email est requis.';
  String get errorPasswordRequired => 'Le mot de passe est requis.';
}

// ---------------------------------------------------------------------------
// Forms (shared modal labels)
// ---------------------------------------------------------------------------
class _Forms {
  const _Forms();

  // Common type labels
  String get typeLabel => 'Type';
  String get nameLabel => 'Nom';
  String get typeExpense => 'Dépense';
  String get typeIncome => 'Revenu';
  String get typeExpensePlural => 'Dépenses';
  String get typeIncomePlural => 'Revenus';
  String get typeAll => 'Tout';
  String get archives => 'Archives';
  String get required => 'Requis';

  // Account form
  String get newAccount => 'Nouveau compte';
  String get editAccount => 'Modifier le compte';
  String get accountName => 'Nom du compte';
  String get accountGroupHint => 'Groupe (ex: Charges fixes)';
  String get accountType => 'Type de compte';
  String get accountBalance => 'Solde initial';
  String get accountIsIncome => 'Compte de revenus';
  String get accountIsFixed => 'Dépenses fixes';
  String get fixedAmount => 'Montant fixe';
  String get createAccountBtn => 'Créer le compte';

  // Transaction form
  String get newTransaction => 'Nouvelle transaction';
  String get editTransaction => 'Modifier la transaction';
  String get newTransactionHint =>
      'Sélectionne une catégorie existante ou crée-la directement ici.';
  String get transactionDate => 'Date';
  String get transactionAmount => 'Montant';
  String get transactionNote => 'Note (optionnel)';
  String get transactionStatus => 'Statut';
  String get transactionIsAuto => 'Prélèvement automatique';
  String get transactionAccount => 'Compte';
  String get transactionCategory => 'Catégorie';
  String get accountsLoadError => 'Erreur de chargement des comptes';
  String get chooseCategory => 'Choisir une catégorie';
  String get alreadyPaid => 'Déjà payé';
  String get paidHelper => 'Coché par défaut pour les opérations déjà réglées.';
  String get notPaidHelper =>
      'Non payé: apparaîtra dans les factures à traiter.';
  String get repeatMonthly => 'Répéter chaque mois';
  String get repaymentPlan => 'Plan de remboursement';
  String get repaymentPlanHelper =>
      'Crée automatiquement des mensualités jusqu\'au solde.';
  String get repaymentPlanHelperOff =>
      'Active si tu rembourses un montant total sur plusieurs mois.';
  String get until => 'Jusqu\'au';
  String get chooseValidEndDate => 'Choisis une date de fin valide';
  String willCreateTransactions(int n) => '$n transaction(s) seront créées';
  String get repaymentHintEmpty =>
      'Renseigne mensualité et total pour calculer le plan.';
  String repaymentSummary(int n, String date, String last) =>
      '$n mensualité(s) jusqu\'au $date (dernière: $last)';
  String createRepaymentPlan(int n) => 'Créer plan ($n mensualités)';
  String createTransactions(int n) => 'Créer $n transaction(s)';
  String get createTransaction => 'Créer la transaction';
  String get invalidRecurrenceEndDate =>
      'Date de fin invalide pour la répétition';
  String get invalidRepaymentTotal => 'Montant total à rembourser invalide';
  String get invalidMonthly => 'Mensualité invalide';
  String get selectAccount => 'Sélectionnez un compte';
  String transactionsCreated(int n) => '$n transaction(s) créée(s)';
  String get transactionCreated => 'Transaction créée';
  String get createError => 'Erreur lors de la création';
  String categoryCreated(String name) => 'Catégorie "$name" créée';
  String get categoryCreateError => 'Erreur création catégorie';
  String amountWithCode(String code) => 'Montant ($code)';
  String monthlyAmountLabel(String code) => 'Mensualité ($code)';
  String repaymentTotalLabel(String code) => 'Total à rembourser ($code)';

  // Category picker
  String get selectAccountTitle => 'Sélectionner un compte';
  String get searchCategoryHint => 'Rechercher une catégorie ou un groupe';
  String get suggestions => 'Suggestions';
  String get favorites => 'Favoris';
  String get recents => 'Récents';
  String get noResultsCreateCategory =>
      'Aucun résultat. Crée une catégorie rapide.';
  String get expensesSectionTitle => 'DÉPENSES';
  String get incomesSectionTitle => 'REVENUS';
  String get quickCategory => 'Catégorie rapide';
  String get manageGroups => 'Gérer groupes/cat.';
  String get quickCreate => 'Création rapide';

  // Quick create dialog
  String get quickCategoryTitle => 'Création rapide catégorie';
  String get useExistingGroup => 'Utiliser un groupe existant';
  String get createNewGroup => 'Créer un nouveau groupe';
  String get newGroupName => 'Nom nouveau groupe';

  // Category form
  String get newCategory => 'Nouvelle catégorie';
  String get editCategory => 'Modifier catégorie';
  String get categoryName => 'Nom de la catégorie';
  String get categoryGroup => 'Groupe';

  // Categories manager
  String get manageCategoriesTitle => 'Gérer groupes et catégories';
  String get newGroupBtn => 'Nouveau groupe';
  String get newCategoryBtn => 'Nouvelle catégorie';
  String get categoriesManagerHint =>
      'Un groupe organise les dépenses/revenus. Une catégorie sert à accumuler les opérations dans ce groupe.';
  String categoriesError(Object e) => 'Erreur catégories: $e';
  String groupsError(Object e) => 'Erreur groupes: $e';
  String get archivedGroup => 'Groupe archivé';
  String get noGroups => 'Aucun groupe';
  String get noCategories => 'Aucune catégorie dans ce groupe';
  String get renameGroup => 'Renommer groupe';
  String get archiveGroup => 'Archiver groupe';
  String get unarchive => 'Désarchiver';
  String get archive => 'Archiver';
  String get createGroupUnavailable =>
      'Création de groupe indisponible: mets à jour/redémarre le backend.';
  String get renameGroupUnavailable =>
      'Renommage de groupe indisponible sur cette version backend.';
  String get archiveGroupUnavailable =>
      'Archivage de groupe indisponible sur cette version backend.';
  String get newCategoryTitle => 'Nouvelle catégorie';
  String get editCategoryTitle => 'Modifier catégorie';
  String get newGroupTitle => 'Nouveau groupe';
  String get renameGroupTitle => 'Renommer groupe';
  String get groupNameLabel => 'Nom du groupe';
  String get newGroupHint => 'Ex: Transactions, Charges fixes';

  // Validation
  String get fieldRequired => 'Ce champ est requis.';
  String get invalidAmount => 'Montant invalide.';
  String get invalidDate => 'Date invalide.';

  // Actions
  String get create => 'Créer';
  String get update => 'Mettre à jour';
  String get deleteConfirm => 'Êtes-vous sûr de vouloir supprimer ?';
}

// ---------------------------------------------------------------------------
// UI (tooltips, labels for theme/currency toggles)
// ---------------------------------------------------------------------------
class _UI {
  const _UI();

  String get themeTooltipLight => 'Passer en mode clair';
  String get themeTooltipDark => 'Passer en mode sombre';
  String get currencyTooltip => 'Changer de devise';
  String get currencyConverterTooltip => 'Convertir une devise';
  String get currencyConverterAction => 'Convertir';
  String get currencyConverterTitle => 'Convertisseur de devises';
  String get currencyConverterSubtitle =>
      'Valeurs indicatives selon les taux de change en direct.';
  String currencyConverterSource(String source) => 'Source des taux: $source';
  String currencyConverterUpdatedAt(String date) =>
      'Derniere mise a jour: $date UTC';
  String get currencyConverterUpdatedUnknown =>
      'Derniere mise a jour: inconnue';
  String get currencyConverterAmountLabel => 'Montant';
  String get currencyConverterFromLabel => 'Devise source';
  String get currencyConverterAllLabel => 'Toutes devises';
  String get currencyConverterFavoritesLabel => 'Favoris';
  String get currencyConverterFavoritesEmpty =>
      'Aucun favori pour le moment. Ajoute une devise avec l etoile.';
  String get currencyConverterAddFavorite => 'Ajouter aux favoris';
  String get currencyConverterRemoveFavorite => 'Retirer des favoris';
  String get currencyConverterRatesLabel => 'Equivalences';
  String get currencyConverterPopularLabel => 'Devises populaires';
  String get currencyConverterSearchLabel => 'Rechercher une devise';
  String get currencyConverterSearchHint => 'Ex: MAD, NOK, INR, Peso...';
  String get currencyConverterNoSearchResult =>
      'Aucune devise trouvee pour cette recherche.';
  String get currencyConverterAvailableByApi =>
      'Liste des devises disponible via l API de taux.';
  String get currencyConverterNoRate => 'Taux indisponible';
  String get currencyConverterRefresh => 'Actualiser';
  String get currencyConverterOffline =>
      'Impossible de charger les taux. Verifie la connexion.';
  String get currencyConverterIndicative =>
      'Conversion informative uniquement, hors frais bancaires.';

  String get currencyChf => 'CHF – Franc suisse';
  String get currencyEur => 'EUR – Euro';
  String get currencyUsd => 'USD – Dollar américain';
}
