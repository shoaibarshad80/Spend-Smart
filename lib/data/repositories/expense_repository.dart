import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/expense.dart';

/// Mirrors the expense list to the Supabase `expenses` table.
/// Every method is a no-op (and never throws) when Supabase is not
/// configured, so the provider can call it fire-and-forget.
class ExpenseRepository {
  static const _table = 'expenses';

  SupabaseClient? get _client => SupabaseService.instance.client;

  /// Loads all expenses, newest first. Empty list when not configured.
  Future<List<Expense>> loadAll() async {
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

  Future<void> upsert(Expense e) async {
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

  Map<String, dynamic> _toRow(Expense e) => {
    'id': e.id,
    'title': e.title,
    'amount': e.amount,
    'category_id': e.categoryId,
    'date': e.date.toUtc().toIso8601String(),
    'note': e.note,
  };

  Expense _fromRow(Map<String, dynamic> row) => Expense(
    id: row['id'] as String,
    title: row['title'] as String,
    amount: (row['amount'] as num).toDouble(),
    categoryId: row['category_id'] as String,
    date: DateTime.parse(row['date'] as String).toLocal(),
    note: row['note'] as String?,
  );
}
