class AnalysisPeerFallbackItem {
  final String title;
  final String subtitle;
  final String percent;
  final bool isOptimal;
  final double barValue;

  const AnalysisPeerFallbackItem({
    required this.title,
    required this.subtitle,
    required this.percent,
    required this.isOptimal,
    required this.barValue,
  });
}

const analysisPeerFallbackItems = <AnalysisPeerFallbackItem>[
  AnalysisPeerFallbackItem(
    title: 'Variable Food',
    subtitle: 'Vs. 2.4k median peers',
    percent: '-12.4%',
    isOptimal: true,
    barValue: 0.30,
  ),
  AnalysisPeerFallbackItem(
    title: 'Transport Costs',
    subtitle: 'Vs. 1.8k median peers',
    percent: '+5.8%',
    isOptimal: false,
    barValue: 0.65,
  ),
  AnalysisPeerFallbackItem(
    title: 'Fixed Utilities',
    subtitle: 'Vs. 0.9k median peers',
    percent: '-8.2%',
    isOptimal: true,
    barValue: 0.40,
  ),
];
