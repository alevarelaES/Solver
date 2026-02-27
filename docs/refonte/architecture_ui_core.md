# Architecture UI Core — Solver Premium Dark Redesign

> **Phase A — Document de référence fondation.**
> Ce document doit être lu et implémenté en totalité AVANT de toucher une seule page.
> Aucun widget de feature ne doit être modifié tant que ce socle n'est pas en place.

---

## 1. Principes Absolus : Deux Règles d'Or

### Règle 1 — Zéro Hardcode Visuel

```
PremiumThemeExtension   ← SEULE source pour opacités, glow, blur, palettes dark
       ↓
PremiumCardBase         ← SEUL widget porteur des effets glass/border
       ↓
Tous les widgets de carte (BalanceCard, KpiCard, GoalCard, etc.)
```

**Règles non-négociables :**
- Aucun `Colors.X.withOpacity(Y)` en dur dans une vue ou un widget de feature.
- Aucun `BackdropFilter` en dur hors de `PremiumCardBase`.
- Aucun rayon, padding ou taille de fonte hardcodé dans les vues.
- Si demain l'opacité du glow change de 0.12 à 0.08 → modification dans `PremiumThemeExtension.dark()` uniquement.

### Règle 2 — Zéro Texte en Dur (i18n obligatoire)

**Système l10n existant :** `lib/core/l10n/` — fichiers `.arb`, classe `AppLocalizations`.

**Interdiction stricte :**
- Aucun `Text("label en dur")` dans aucun widget, vue ou composant.
- Aucun `tooltip:`, `hintText:`, `labelText:`, `semanticsLabel:` avec une chaîne littérale.
- Aucun message d'erreur, placeholder, titre de section ou libellé de bouton en dur.

**Obligation :**
- Toute chaîne visible par l'utilisateur passe par une clé `AppLocalizations` :
  ```
  // Interdit :
  Text("Tableau de bord")
  Text("Aucune donnée disponible")

  // Obligatoire :
  Text(l10n.dashboardTitle)
  Text(l10n.emptyStateNoData)
  ```
- Toute nouvelle clé est déclarée dans `app_fr.arb` (et les autres locales si existantes) **avant** d'être utilisée dans le widget.
- Les noms de clés suivent le format `camelCase` + préfixe de feature :
  `dashboardTitle`, `portfolioTabPositions`, `budgetGaugeUsedPercent`, etc.

**Périmètre :**
- S'applique à tous les widgets créés ou modifiés dans le cadre de la refonte.
- Les widgets existants non modifiés dans un batch donné ne sont pas à migrer (éviter le scope creep) — sauf s'ils sont refondus.

---

## 2. Palette "Ultra Dark" — Tokens Additionnels

**Fichier cible :** `lib/core/theme/app_premium_theme.dart` *(nouveau)*

Ces tokens complètent `app_theme.dart` existant. Ils ne remplacent pas les couleurs actuelles ; ils s'y ajoutent comme extension.

### 2.1 Surfaces

| Token | Valeur hex/rgba | Usage |
|-------|-----------------|-------|
| `canvasDeep` | `#07090A` | Fond de page principal (body) |
| `canvasMid` | `#0E1210` | Fond des sections secondaires |
| `glassSurface` | `#141918` | Fond opaque des cartes standard |
| `glassSurfaceHero` | `#0D1A0B` | Fond carte balance / hero cards |
| `glassBorder` | `rgba(255,255,255,0.07)` | Bordure 1px cartes au repos |
| `glassBorderActive` | `rgba(255,255,255,0.16)` | Bordure carte sélectionnée/hover |
| `glassBorderAccent` | `rgba(104,158,40,0.30)` | Bordure carte avec accent vert |
| `glassOverlay` | `rgba(255,255,255,0.03)` | Overlay InkWell hover |

### 2.2 Glow & Lumières

| Token | Type | Valeur | Usage |
|-------|------|--------|-------|
| `glowGreenOpacity` | `double` | `0.12` | Opacité ombre glow vert |
| `glowGreenRadius` | `double` | `40.0` | spreadRadius du BoxShadow glow |
| `glowGreenBlur` | `double` | `60.0` | blurRadius du BoxShadow glow |
| `glowDangerOpacity` | `double` | `0.10` | Glow rouge (valeurs négatives) |
| `glowDangerRadius` | `double` | `30.0` | |
| `blurSigma` | `double` | `12.0` | Sigma du BackdropFilter |
| `blurEnabled` | `bool` | `true` | Kill-switch global (false = 0 BackdropFilter, perf mobile) |

### 2.3 Gradients Prédéfinis

| Token | Stops | Usage |
|-------|-------|-------|
| `heroCardGradient` | `#0D1A0B` → `#1C3016` | Fond carte balance |
| `accentLineGradient` | `primaryGreen` → transparent | Lignes de graphique |
| `dangerLineGradient` | `#EF4444` → transparent | Lignes dépenses chart |
| `warmthGradient` | `#1A1200` → `#0E0E0E` | Sections warnings |

### 2.4 Typographie Chiffres

| Token | Type | Valeur | Usage |
|-------|------|--------|-------|
| `heroAmountSize` | `double` | `40.0` | Montant hero (balance) |
| `heroAmountWeight` | `FontWeight` | `w200` | Poids très fin grands chiffres |
| `kpiAmountSize` | `double` | `22.0` | Montants KPI secondaires |
| `kpiAmountWeight` | `FontWeight` | `w600` | |
| `tableAmountSize` | `double` | `13.0` | Montants en tableau |
| `fontFeatureTabular` | `List<FontFeature>` | `[FontFeature.tabularFigures()]` | Chiffres alignés |

### 2.5 Skeletons

| Token | Type | Valeur | Usage |
|-------|------|--------|-------|
| `skeletonBase` | `Color` | `rgba(255,255,255,0.04)` | Fond skeleton |
| `skeletonShimmer` | `Color` | `rgba(255,255,255,0.10)` | Shimmer animé |
| `skeletonDuration` | `Duration` | `1400ms` | Cycle d'animation |
| `skeletonRadius` | `double` | `6.0` | Rayon par défaut |

---

## 3. Extension de Thème : `PremiumThemeExtension`

**Fichier cible :** `lib/core/theme/app_premium_theme.dart`

### 3.1 Contrat de l'extension

```
class PremiumThemeExtension extends ThemeExtension<PremiumThemeExtension> {
  // --- Surfaces ---
  final Color canvasDeep
  final Color canvasMid
  final Color glassSurface
  final Color glassSurfaceHero
  final Color glassBorder
  final Color glassBorderActive
  final Color glassBorderAccent
  final Color glassOverlay

  // --- Glow ---
  final double glowGreenOpacity
  final double glowGreenRadius
  final double glowGreenBlur
  final double glowDangerOpacity
  final double glowDangerRadius

  // --- Blur ---
  final double blurSigma
  final bool blurEnabled

  // --- Gradients ---
  final Gradient heroCardGradient
  final Gradient accentLineGradient
  final Gradient dangerLineGradient

  // --- Typography ---
  final double heroAmountSize
  final FontWeight heroAmountWeight
  final double kpiAmountSize
  final FontWeight kpiAmountWeight
  final double tableAmountSize
  final List<FontFeature> fontFeatureTabular

  // --- Skeletons ---
  final Color skeletonBase
  final Color skeletonShimmer
  final Duration skeletonDuration
  final double skeletonRadius

  // --- Factories ---
  static PremiumThemeExtension dark()    // valeurs dark mode
  static PremiumThemeExtension light()   // valeurs light (gracieux, sans glass)

  @override
  PremiumThemeExtension copyWith(...)

  @override
  PremiumThemeExtension lerp(ThemeExtension<PremiumThemeExtension>? other, double t)
}
```

### 3.2 Injection dans `app_theme.dart`

Dans la méthode de construction du `ThemeData` dark (et light), ajouter :

```
ThemeData(
  ...
  extensions: [
    PremiumThemeExtension.dark(),   // ou .light()
  ],
)
```

### 3.3 Accès dans les widgets

```
// Lecture dans n'importe quel widget :
final p = Theme.of(context).extension<PremiumThemeExtension>()!;

// Utilisation :
color: p.glassSurface
borderColor: p.glassBorder
sigma: p.blurSigma
```

---

## 4. Widget Socle : `PremiumCardBase`

**Fichier cible :** `lib/shared/widgets/premium_card_base.dart`

### 4.1 Rôle

`PremiumCardBase` est le **seul** widget autorisé à porter :
- La couleur de surface glass
- La bordure 1px
- Le glow optionnel
- Le BackdropFilter optionnel
- L'InkWell avec overlay

Tout widget de carte est une **composition** autour de `PremiumCardBase`.

### 4.2 Variants

```
enum PremiumCardVariant {
  hero,       // carte balance, headers majeurs
  standard,   // sections et panneaux
  kpi,        // cartes KPI en ligne
  listItem,   // lignes de liste (pas de fond, juste diviseur)
  chip,       // pill / badge
  sidebar,    // items de sidebar (hauteur fixe)
}
```

### 4.3 Contrat des paramètres

```
PremiumCardBase({
  required Widget child,
  PremiumCardVariant variant = standard,

  // Layout
  EdgeInsetsGeometry? padding,      // override du padding par défaut du variant
  double? width,
  double? height,
  double? borderRadius,             // override du radius par défaut

  // Apparence optionnelle (escape hatch — usage exceptionnel uniquement)
  Color? overrideSurface,
  Color? overrideBorder,
  Gradient? overrideGradient,

  // Glow
  bool showGlow = false,
  Color? glowColor,                 // défaut: primary green du theme

  // Blur (lit blurEnabled depuis PremiumThemeExtension)
  bool enableBlur = false,

  // Interaction
  VoidCallback? onTap,
  bool selected = false,            // → glassBorderActive si true
})
```

### 4.4 Comportement par variant

| Variant | Radius | Padding interne | Surface | Bordure |
|---------|--------|-----------------|---------|---------|
| `hero` | 20px | 24px | `glassSurfaceHero` + `heroCardGradient` | `glassBorderActive` |
| `standard` | 16px | 16px | `glassSurface` | `glassBorder` |
| `kpi` | 12px | 14px / 12px | `glassSurface` | `glassBorder` |
| `listItem` | 0px | 12px / 8px | transparent | aucune (PremiumDivider en bas) |
| `chip` | 99px | 8px / 14px | `glassSurface` léger | `glassBorder` |
| `sidebar` | 10px | 12px | transparent | none |

### 4.5 Arbre interne (logique — sans code)

```
PremiumCardBase
└── AnimatedContainer (transitions de couleur smooth)
    └── [si enableBlur && p.blurEnabled]
        └── ClipRRect
            └── BackdropFilter(sigmaX: p.blurSigma, sigmaY: p.blurSigma)
    └── DecoratedBox (surface + border + glow via BoxDecoration)
        └── [si onTap != null]
            └── InkWell(overlayColor: p.glassOverlay)
        └── Padding(padding: _resolvedPadding)
            └── child
```

---

## 5. Widget : `PremiumDivider`

**Fichier cible :** `lib/shared/widgets/premium_divider.dart`

### 5.1 Contrat

```
PremiumDivider({
  Axis direction = Axis.horizontal,
  double thickness = 1.0,
  double? indent,
  double? endIndent,
  // Lit glassBorder depuis PremiumThemeExtension (pas de couleur en dur)
})
```

### 5.2 Cas d'usage

| Contexte | Appel |
|----------|-------|
| Entre lignes de tableau | `PremiumDivider(indent: AppSpacing.md)` |
| Séparateur section sidebar | `PremiumDivider()` |
| Séparateur vertical header | `PremiumDivider(direction: Axis.vertical)` |
| Ligne sous titre de section | `PremiumDivider(endIndent: 60%)` |

---

## 6. Widget : `PremiumSkeleton`

**Fichier cible :** `lib/shared/widgets/premium_skeleton.dart`

### 6.1 Principe

Un seul widget de chargement dans toute l'application. Couleur, shimmer et durée viennent de `PremiumThemeExtension`. Aucun loader custom par feature.

### 6.2 Contrat

```
PremiumSkeleton({
  required double width,
  required double height,
  double? borderRadius,   // défaut: p.skeletonRadius
  bool isCircle = false,
})

// Variants composites pré-construits :
PremiumSkeleton.kpiCard()       // 3 blocs empilés, mimant une KpiCard
PremiumSkeleton.listItem()      // ligne de tableau (icon + 2 textes + montant)
PremiumSkeleton.chart({double height = 180})
PremiumSkeleton.textLine({double width = double.infinity})
PremiumSkeleton.heroCard()      // mimant BalanceHeroCard
```

### 6.3 Animation

Shimmer basé sur `AnimationController` avec `Tween<double>(0.0 → 1.0)`.
Gradient horizontal qui traverse la forme. Durée = `p.skeletonDuration`.

---

## 7. Widget : `PremiumAmountText`

**Fichier cible :** `lib/shared/widgets/premium_amount_text.dart`

Remplace progressivement tous les `Text` affichant des montants financiers.

### 7.1 Contrat

```
PremiumAmountText({
  required double amount,
  required String currency,           // ex: 'CHF', 'USD', '%'
  PremiumAmountVariant variant = standard,
  bool showSign = false,              // force +/- prefix
  bool colorCoded = false,            // vert si positif, rouge si négatif
  Color? overrideColor,
  String? overrideFontFamily,         // pour monospaced dans tableaux
})

enum PremiumAmountVariant { hero, standard, small, table }
```

### 7.2 Styles par variant

| Variant | Taille | Poids | FontFeatures |
|---------|--------|-------|--------------|
| `hero` | `p.heroAmountSize` | `p.heroAmountWeight` | tabular |
| `standard` | `p.kpiAmountSize` | `p.kpiAmountWeight` | tabular |
| `small` | `14` | `w500` | tabular |
| `table` | `p.tableAmountSize` | `w500` | tabular + mono |

---

## 8. Mise à Jour de `PageScaffold`

**Fichier cible :** `lib/shared/widgets/page_scaffold.dart` *(modification mineure)*

Adapter la `backgroundColor` pour lire `p.canvasDeep` depuis `PremiumThemeExtension` quand le thème dark est actif.

```
// Avant :
color: theme.colorScheme.background

// Après :
color: isDark ? p.canvasDeep : theme.colorScheme.background
```

---

## 9. Mise à Jour de `AppShell` et `DesktopSidebar`

**Fichiers cibles :**
- `lib/shared/widgets/app_shell.dart`
- `lib/shared/widgets/desktop_sidebar.dart`

### Sidebar
- Fond de la sidebar → `p.canvasMid` (légèrement plus clair que la page)
- Bordure droite de la sidebar → `PremiumDivider(direction: Axis.vertical)`
- Items de navigation hover → `PremiumCardBase(variant: sidebar)`

---

## 10. Mapping de Migration

### Widgets existants → nouveaux comportements

| Widget actuel | Action | Priorité |
|---------------|--------|----------|
| `GlassContainer` | Wrapper interne → `PremiumCardBase(variant: standard)` ; garder l'API publique pour compat | P1 |
| `AppPanel` | Conserver pour surfaces non-card ; adapter `backgroundColor` | P2 |
| `KpiCard` | Reconstruire intérieur avec `PremiumCardBase(variant: kpi)` + `PremiumAmountText` | P1 |
| `PageScaffold` | Adapter background → `p.canvasDeep` | P1 |
| `DesktopSidebar` | Adapter couleurs + hover items | P2 |
| Tous `Text` montants | Migrer vers `PremiumAmountText` au fil des pages | P3 |

---

## 11. Ordre d'Implémentation (Batch 0)

```
[ ] 1. Créer lib/core/theme/app_premium_theme.dart
       → PremiumThemeExtension avec dark() et light()
[ ] 2. Injecter dans app_theme.dart (extensions: [...])
[ ] 3. Créer lib/shared/widgets/premium_card_base.dart
[ ] 4. Créer lib/shared/widgets/premium_divider.dart
[ ] 5. Créer lib/shared/widgets/premium_skeleton.dart
[ ] 6. Créer lib/shared/widgets/premium_amount_text.dart
[ ] 7. Adapter PageScaffold (background)
[ ] 8. Adapter AppShell / DesktopSidebar (fond + hover)
[ ] 9. Gate : flutter analyze — zéro erreur
[ ] 10. Gate : smoke test visuel sur Dashboard existant
        (les pages ne doivent pas régresser en chargeant le nouveau fond)
```

---

## 12. Critères de Validation du Batch 0

- `flutter analyze` → 0 erreur, 0 warning sur les nouveaux fichiers.
- Le changement d'une valeur dans `PremiumThemeExtension.dark()` impacte visuellement toutes les cartes sans toucher d'autre fichier.
- `blurEnabled = false` supprime tous les `BackdropFilter` de l'application sans aucune modification supplémentaire.
- Un montant quelconque peut être rendu avec `PremiumAmountText` avec les chiffres tabulaires alignés.
- La page Dashboard existante s'affiche sans régression (layout conservé, fond mis à jour).
- **Aucune chaîne de caractères visible utilisateur dans les nouveaux fichiers** — grep sur les fichiers créés doit retourner zéro `Text("` avec contenu littéral.
