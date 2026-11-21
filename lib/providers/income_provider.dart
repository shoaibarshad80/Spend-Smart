import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/supabase_service.dart';
import '../data/repositories/income_repository.dart';
import '../data/sample_data.dart';
import '../models/income_entry.dart';

/// Tracks both income kinds:
/// 1. Job income — a fixed monthly salary (single value).
/// 2. Other earnings — one-off/random income entries (freelance, gifts...).
///
/// Everything is persisted to SharedPreferences so the module survives
/// app restarts, like the rest of the app's providers.
class IncomeProvider extends ChangeNotifier {
  static const _kJobIncome = 'income_job_monthly';
  static const _kEarnings = 'income_other_entries';

  double _jobIncome = SampleData.user.monthlyIncome;
  List<IncomeEntry> _earnings = [
    IncomeEntry(
      id: 'inc-sample-1',
      source: 'Freelance project',
      amount: 15000,
      date: DateTime.now().subtract(const Duration(days: 3)),
    ),
    IncomeEntry(
      id: 'inc-sample-2',
      source: 'Birthday gift',
      amount: 5000,
      date: DateTime.now().subtract(const Duration(days: 10)),
    ),
    IncomeEntry(
      id: 'inc-sample-3',
      source: 'Cashback reward',
      amount: 1200,
      date: DateTime.now().subtract(const Duration(days: 15)),
    ),
  ];

  IncomeProvider() {
    // Prefer cloud data when Supabase is configured; otherwise keep the
    // existing SharedPreferences behaviour.
    if (SupabaseService.instance.isReady) {
      _loadFromSupabase();
    } else {
      _loadFromPrefs();
    }
    _listenRemote();
  }

  // ---------- Supabase sync ----------
  final IncomeRepository _repo = IncomeRepository();

  /// Replaces the prefs-backed values with cloud rows once Supabase is
  /// ready. Empty cloud values keep the current local state.
  Future<void> _loadFromSupabase() async {
    final snap = await _repo.loadAll();
    if (snap == null) return;
    if (snap.jobIncome > 0) _jobIncome = snap.jobIncome;
    if (snap.earnings.isNotEmpty) _earnings = snap.earnings;
    notifyListeners();
  }

  // ---------- Live sync (Supabase Realtime) ----------
  StreamSubscription<String>? _remoteSub;
  Timer? _reloadDebounce;

  /// Refreshes this provider whenever its cloud table changes — edits
  /// made on another device show up here live.
  void _listenRemote() {
    if (!SupabaseService.instance.isReady) return;
    _remoteSub = SupabaseService.instance.tableChanges
        .where((table) => table == 'income_entries')
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

  double get jobIncome => _jobIncome;

  /// One-off earnings, newest first.
  List<IncomeEntry> get earnings {
    final sorted = List<IncomeEntry>.of(_earnings)
      ..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(sorted);
  }

  /// Sum of one-off earnings received in [month] (defaults to this month).
  double otherEarningsIn([DateTime? month]) {
    final m = month ?? DateTime.now();
    return _earnings
        .where((e) => e.date.year == m.year && e.date.month == m.month)
        .fold(0.0, (s, e) => s + e.amount);
  }

  /// Total income for a month = job salary + one-off earnings of that month.
  double totalIn([DateTime? month]) => _jobIncome + otherEarningsIn(month);

  double get totalOtherEarnings =>
      _earnings.fold(0.0, (s, e) => s + e.amount);

  void setJobIncome(double value) {
    if (_jobIncome == value) return;
    _jobIncome = value;
    _saveToPrefs();
    unawaited(_repo.saveJobIncome(value));
    notifyListeners();
  }

  void addEarning(String source, double amount, [DateTime? date]) {
    final entry = IncomeEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      source: source.trim().isEmpty ? 'Other earning' : source.trim(),
      amount: amount,
      date: date ?? DateTime.now(),
    );
    _earnings.insert(0, entry);
    _saveToPrefs();
    unawaited(_repo.upsert(entry));
    notifyListeners();
  }

  void deleteEarning(String id) {
    _earnings.removeWhere((e) => e.id == id);
    _saveToPrefs();
    unawaited(_repo.delete(id));
    notifyListeners();
  }

  /// Re-inserts an existing entry (used by the UNDO snackbar after a
  /// delete — keeps the original id, type and date intact).
  void restoreEarning(IncomeEntry entry) {
    if (_earnings.any((e) => e.id == entry.id)) return;
    _earnings.insert(0, entry);
    _saveToPrefs();
    unawaited(_repo.upsert(entry));
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final job = prefs.getDouble(_kJobIncome);
      if (job != null) _jobIncome = job;
      final raw = prefs.getString(_kEarnings);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .map((e) => IncomeEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) _earnings = list;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kJobIncome, _jobIncome);
      await prefs.setString(
          _kEarnings, jsonEncode(_earnings.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    _reloadDebounce?.cancel();
    super.dispose();
  }
}
