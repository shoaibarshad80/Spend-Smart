import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/ledger_entry.dart';

/// Mirrors the Lend & Borrow ledger to the Supabase `ledger_entries` table.
/// No-op (and never throws) when Supabase is not configured.
class LedgerRepository {
  static const _table = 'ledger_entries';

  SupabaseClient? get _client => SupabaseService.instance.client;

  /// Loads all entries, newest first. Empty list when not configured.
  Future<List<LedgerEntry>> loadAll() async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from(_table)
          .select()
          .order('date', ascending: false);
      return rows.map(_fromRow).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsert(LedgerEntry e) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from(_table).upsert(_toRow(e));
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from(_table).delete().eq('id', id);
    } catch (_) {}
  }

  Map<String, dynamic> _toRow(LedgerEntry e) => {
    'id': e.id,
    'person': e.person,
    'amount': e.amount,
    'note': e.note,
    'date': e.date.toUtc().toIso8601String(),
    'direction': e.direction.name,
    'settled': e.settled,
    'settled_date': e.settledDate?.toUtc().toIso8601String(),
  };

  LedgerEntry _fromRow(Map<String, dynamic> row) => LedgerEntry(
    id: row['id'] as String,
    person: row['person'] as String,
    amount: (row['amount'] as num).toDouble(),
    note: row['note'] as String? ?? '',
    date: DateTime.parse(row['date'] as String).toLocal(),
    direction: LedgerDirection.values.firstWhere(
      (d) => d.name == row['direction'],
      orElse: () => LedgerDirection.given,
    ),
    settled: row['settled'] as bool? ?? false,
    settledDate: row['settled_date'] == null
        ? null
        : DateTime.parse(row['settled_date'] as String).toLocal(),
  );
}
