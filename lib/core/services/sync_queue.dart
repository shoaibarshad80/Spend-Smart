import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Offline safety net for cloud writes.
///
/// When a repository write cannot reach Supabase (backend down, device
/// offline, app started before the network is ready) the operation is
/// stored here as JSON in SharedPreferences and replayed — oldest first —
/// as soon as the backend answers again. The queue survives app restarts.
///
/// The queue is only active when Supabase credentials are configured:
/// in local demo mode there is no backend to sync to, so nothing is
/// ever queued.
///
/// Behaviour notes:
/// - A newer queued operation for the same table + target replaces the
///   older one, so replaying never applies stale payloads.
/// - A drain pass stops at the first failing operation and keeps the
///   remaining ones for the next attempt (order is preserved).
/// - An operation that keeps failing is dropped after [_maxAttempts]
///   tries so it cannot block the queue forever.
class SyncQueue {
  SyncQueue._();

  static final SyncQueue instance = SyncQueue._();

  static const _prefsKey = 'spendsmart_sync_queue_v1';
  static const _maxOps = 200;
  static const _maxAttempts = 5;

  final List<Map<String, dynamic>> _ops = <Map<String, dynamic>>[];
  bool _restored = false;
  bool _draining = false;

  /// Number of writes waiting to reach the cloud.
  int get pendingCount => _ops.length;

  /// True while a drain pass is replaying queued operations.
  bool get isDraining => _draining;

  /// The client once Supabase is initialized, null otherwise (including
  /// demo mode). Kept local so this file has no dependency on
  /// [SupabaseService] and no import cycle can appear.
  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null; // Supabase.initialize() has not completed yet.
    }
  }

  // ---------- enqueue ----------

  /// Queues an upsert of [row] into [table].
  void enqueueUpsert(String table, Map<String, dynamic> row) {
    _enqueue({'kind': 'upsert', 'table': table, 'row': row, 'key': row['id']});
  }

  /// Queues a delete of the row with [id] from [table].
  void enqueueDelete(String table, String id) {
    _enqueue({'kind': 'delete', 'table': table, 'key': id});
  }

  /// Queues a patch of the row with [id] inside [table].
  void enqueueUpdate(String table, String id, Map<String, dynamic> values) {
    _enqueue({'kind': 'update', 'table': table, 'values': values, 'key': id});
  }

  /// Queues a patch of every row where [column] == [value].
  void enqueueUpdateWhere(
    String table,
    String column,
    dynamic value,
    Map<String, dynamic> values,
  ) {
    _enqueue({
      'kind': 'update',
      'table': table,
      'values': values,
      'match_column': column,
      'match_value': value,
      // Not a row id — used only for de-duplication of this kind.
      'key': '$column=$value',
    });
  }

  void _enqueue(Map<String, dynamic> op) {
    if (!SupabaseConfig.isConfigured) return; // demo mode: nothing to queue
    // Newest payload wins: replace an older queued op with the same
    // table + kind + target instead of replaying both.
    final i = _ops.indexWhere(
      (o) =>
          o['table'] == op['table'] &&
          o['kind'] == op['kind'] &&
          o['key'] == op['key'],
    );
    if (i >= 0) {
      _ops[i] = op;
    } else {
      _ops.add(op);
      if (_ops.length > _maxOps) _ops.removeAt(0);
    }
    unawaited(_persist());
    // Try to flush immediately — this is instant when we are online and
    // a no-op when the backend is still unreachable.
    unawaited(drain());
  }

  // ---------- replay ----------

  /// Replays all queued operations oldest-first. Stops at the first
  /// failing operation and resumes from there on the next attempt.
  /// Safe to call any number of times — concurrent calls coalesce.
  Future<void> drain() async {
    if (_draining) return;
    if (!_restored) await _restore();
    final client = _client;
    if (client == null) return; // backend not reachable yet
    if (_ops.isEmpty) return;
    _draining = true;
    var stopped = false;
    while (_ops.isNotEmpty && !stopped) {
      final op = _ops.first;
      try {
        await _run(client, op);
        _ops.removeAt(0);
        await _persist();
      } catch (_) {
        // Backend still unreachable or the op was rejected — keep the
        // remaining operations queued for the next attempt.
        final tries = ((op['attempts'] as num?) ?? 0).toInt() + 1;
        op['attempts'] = tries;
        if (tries >= _maxAttempts) {
          // Give up on this op so it cannot block the queue forever.
          _ops.removeAt(0);
        }
        await _persist();
        stopped = true;
      }
    }
    _draining = false;
  }

  Future<void> _run(SupabaseClient client, Map<String, dynamic> op) async {
    final table = op['table'] as String;
    final kind = op['kind'] as String;
    if (kind == 'upsert') {
      await client
          .from(table)
          .upsert((op['row'] as Map).cast<String, dynamic>());
    } else if (kind == 'update') {
      await client
          .from(table)
          .update((op['values'] as Map).cast<String, dynamic>())
          .eq(
            op['match_column'] as String? ?? 'id',
            op['match_value'] ?? op['key'],
          );
    } else if (kind == 'delete') {
      await client.from(table).delete().eq('id', op['key']);
    }
  }

  // ---------- persistence ----------

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_ops));
    } catch (_) {
      // Persistence is best-effort; the in-memory queue keeps working.
    }
  }

  Future<void> _restore() async {
    _restored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _ops
        ..clear()
        ..addAll(decoded.whereType<Map<String, dynamic>>());
    } catch (_) {
      // Corrupt queue file — start with an empty queue.
    }
  }
}
