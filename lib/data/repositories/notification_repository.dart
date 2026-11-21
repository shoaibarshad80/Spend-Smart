import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/app_notification.dart';

/// Mirrors notifications (and their read state) to the Supabase
/// `notifications` table. IconData and Color are stored as their
/// numeric codepoint / value. No-op (and never throws) when Supabase
/// is not configured.
class NotificationRepository {
  static const _table = 'notifications';

  SupabaseClient? get _client => SupabaseService.instance.client;

  /// Loads all notifications, newest first. Empty list when not configured.
  Future<List<AppNotification>> loadAll() async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from(_table)
          .select()
          .order('created_at', ascending: false);
      return rows.map(_fromRow).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsert(AppNotification n) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from(_table).upsert(_toRow(n));
    } catch (_) {}
  }

  /// Marks one notification read by id.
  Future<void> markRead(String id) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from(_table).update({'is_read': true}).eq('id', id);
    } catch (_) {}
  }

  /// Marks every stored notification read in one statement.
  Future<void> markAllRead() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from(_table).update({'is_read': true}).eq('is_read', false);
    } catch (_) {}
  }

  Map<String, dynamic> _toRow(AppNotification n) => {
    'id': n.id,
    'type': n.type.name,
    'title': n.title,
    'body': n.body,
    'time_ago': n.timeAgo,
    'icon_codepoint': n.icon.codePoint,
    'color_value': n.color.value,
    'is_read': n.isRead,
  };

  AppNotification _fromRow(Map<String, dynamic> row) => AppNotification(
    id: row['id'] as String,
    type: NotificationType.values.firstWhere(
      (t) => t.name == row['type'],
      orElse: () => NotificationType.alert,
    ),
    title: row['title'] as String,
    body: row['body'] as String? ?? '',
    timeAgo: row['time_ago'] as String? ?? '',
    icon: IconData(
      (row['icon_codepoint'] as num).toInt(),
      fontFamily: 'MaterialIcons',
    ),
    color: Color((row['color_value'] as num).toInt()),
    isRead: row['is_read'] as bool? ?? false,
  );
}
