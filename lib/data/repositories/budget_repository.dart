import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';

/// Mirrors the monthly budget to the single-row Supabase `budgets` table.
/// No-op (and never throws) when Supabase is not configured.
class BudgetRepository {
  static const _table = 'budgets';

  SupabaseClient? get _client => SupabaseService.instance.client;

  /// Returns the stored monthly limit, or null when not configured /
  /// no row exists yet (the provider then keeps its sample value).
  Future<double?> loadMonthlyLimit() async {
    final client = _client;
    if (client == null) return null;
    try {
      final rows = await client.from(_table).select().eq('id', 1).limit(1);
      if (rows.isEmpty) return null;
      return (rows.first['monthly_limit'] as num).toDouble();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMonthlyLimit(double limit) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from(_table).upsert({'id': 1, 'monthly_limit': limit});
    } catch (_) {}
  }
}
