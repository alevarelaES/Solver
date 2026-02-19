# Audit Baseline Frontend (Step 0)

Date baseline: 2026-02-18
Scope: `lib/**`

## 1) Volume global
- Dart files: 115
- Total lines: 28,219

## 2) Files above target size
Target from master plan:
- view screen file: <= 600 lines
- non-view file: <= 300 lines

### Views > 600
- 1927 `lib/features/goals/views/goals_view.dart`
- 1764 `lib/features/schedule/views/schedule_view.dart`
- 1318 `lib/features/spreadsheet/views/spreadsheet_view.dart`
- 1243 `lib/features/journal/views/journal_view.filters.part.dart`
- 1212 `lib/features/analysis/views/analysis_view.dart`
- 789 `lib/features/budget/views/budget_view.dart`
- 739 `lib/features/journal/views/journal_view.detail.part.dart`
- 728 `lib/features/journal/views/journal_view.table.part.dart`
- 649 `lib/features/portfolio/views/portfolio_view.dart`

Count: 9

### Non-view files > 300
- 1586 `lib/features/transactions/widgets/transaction_form_modal.dart`
- 955 `lib/features/portfolio/widgets/asset_detail_inline.dart`
- 739 `lib/features/categories/widgets/categories_manager_modal.dart`
- 607 `lib/features/portfolio/widgets/portfolio_dashboard.dart`
- 487 `lib/features/dashboard/widgets/recent_activities.dart`
- 440 `lib/features/dashboard/widgets/financial_overview_chart.dart`
- 413 `lib/features/transactions/widgets/transactions_list_modal.dart`
- 374 `lib/features/budget/providers/budget_provider.dart`
- 365 `lib/features/dashboard/widgets/pending_invoices_section.dart`
- 301 `lib/core/theme/app_theme.dart`

Count: 10

## 3) UI consistency baseline
From `tools/refactor/audit_ui_consistency.ps1`:
- direct `styleFrom` outside theme helpers: 0
- non-token border radius: 0
- hardcoded hex colors outside theme: 0
- hardcoded numeric `EdgeInsets`: 0
- total findings: 0

Conclusion: tokenization baseline is good. Remaining debt is mostly architectural and file-size related.

## 4) Hardcoded business data findings
High-priority examples:
- 20 hardcoded `TrendingStock(...)` entries in `lib/features/portfolio/views/portfolio_view.dart`
- 20 hardcoded `TrendingStock(...)` entries in `lib/features/portfolio/providers/trending_provider.dart`
- Duplicate fallback catalogs between UI view and provider.

Other hardcoded/business-fallback signals:
- `legacy-*` ids still handled in categories/transactions flow:
  - `lib/features/categories/providers/categories_provider.dart`
  - `lib/features/categories/widgets/categories_manager_modal.dart`
  - `lib/features/transactions/widgets/transaction_form_modal.dart`

Open TODO markers:
- `lib/features/dashboard/widgets/promo_cards.dart`
- `lib/features/dashboard/widgets/spending_limit.dart`

## 5) Duplication signals
From `tools/refactor/find_duplicate_windows.ps1` (window=10, min=4):
- One repeated block detected in 4 locations:
  - `lib/features/analysis/views/analysis_view.dart:920`
  - `lib/features/analysis/views/analysis_view.dart:1167`
  - `lib/features/dashboard/widgets/market_popular_card.dart:225`
  - `lib/features/dashboard/widgets/pending_invoices_section.dart:287`

Additional obvious duplicate pattern:
- Trending fallback list duplicated across two files (provider + view).

## 6) Shared page layout adoption
Detected shared layout primitives:
- `AppPageScaffold` / `AppPageHeader` used in:
  - dashboard, budget, goals, schedule, portfolio
  - journal header (part file)

Still not migrated to shared page header/scaffold:
- `lib/features/analysis/views/analysis_view.dart`
- `lib/features/spreadsheet/views/spreadsheet_view.dart`
- `lib/features/auth/views/login_view.dart` (special-case auth page)

## 7) Candidate root/orphan files (manual review)
Import graph roots detected (14). This is not a delete list, only a review list.
Examples:
- `lib/shared/widgets/desktop_sidebar.dart`
- `lib/shared/widgets/kpi_card.dart`
- `lib/features/dashboard/widgets/my_cards_section.dart`
- `lib/features/dashboard/widgets/promo_cards.dart`
- `lib/features/dashboard/widgets/spending_limit.dart`
- `lib/features/portfolio/widgets/holding_list.dart`
- `lib/features/portfolio/widgets/portfolio_summary_card.dart`

## 8) Step 0 conclusion (frontend)
Main issues are structural, not style-token issues:
- oversized files,
- duplicated business fallback data,
- partial adoption of shared page skeleton,
- leftover legacy branches and TODOs.

Priority for Step 2/3/4:
1. split oversized view/widget files,
2. centralize dynamic fallback data policy (remove duplicated hardcoded catalogs),
3. complete shared layout migration for remaining pages.

