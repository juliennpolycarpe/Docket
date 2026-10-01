import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

// Calls to the Docket server (server/). Reading and editing tasks goes straight
// to Supabase; anything involving connected accounts goes through here.
class DocketApi {
  static Future<Map<String, dynamic>> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final request = http.Request(method, Uri.parse('${Config.serverUrl}$path'))
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    http.Response response;
    try {
      response = await http.Response.fromStream(await request.send()).timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw ApiException('The Docket server took too long to respond.');
    } catch (_) {
      throw ApiException("Couldn't reach the Docket server. Is it running?");
    }

    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(decoded['error'] as String? ?? 'Something went wrong (HTTP ${response.statusCode}).');
    }
    return decoded;
  }

  /// Connects Canvas and runs the first sync. Returns a warning if the account
  /// was saved but the first sync failed.
  static Future<String?> connectCanvas({required String baseUrl, required String token}) async {
    final result = await _send('POST', '/accounts/canvas', {'baseUrl': baseUrl, 'token': token});
    final sync = result['sync'] as Map<String, dynamic>?;
    return sync != null && sync['ok'] == false ? sync['error'] as String? : null;
  }

  static Future<void> disconnectAccount(String accountId) => _send('DELETE', '/accounts/$accountId');

  /// Syncs all connected accounts now. Returns the errors, if any.
  static Future<List<String>> syncNow() async {
    final result = await _send('POST', '/sync');
    return [
      for (final r in (result['results'] as List).cast<Map<String, dynamic>>())
        if (r['ok'] == false) r['error'] as String,
    ];
  }
}
