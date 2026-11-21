import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/budget.dart';
import '../data/sample_data.dart';
import '../core/services/supabase_service.dart';
import '../data/repositories/budget_repository.dart';

class BudgetProvider extends ChangeNotifier {
  BudgetProvider() {
    _loadFromSupabase();
    _listenRemote();
  }

  Budget _budget = SampleData.budget;

  // ---------- Supabase sync ----------
  final BudgetRepository _repo = BudgetRepository();

  /// Picks up the stored monthly limit once Supabase is ready.
  Future<void> _loadFromSupabase() async {
    if (!SupabaseService.instance.isReady) return;
    final limit = await _repo.loadMonthlyLimit();
    if (limit != null) {
      _budget = Budget(monthlyLimit: limit);
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
        .where((table) => table == 'budgets')
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

  Budget get budget => _budget;

  double get monthlyLimit => _budget.monthlyLimit;

  void updateBudget(double newLimit) {
    _budget = Budget(monthlyLimit: newLimit);
    unawaited(_repo.saveMonthlyLimit(newLimit));
    notifyListeners();
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    _reloadDebounce?.cancel();
    super.dispose();
  }
}
