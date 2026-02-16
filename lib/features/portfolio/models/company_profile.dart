class CompanyProfile {
  final String name;
  final String ticker;
  final String? exchange;
  final String? sector;
  final String? country;
  final String? currency;
  final double? marketCap;
  final String? logo;
  final DateTime? ipo;
  final String? webUrl;

  const CompanyProfile({
    required this.name,
    required this.ticker,
    required this.exchange,
    required this.sector,
    required this.country,
    required this.currency,
    required this.marketCap,
    required this.logo,
    required this.ipo,
    required this.webUrl,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      name: (json['name'] ?? '').toString(),
      ticker: (json['ticker'] ?? '').toString(),
      exchange: json['exchange'] as String?,
      sector: json['sector'] as String?,
      country: json['country'] as String?,
      currency: json['currency'] as String?,
      marketCap: _asDouble(json['marketCap']),
      logo: json['logo'] as String?,
      ipo: _asDate(json['ipo']),
      webUrl: json['webUrl'] as String?,
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _asDate(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
