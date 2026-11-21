import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../core/services/sync_queue.dart';
import '../../models/user_profile.dart';

/// Mirrors the user profile to the single-row Supabase `profiles` table
/// (row id `profile`). No-op (and never throws) when Supabase is not
/// configured.
class ProfileRepository {
  static const _table = 'profiles';
  static const _kRowId = 'profile';

  SupabaseClient? get _client => SupabaseService.instance.client;

  /// Returns the stored profile, or null when not configured / no row.
  Future<UserProfile?> load() async {
    final client = _client;
    if (client == null) return null;
    try {
      final rows = await client
          .from(_table)
          .select()
          .eq('id', _kRowId)
          .limit(1);
      if (rows.isEmpty) return null;
      final row = rows.first;
      return UserProfile(
        fullName: row['full_name'] as String? ?? '',
        email: row['email'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
        memberTier: row['member_tier'] as String? ?? 'Smart Saver',
        joinDate: row['join_date'] as String? ?? '',
        monthlyIncome: (row['monthly_income'] as num? ?? 0).toDouble(),
        occupation: row['occupation'] as String? ?? '',
        streakDays: (row['streak_days'] as num? ?? 0).toInt(),
        healthScore: (row['health_score'] as num? ?? 0).toInt(),
        biometricsEnabled: row['biometrics_enabled'] as bool? ?? false,
        appLockEnabled: row['app_lock_enabled'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(UserProfile u) async {
    final client = _client;
    if (client == null) {
      // Backend not reachable yet — remember the write for later.
      SyncQueue.instance.enqueueUpsert(_table, _toRow(u));
      return;
    }
    try {
      await client.from(_table).upsert(_toRow(u));
    } catch (_) {
      SyncQueue.instance.enqueueUpsert(_table, _toRow(u));
    }
  }

  Map<String, dynamic> _toRow(UserProfile u) => {
    'id': _kRowId,
    'full_name': u.fullName,
    'email': u.email,
    'phone': u.phone,
    'member_tier': u.memberTier,
    'join_date': u.joinDate,
    'monthly_income': u.monthlyIncome,
    'occupation': u.occupation,
    'streak_days': u.streakDays,
    'health_score': u.healthScore,
    'biometrics_enabled': u.biometricsEnabled,
    'app_lock_enabled': u.appLockEnabled,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}
