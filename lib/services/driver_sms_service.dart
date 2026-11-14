import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DriverSmsService {
  static Object? displayStatus(Map<String, dynamic> record) {
    final stored = record['status'];
    if (stored != null) return stored; // Includes older records.
    final code = int.tryParse(record['httpStatus']?.toString() ?? '');
    return code != null && code >= 200 && code < 300 ? 'accepted' : null;
  }

  static Future<Map<String, dynamic>> request({
    Map<String, dynamic>? data,
    String? cursor,
    bool officeDirectory = false,
  }) async {
    const base = String.fromEnvironment('SMS_FUNCTION_BASE_URL');
    if (base.isEmpty && !kIsWeb) {
      throw StateError('Driver SMS needs the BAJ server URL in this build.');
    }
    final origin = base.isEmpty
        ? Uri.base.origin
        : base.replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse('$origin/.netlify/functions/driver-sms').replace(
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        if (officeDirectory) 'directory': 'office',
      },
    );
    if (uri.scheme != 'https' &&
        uri.host != 'localhost' &&
        uri.host != '127.0.0.1') {
      throw StateError('Driver SMS needs a secure server URL.');
    }
    final token = await FirebaseAuth.instance.currentUser?.getIdToken().timeout(
      const Duration(seconds: 10),
    );
    if (token == null) throw StateError('Sign in again to use driver SMS.');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final client = http.Client();
    try {
      final response =
          await (data == null
                  ? client.get(uri, headers: headers)
                  : client.post(uri, headers: headers, body: jsonEncode(data)))
              .timeout(const Duration(seconds: 35));
      Map<String, dynamic> result;
      try {
        result = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw StateError(
          'The SMS endpoint returned an unexpected response (HTTP '
          '${response.statusCode}). Check that the BAJ SMS function is deployed.',
        );
      }
      if (response.statusCode != 200) {
        final reason =
            result['error']?.toString() ?? 'Driver SMS is unavailable.';
        if (response.statusCode < 500) throw SmsRejected(reason);
        throw StateError(reason);
      }
      return result;
    } finally {
      client.close();
    }
  }
}

class SmsRejected extends StateError {
  SmsRejected(super.message);
}
