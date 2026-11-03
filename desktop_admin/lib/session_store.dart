import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hrms_core/hrms_core.dart';

class SessionStore {
  static const _key = 'session';
  final _storage = const FlutterSecureStorage();

  Future<LoginResult?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      return LoginResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // unreadable or corrupted: treat as signed out
    }
  }

  Future<void> save(LoginResult result) =>
      _storage.write(key: _key, value: jsonEncode(result.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}