import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Central access point for the Supabase client.
///
/// Call [init] once from main() before runApp(). If the project is not
/// configured yet (placeholders untouched in SupabaseConfig) or the
/// connection fails, the service stays "not ready" and every repository
/// simply falls back to the existing local sample-data behaviour —
/// the app never crashes because of a missing or broken backend.
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _ready = false;

  /// True only after a successful Supabase.initialize with real values.
  bool get isReady => _ready;

  /// Non-null only when [isReady] — repositories must null-check this.
  SupabaseClient? get client => _ready ? Supabase.instance.client : null;

  Future<void> init() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        debug: false,
      );
      _ready = true;
    } catch (e) {
      // Keep the app fully usable in local mode when the backend is
      // unreachable or misconfigured.
      debugPrint('Supabase init failed, running in local mode: $e');
      _ready = false;
    }
  }
}
