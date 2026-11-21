import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'sync_queue.dart';

/// Central access point for the Supabase client.
///
/// Call [init] once from main() before runApp(). If the project is not
/// configured yet (placeholders untouched in SupabaseConfig) or the
/// connection fails, the service stays "not ready" and every repository
/// simply falls back to the existing local sample-data behaviour —
/// the app never crashes because of a missing or broken backend.
///
/// Once ready it also:
/// - drains the offline [SyncQueue], replaying writes that were queued
///   while the backend was unreachable, and
/// - listens to Postgres changes on every mirrored table and publishes
///   the table name on [tableChanges], so providers can refresh live
///   when data changes from another device.
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _ready = false;

  /// True only after a successful Supabase.initialize with real values.
  bool get isReady => _ready;

  /// Non-null only when [isReady] — repositories must null-check this.
  SupabaseClient? get client => _ready ? Supabase.instance.client : null;

  /// Every mirrored table; the repositories own the same list of names.
  static const _watchedTables = [
    'expenses',
    'budgets',
    'goals',
    'income_entries',
    'ledger_entries',
    'profiles',
    'notifications',
  ];

  final StreamController<String> _tableChanges =
      StreamController<String>.broadcast();

  /// Emits the name of a table whenever its rows change in the cloud
  /// (from this device or any other). Providers listen and refresh.
  Stream<String> get tableChanges => _tableChanges.stream;

  Future<void> init() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        debug: false,
      );
      _ready = true;
      // Replay writes that were queued while the backend was down.
      unawaited(SyncQueue.instance.drain());
      _startRealtime();
    } catch (e) {
      // Keep the app fully usable in local mode when the backend is
      // unreachable or misconfigured.
      debugPrint('Supabase init failed, running in local mode: $e');
      _ready = false;
    }
  }

  /// Subscribes to Postgres changes for every watched table and
  /// publishes the affected table name on [tableChanges].
  /// Never throws — a broken realtime connection must not affect the
  /// app; repositories still sync on the next mutation.
  void _startRealtime() {
    try {
      final client = Supabase.instance.client;
      final channel = client.channel('spendsmart_sync');
      for (final table in _watchedTables) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (payload) {
            if (!_tableChanges.isClosed) _tableChanges.add(table);
          },
        );
      }
      channel.subscribe();
    } catch (e) {
      debugPrint('Realtime unavailable, continuing without live sync: $e');
    }
  }
}
