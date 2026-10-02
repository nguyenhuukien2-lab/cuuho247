import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Temporary submit diagnostics. Never print request bodies or raw headers.
/// Debug-only so phone release/profile builds do not emit these diagnostics.
void logRequestStep(String step) {
  if (!kDebugMode) return;
  try {
    debugPrint('[rescue-submit] $step');
  } catch (_) {
    // Diagnostics cannot interrupt submit.
  }
}

void logRequestFailure(String step, Object error, StackTrace stackTrace,
    {SupabaseClient? client, Iterable<String?> sensitiveValues = const []}) {
  if (!kDebugMode) return;
  // Diagnostics must not replace the original exception or break upload retry.
  try {
    final secrets = <String?>[
      ...sensitiveValues,
      const String.fromEnvironment('SUPABASE_URL'),
      const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      const String.fromEnvironment('SUPABASE_ANON_KEY'),
      const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY'),
      client?.headers['apikey'],
      client?.auth.headers['apikey'],
      client?.auth.currentSession?.accessToken,
      client?.auth.currentSession?.refreshToken,
    ];
    Object? message;
    Object? status;
    Object? code;
    Object? details;
    Object? hint;
    if (error is PostgrestException) {
      message = error.message;
      code = error.code;
      details = error.details;
      hint = error.hint;
      // The installed Postgrest SDK does not expose HTTP status on exceptions.
    } else if (error is StorageException) {
      message = error.message;
      status = error.statusCode;
      code = error.error;
    } else if (error is AuthException) {
      message = error.message;
      status = error.statusCode;
      code = error.code;
    } else if (error is http.ClientException) {
      message = error.message; // Omit its URI.
    } else if (error is TimeoutException) {
      message = error.message;
    } else if (error is FormatException) {
      message = error.message; // Omit its source (may contain response data).
    } else {
      message = error.toString();
    }
    final fields = <String, Object?>{
      'runtimeType': error.runtimeType,
      'exception': '${error.runtimeType}: $message',
      'message': message,
      'status': status,
      'code': code,
      'details': details,
      'hint': hint,
      'stackTrace': stackTrace,
    };
    debugPrint('[rescue-submit] $step FAILED');
    for (final field in fields.entries) {
      debugPrint('[rescue-submit] ${field.key}: '
          '${redactRequestDebugValue(field.value, secrets: secrets)}');
    }
  } catch (_) {
    // Do not print the logging error: it could include the original secret.
  }
}

@visibleForTesting
String redactRequestDebugValue(Object? value,
    {Iterable<String?> secrets = const []}) {
  if (value == null) return '<not provided>';
  if (value is Map) {
    return '{${value.entries.map((entry) {
      final key = entry.key.toString();
      final text = _sensitiveKey.hasMatch(key)
          ? '<redacted>'
          : redactRequestDebugValue(entry.value, secrets: secrets);
      return '${redactRequestDebugValue(key, secrets: secrets)}: $text';
    }).join(', ')}}';
  }
  if (value is Iterable) {
    return '[${value.map((item) => redactRequestDebugValue(item, secrets: secrets)).join(', ')}]';
  }
  var text = value.toString();
  for (final secret in secrets) {
    if (secret != null && secret.isNotEmpty) {
      text = text.replaceAll(secret, '<redacted>');
    }
  }
  text = text.replaceAll(_url, '<redacted-url>');
  text = text.replaceAll(_bearer, 'Bearer <redacted>');
  text = text.replaceAll(_jwt, '<redacted>');
  text = text.replaceAll(_supabaseKey, '<redacted>');
  return text.replaceAllMapped(
      _credentialAssignment, (match) => '${match.group(1)}<redacted>');
}

final _sensitiveKey = RegExp(
    r'authorization|api[_-]?key|supabase.*(?:url|key)|token|password|passwd|secret|phone|email|address|location|contact|description',
    caseSensitive: false);
final _url = RegExp(r'''https?://[^\s"'<>]+''', caseSensitive: false);
final _bearer = RegExp(r'''\bBearer\s+[^\s,"'<>;]+''', caseSensitive: false);
final _jwt = RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b');
final _supabaseKey = RegExp(r'\bsb_(?:publishable|secret)_[A-Za-z0-9_-]+\b');
final _credentialAssignment = RegExp(
    r'''(["']?(?:authorization|api[_-]?key|supabase[_-]?(?:url|publishable[_-]?key|anon[_-]?key|service[_-]?role[_-]?key)|(?:access[_-]?|refresh[_-]?)?token|password|passwd|secret)["']?\s*[:=]\s*)(?:"[^"\r\n]*"|'[^'\r\n]*'|[^\s,;}\]\r\n]+)''',
    caseSensitive: false);
