import 'dart:convert';

class SupabaseConfig {
  const SupabaseConfig(this.url, this.key);
  factory SupabaseConfig.environment() => const SupabaseConfig(
    String.fromEnvironment('SUPABASE_URL'),
    String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
    ),
  );
  final String url;
  final String key;

  String? get error {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.host.contains('YOUR_PROJECT') ||
        key.isEmpty) {
      return 'Thiếu cấu hình Supabase. Chạy ứng dụng với '
          '--dart-define-from-file=config/supabase.dev.json.';
    }
    if (key.startsWith('sb_publishable_') && key.length > 20) return null;
    try {
      final parts = key.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        if (payload is Map && payload['role'] == 'anon') return null;
      }
    } catch (_) {
      /* Invalid client key; never include it in an error. */
    }
    return 'Cấu hình chỉ chấp nhận publishable key hoặc anon key của Supabase.';
  }
}
