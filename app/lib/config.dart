// Settings are passed in at build time from config.json:
//   flutter run --dart-define-from-file=config.json
// See config.example.json.
class Config {
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const serverUrl = String.fromEnvironment('DOCKET_SERVER_URL', defaultValue: 'http://localhost:8787');

  // Supabase shows the URL with /rest/v1/ in some places; the client wants just the origin.
  static String get supabaseUrl => _supabaseUrl.isEmpty ? '' : Uri.parse(_supabaseUrl).origin;

  static bool get isComplete => _supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
