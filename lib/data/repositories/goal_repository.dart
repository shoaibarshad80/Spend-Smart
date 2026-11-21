import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../core/services/sync_queue.dart';
import '../../models/goal.dart';

/// Mirrors the savings goals to the Supabase `goals` table.
/// The IconData is stored as its numeric codepoint (MaterialIcons).
/// No-op (and never throws) when Supabase is not configured.
class GoalRepository {
  static const _table = 'goals';

  SupabaseClient? get _client => SupabaseService.instance.client;

  /// Loads all goals, oldest insert first (stable list order).
  Future<List<Goal>> loadAll() async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from(_table)
          .select()
          .order('created_at', ascending: true);
      return rows.map(_fromRow).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsert(Goal g) async {
    final client = _client;
    if (client == null) {
      // Backend not reachable yet — remember the write for later.
      SyncQueue.instance.enqueueUpsert(_table, _toRow(g));
      return;
    }
    try {
      await client.from(_table).upsert(_toRow(g));
    } catch (_) {
      SyncQueue.instance.enqueueUpsert(_table, _toRow(g));
    }
  }

  Future<void> delete(String id) async {
    final client = _client;
    if (client == null) {
      SyncQueue.instance.enqueueDelete(_table, id);
      return;
    }
    try {
      await client.from(_table).delete().eq('id', id);
    } catch (_) {
      SyncQueue.instance.enqueueDelete(_table, id);
    }
  }

  Map<String, dynamic> _toRow(Goal g) => {
    'id': g.id,
    'name': g.name,
    'icon_codepoint': g.icon.codePoint,
    'target_amount': g.targetAmount,
    'saved_amount': g.savedAmount,
    'monthly_saving': g.monthlySaving,
    'target_date': g.targetDate.toUtc().toIso8601String(),
  };

  Goal _fromRow(Map<String, dynamic> row) => Goal(
    id: row['id'] as String,
    name: row['name'] as String,
    icon: IconData(
      (row['icon_codepoint'] as num).toInt(),
      fontFamily: 'MaterialIcons',
    ),
    targetAmount: (row['target_amount'] as num).toDouble(),
    savedAmount: (row['saved_amount'] as num).toDouble(),
    monthlySaving: (row['monthly_saving'] as num).toDouble(),
    targetDate: DateTime.parse(row['target_date'] as String).toLocal(),
  );
}
