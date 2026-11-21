import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_colors.dart';
import 'providers/budget_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/income_provider.dart';
import 'providers/language_provider.dart';
import 'providers/lend_borrow_provider.dart';
import 'providers/notif_prefs_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';

/// App entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Connect to Supabase before the providers construct so they can load
  // cloud data right away. No-op while SupabaseConfig still holds the
  // placeholders — the app then runs fully on local sample data.
  await SupabaseService.instance.init();
  runApp(const _Providers());
}

class _Providers extends StatelessWidget {
  const _Providers();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => NotifPrefsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => IncomeProvider()),
        ChangeNotifierProvider(create: (_) => LendBorrowProvider()),
      ],
      child: Builder(
        builder: (context) {
          final theme = context.watch<ThemeProvider>();
          // While prefs are loading, render a plain splash-less placeholder
          // so we don't flash the wrong theme.
          if (!theme.isLoaded) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Material(
                color: AppColors.lightBackground,
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return const SpendSmartApp();
        },
      ),
    );
  }
}
