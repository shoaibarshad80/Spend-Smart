import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/income_entry.dart';

/// Job income + one-off earnings loaded together from Supabase.
class IncomeSnapshot {
  final double jobIncome;
  final List<IncomeEntry> earnings;

  const IncomeSnapshot({required this.jobIncome, required this.earnings});
}

/// Mirrors income data to the Supabase `income_entries` table.
/// The job salary lives in one row of type 'job' (id `job-monthly`);
/// one-off earnings are normal rows of type 'other'.
/// No-op (and never throws) when Supabase is not configured.
class IncomeRepository {
  static const _table = 'income_entries';
  static const _kJobRowId = 'job-monthly';

  SupabaseClient? get _client => SupabaseService.instance.client;

  /// Returns null when not configured or the table is empty — the
  /// provider then keeps its sample / prefs data.
  Future<IncomeSnapshot?> loadAll() async {
    final client = _client;
    if (client == null) return null;
    try {
      final rows = await client
          .from(_table)
          .select()
          .order('date', ascending: false);
      double job = 0;
      final earnings = <IncomeEntry>[];
      for (final row in rows) {
        final entry = _fromRow(row);
        if (entry.type == IncomeType.job) {
          job = entry.amount;
        } else {
          earnings.add(entry);
        }
      }
      if (job == 0 && earnings.isEmpty) return null;
      return IncomeSnapshot(jobIncome: job, earnings: earnings);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveJobIncome(double value) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from(_table).upsert({
        'id': _kJobRowId,
        'source': 'Job salary',
        'amount': value,
        'date': DateTime.now().toUtc().toIso8601String(),
        'type': 'job',
      });
    } catch (_) {}
  }

  Future<void> upsert(IncomeEntry e) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from(_table).upsert(_toRow(e));
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    final client = _client;
    if (client == null) return;
    if (id == _kJobRowId) return; // job row is managed via saveJobIncome
    try {
      await client.from(_table).delete().eq('id', id);
    } catch (_) {}
  }

  Map<String, dynamic> _toRow(IncomeEntry e) => {
    'id': e.id,
    'source': e.source,
    'amount': e.amount,
    'date': e.date.toUtc().toIso8601String(),
    'type': e.type.name,
  };

  IncomeEntry _fromRow(Map<String, dynamic> row) => IncomeEntry(
    id: row['id'] as String,
    source: row['source'] as String,
    amount: (row['amount'] as num).toDouble(),
    date: DateTime.parse(row['date'] as String).toLocal(),
    type: IncomeType.values.firstWhere(
      (t) => t.name == row['type'],
      orElse: () => IncomeType.other,
    ),
  );
}
