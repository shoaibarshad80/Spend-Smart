/// Supabase connection settings for SpendSmart.
///
/// Two ways to provide the values:
/// 1. Paste your project URL and anon key directly over the two
///    placeholders below (Dashboard → Project Settings → API).
/// 2. Pass them at build time instead:
///    flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// The anon key is safe to ship in a web build as long as Row Level
/// Security is enabled on every table — see supabase/schema.sql.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  /// True only when both values are real. While the placeholders above
  /// are untouched the app keeps running in local sample-data mode.
  static bool get isConfigured =>
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      !url.startsWith('YOUR_') &&
      !anonKey.startsWith('YOUR_');
}
