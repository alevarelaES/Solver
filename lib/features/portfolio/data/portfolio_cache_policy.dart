class TimedCacheEntry<T> {
  final T value;
  final DateTime storedAt;

  const TimedCacheEntry({required this.value, required this.storedAt});
}

bool isCacheFresh<T>(TimedCacheEntry<T>? entry, Duration ttl, {DateTime? now}) {
  if (entry == null) return false;
  final current = now ?? DateTime.now();
  return current.difference(entry.storedAt) <= ttl;
}

bool isCacheUsable<T>(
  TimedCacheEntry<T>? entry,
  Duration maxAge, {
  DateTime? now,
}) {
  if (entry == null) return false;
  final current = now ?? DateTime.now();
  return current.difference(entry.storedAt) <= maxAge;
}
