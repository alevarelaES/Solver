class TimeSeriesPoint {
  final String datetime;
  final double close;

  const TimeSeriesPoint({required this.datetime, required this.close});

  factory TimeSeriesPoint.fromJson(Map<String, dynamic> json) {
    final close = _toDouble(json['close']) ?? 0;
    return TimeSeriesPoint(
      datetime: (json['datetime'] ?? '').toString(),
      close: close,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
