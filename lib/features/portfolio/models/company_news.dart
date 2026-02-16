class CompanyNews {
  final String headline;
  final String? summary;
  final String? source;
  final String? url;
  final String? image;
  final DateTime? datetime;

  const CompanyNews({
    required this.headline,
    required this.summary,
    required this.source,
    required this.url,
    required this.image,
    required this.datetime,
  });

  factory CompanyNews.fromJson(Map<String, dynamic> json) {
    return CompanyNews(
      headline: (json['headline'] ?? '').toString(),
      summary: json['summary'] as String?,
      source: json['source'] as String?,
      url: json['url'] as String?,
      image: json['image'] as String?,
      datetime: _asDate(json['datetime']),
    );
  }

  static DateTime? _asDate(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
