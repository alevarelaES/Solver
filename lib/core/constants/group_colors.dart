import 'package:flutter/material.dart';

/// Centralized group → accent color mapping.
/// Used by [GroupBadge] and any widget needing a group color.
/// Add/modify entries here — never hardcode colors in individual widgets.
class GroupColors {
  const GroupColors._();

  /// Returns a stable color for a group name.
  /// Matches on lowercase substring, falls back to a deterministic palette
  /// color derived from the name's hash code.
  static Color forGroup(String? groupName) {
    if (groupName == null || groupName.isEmpty) return _fallback;
    final lower = groupName.toLowerCase().trim();
    for (final entry in _map.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return _palette[groupName.hashCode.abs() % _palette.length];
  }

  static const Color _fallback = Color(0xFF607D8B);

  /// Keyword-based matching (case-insensitive substring).
  static const Map<String, Color> _map = {
    'activit': Color(0xFFFF8F00),      // orange   — Activités
    'investiss': Color(0xFF43A047),    // green    — Investissements
    'revenu': Color(0xFF1E88E5),       // blue     — Revenus
    'charge': Color(0xFFE53935),       // red      — Charges fixes
    'logement': Color(0xFF8E24AA),     // purple   — Logement
    'transport': Color(0xFF00897B),    // teal     — Transport
    'alimentation': Color(0xFFFB8C00), // amber    — Alimentation
    'sant': Color(0xFF26A69A),         // teal-green — Santé
    'loisir': Color(0xFF7E57C2),       // deep purple — Loisirs
    'épargne': Color(0xFF00ACC1),      // cyan     — Épargne
    'epargne': Color(0xFF00ACC1),      // alias without accent
    'dette': Color(0xFFD32F2F),        // dark red — Dettes
    'abonnement': Color(0xFF546E7A),   // blue grey — Abonnements
    'assurance': Color(0xFF78909C),    // grey blue — Assurances
    'impôt': Color(0xFF4E342E),        // brown    — Impôts
    'impot': Color(0xFF4E342E),        // alias without accent
    'tax': Color(0xFF4E342E),          // brown    — Taxes
    'formation': Color(0xFF0288D1),    // light blue — Formation
    'voyage': Color(0xFFEC407A),       // pink     — Voyages
    'enfant': Color(0xFFAB47BC),       // purple   — Enfants
    'tech': Color(0xFF039BE5),         // light blue — Tech
  };

  /// Deterministic fallback palette (selected by hash).
  static const List<Color> _palette = [
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFF8F00),
    Color(0xFFE53935),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFF546E7A),
    Color(0xFFEC407A),
    Color(0xFF0288D1),
    Color(0xFFAB47BC),
  ];
}
