import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../data/sample_data.dart';
import '../core/services/supabase_service.dart';
import '../data/repositories/notification_repository.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider() {
    _loadFromSupabase();
    _listenRemote();
  }

  List<AppNotification> _items = List.of(SampleData.notifications);

  List<AppNotification> get items => List.unmodifiable(_items);

  // ---------- Supabase sync ----------
  final NotificationRepository _repo = NotificationRepository();

  /// Replaces the sample notifications with cloud rows once Supabase is
  /// ready. An empty cloud table keeps the built-in sample data.
  Future<void> _loadFromSupabase() async {
    if (!SupabaseService.instance.isReady) return;
    final rows = await _repo.loadAll();
    if (rows.isNotEmpty) {
      _items = rows;
      notifyListeners();
    }
  }

  // ---------- Live sync (Supabase Realtime) ----------
  StreamSubscription<String>? _remoteSub;
  Timer? _reloadDebounce;

  /// Refreshes this provider whenever its cloud table changes — edits
  /// made on another device show up here live.
  void _listenRemote() {
    if (!SupabaseService.instance.isReady) return;
    _remoteSub = SupabaseService.instance.tableChanges
        .where((table) => table == 'notifications')
        .listen((_) => _scheduleRemoteReload());
  }

  /// Coalesces bursts of change events into a single reload so a run of
  /// cloud updates only triggers one refresh.
  void _scheduleRemoteReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_loadFromSupabase());
    });
  }

  int get unreadCount => _items.where((n) => !n.isRead).length;

  void markAllRead() {
    _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    unawaited(_repo.markAllRead());
    notifyListeners();
  }

  void markRead(String id) {
    final i = _items.indexWhere((n) => n.id == id);
    if (i >= 0 && !_items[i].isRead) {
      _items[i] = _items[i].copyWith(isRead: true);
      unawaited(_repo.markRead(id));
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    _reloadDebounce?.cancel();
    super.dispose();
  }
}
