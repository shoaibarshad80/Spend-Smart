import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/budget.dart';
import '../data/sample_data.dart';
import '../core/services/supabase_service.dart';
import '../data/repositories/budget_repository.dart';

class BudgetProvider extends ChangeNotifier {
  BudgetProvider() {
    _loadFromSupabase();
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

  Budget get budget => _budget;

  double get monthlyLimit => _budget.monthlyLimit;

  void updateBudget(double newLimit) {
    _budget = Budget(monthlyLimit: newLimit);
    unawaited(_repo.saveMonthlyLimit(newLimit));
    notifyListeners();
  }
}
