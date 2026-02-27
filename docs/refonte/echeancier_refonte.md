# Échéancier — Plan de Refonte

> **Réf. image :** `Echeancier.png`
> **Feature path :** `lib/features/schedule/`

---

## 1. Analyse Visuelle

### 1.1 Layout Global

```
┌──────────────────────────────────────────────────────────────────┐
│  Échéancier                                                      │
│  Suivez vos factures, prélèvements et échéances à payer         │
├──────────────────────────────────────────────────────────────────┤
│  [ScheduleHeroCard]  80,00 CHF  TOTAL À PAYER - FÉVRIER 2026    │
│                      [mini sparkline]  [badge Factures Actives] │
│  [Tabs: Stat | Calendrier | Mob | Tableur]                       │
├───────────────────────────┬──────────────────────────────────────┤
│  [ScheduleLeftPanel]      │  [ScheduleMainContent]               │
│  UpcomingInvoices         │                                      │
│  → Manual: 0,00 CHF       │  [KpiHeaders]                        │
│  → Prélèvements: 0,00 CHF │  0,00 CHF | → Prélèvements auto    │
│                           │                                      │
│  [MiniCalendar]           │  [FacturesManuelles]                 │
│  Février 2026             │  → InvoiceCard (rouge: Téléphone)   │
│  (grille jours)           │                                      │
│                           │  [PrelèvementsAuto]                  │
│                           │  → EmptyState                        │
└───────────────────────────┴──────────────────────────────────────┘
```

### 1.2 Changements Structurels Majeurs

| Élément | Avant | Après |
|---------|-------|-------|
| Header | Simple | Hero card avec gradient d'alerte (rouge/orange), mini sparkline, badge |
| Navigation | Aucune ou simple | Tab Bar 4 onglets : Stat / Calendrier / Mob / Tableur |
| Layout | Colonne unique | 2 colonnes (panel gauche + contenu principal) |
| Calendrier | Absent ou basique | Mini calendrier intégré dans le panel gauche |
| Factures | Liste plate | Cards visuelles avec indicateurs d'urgence colorés |

### 1.3 Éléments "Premium Dark"

- **ScheduleHeroCard** : fond dégradé `warmthGradient` (orangé/brun sombre pour signal d'alerte), chiffre en `PremiumAmountText(variant: hero)`.
- **Badge alerte** : `PremiumCardBase(variant: chip)` avec fond rouge pour "1 RETARD".
- **InvoiceCard urgente** : bordure `glassBorderAccent` remplacée par bordure rouge, fond légèrement teinté rouge.
- **MiniCalendar** : jours sous forme de grille compacte, jours avec échéances marqués d'un point vert ou rouge.
- **EmptyState** : icône illustrative centrée + texte, pas de fond (transparent), style sobre.

---

## 2. Arbre des Composants Cibles

### 2.1 Vue principale — `schedule_view.dart`

```
ScheduleView
├── AppShell
└── Column
    ├── PageHeader("Échéancier")
    ├── ScheduleHeroCard                       ← CRÉER/MODIFIER
    ├── ScheduleTabBar(tabs: [Stat,Cal,Mob,Tab])  ← CRÉER
    └── TabBarView
        ├── ScheduleStatTab                    ← layout 2 colonnes
        ├── ScheduleCalendarTab                ← (vue calendrier étendu)
        ├── ScheduleMobileTab                  ← (vue mobile-friendly)
        └── ScheduleSpreadsheetTab             ← (vue tableur)
```

### 2.2 `ScheduleHeroCard` *(nouveau ou refonte)*

**Fichier :** `lib/features/schedule/widgets/schedule_hero_card.dart`

```
ScheduleHeroCard({
  required double totalDue,
  required String period,
  required int activeCount,
  required bool hasOverdue,
  required List<double> sparklineData,
})
└── PremiumCardBase(
      variant: hero,
      overrideGradient: hasOverdue ? p.warmthGradient : p.heroCardGradient,
      showGlow: hasOverdue,
      glowColor: hasOverdue ? AppColors.danger : AppColors.primary,
    )
    └── Row
        ├── Column
        │   ├── PremiumAmountText(variant: hero, amount: totalDue)
        │   ├── Text("TOTAL À PAYER - $period")
        │   └── OverdueBadge(count: activeCount) si hasOverdue
        └── MiniSparkline(points: sparklineData, color: danger si overdue)
```

### 2.3 `OverdueBadge` *(nouveau, réutilisable)*

**Fichier :** `lib/shared/widgets/overdue_badge.dart`

```
OverdueBadge({
  required int count,
  String suffix = 'RETARD',
})
└── PremiumCardBase(variant: chip, overrideBorder: dangerColor)
    └── Row
        ├── Icon(warning, color: danger, size: 12)
        └── Text("$count $suffix", style: labelSmall, color: danger)
```

### 2.4 `ScheduleStatTab` — layout principal *(nouveau)*

**Fichier :** `lib/features/schedule/views/schedule_stat_tab.dart`

```
ScheduleStatTab
└── Row
    ├── ScheduleLeftPanel (fixed width: 240px)   ← CRÉER
    └── ScheduleMainContent (flex: 1)            ← CRÉER
```

### 2.5 `ScheduleLeftPanel` *(nouveau)*

**Fichier :** `lib/features/schedule/widgets/schedule_left_panel.dart`

```
ScheduleLeftPanel
└── Column
    ├── UpcomingInvoicesSummary          ← CRÉER
    │   └── PremiumCardBase(variant: standard)
    │       ├── SectionHeader("Upcoming invoices")
    │       ├── UpcomingSummaryRow("Manual invoices", amount)
    │       └── UpcomingSummaryRow("Prélèvements auto", amount)
    └── MiniMonthCalendar                ← CRÉER
        └── PremiumCardBase(variant: standard)
            ├── CalendarHeader(month, year, prev/next)
            └── CalendarGrid
                └── CalendarDayCell ×42
                    → couleur normale / point vert (échéance) / rouge (overdue)
```

### 2.6 `MiniMonthCalendar` *(nouveau, réutilisable)*

**Fichier :** `lib/shared/widgets/mini_month_calendar.dart`

```
MiniMonthCalendar({
  required DateTime month,
  required List<DateTime> scheduledDates,    // points verts
  required List<DateTime> overdueDates,      // points rouges
  ValueChanged<DateTime>? onDayTapped,
})
```

Layout : grille 7×6. Cellule sélectionnée → fond `glassBorderActive`. Point d'événement = 4px circle sous le chiffre.

### 2.7 `ScheduleMainContent` *(nouveau)*

**Fichier :** `lib/features/schedule/widgets/schedule_main_content.dart`

```
ScheduleMainContent
└── Column
    ├── ScheduleKpiHeader               ← CRÉER
    │   └── Row
    │       ├── KpiHeaderItem("0,00 CHF", label: "Factures manuelles")
    │       └── KpiHeaderItem("0,00 CHF", label: "Prélèvements auto")
    ├── InvoiceSection("Factures manuelles", items: manualInvoices)   ← CRÉER
    └── InvoiceSection("Prélèvements auto", items: autoInvoices)      ← CRÉER
```

### 2.8 `InvoiceSection` *(nouveau)*

**Fichier :** `lib/features/schedule/widgets/invoice_section.dart`

```
InvoiceSection({
  required String title,
  required List<Invoice> items,
})
└── Column
    ├── SectionHeader(title)
    ├── [si items.isEmpty] → ScheduleEmptyState
    └── [sinon] InvoiceCard ×N         ← CRÉER
```

### 2.9 `InvoiceCard` *(nouveau)*

**Fichier :** `lib/features/schedule/widgets/invoice_card.dart`

```
InvoiceCard({required Invoice invoice})
└── PremiumCardBase(
      variant: standard,
      overrideBorder: invoice.isOverdue ? AppColors.danger : null,
      overrideGradient: invoice.isOverdue ? p.warmthGradient.subtle : null,
    )
    └── Row
        ├── InvoiceIcon (icône de service/type)
        ├── Column
        │   ├── Text(invoice.name)
        │   └── Text(invoice.dueDate + " - Manuelle / " + status)
        ├── PremiumAmountText(variant: standard, colorCoded: false)
        └── PayButton si isPending              ← PrimaryButton compact
```

### 2.10 `ScheduleEmptyState` *(nouveau)*

**Fichier :** `lib/features/schedule/widgets/schedule_empty_state.dart`

```
ScheduleEmptyState({
  String message = "Aucune échéance programmée pour ce mois.\nTout est à jour.",
  IconData icon = Icons.flash_on_outlined,
})
```

---

## 3. Checklist Technique

### Batch S-1 : Composants partagés

```
[ ] S-1.1  Créer OverdueBadge
[ ] S-1.2  Créer MiniMonthCalendar
[ ] S-1.3  Vérifier disponibilité MiniSparkline (Dashboard)
```

### Batch S-2 : Hero + Tab Bar

```
[ ] S-2.1  Créer ScheduleHeroCard (bind sur provider schedule existant)
[ ] S-2.2  Créer ScheduleTabBar (4 onglets)
[ ] S-2.3  Test : badge overdue apparaît si une facture est en retard
[ ] S-2.4  Test : glow rouge si hasOverdue = true
```

### Batch S-3 : Panel gauche

```
[ ] S-3.1  Créer UpcomingInvoicesSummary
[ ] S-3.2  Créer MiniMonthCalendar avec points d'événements
[ ] S-3.3  Créer ScheduleLeftPanel
[ ] S-3.4  Test : clic sur un jour → filtre les factures du jour (si applicable)
```

### Batch S-4 : Contenu principal

```
[ ] S-4.1  Créer InvoiceCard (urgente et normale)
[ ] S-4.2  Créer InvoiceSection avec EmptyState
[ ] S-4.3  Créer ScheduleMainContent
[ ] S-4.4  Assembler ScheduleStatTab dans le TabBarView
```

### Batch S-5 : Onglets restants (phases suivantes)

```
[ ] S-5.1  Placeholder ScheduleCalendarTab (calendrier étendu)
[ ] S-5.2  Placeholder ScheduleMobileTab
[ ] S-5.3  Placeholder ScheduleSpreadsheetTab (lié à la feature Tableur)
```

### Batch S-6 : Finitions

```
[ ] S-6.1  Smoke test : mois sans facture → EmptyState visible
[ ] S-6.2  Smoke test : navigation entre onglets sans erreur
[ ] S-6.3  Smoke test : bouton "Payer" → action confirmée
[ ] S-6.4  flutter analyze → 0 warning
[ ] S-6.5  Vérifier : aucun hardcode couleur dans les nouveaux fichiers
```
