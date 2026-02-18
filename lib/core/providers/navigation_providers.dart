import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set before navigating to /journal to auto-select a transaction.
final pendingJournalTxIdProvider = StateProvider<String?>((ref) => null);

/// Set before navigating to /schedule to auto-select an invoice.
final pendingScheduleTxIdProvider = StateProvider<String?>((ref) => null);
