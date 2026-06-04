import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// API base URL per platform. Persist override for physical devices on LAN.
class AppConfig {
  static const _hostKey = 'api_host';
  static String? _hostOverride;

  static Future<void> loadSavedHost() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_hostKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _hostOverride = _normalizeHost(saved.trim());
    }
  }

  static Future<void> saveHost(String host) async {
    final normalized = _normalizeHost(host.trim());
    _hostOverride = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, normalized);
  }

  static Future<void> clearHostOverride() async {
    _hostOverride = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hostKey);
  }

  static String _normalizeHost(String input) {
    var h = input;
    if (!h.startsWith('http://') && !h.startsWith('https://')) {
      h = 'http://$h';
    }
    return h.endsWith('/') ? h.substring(0, h.length - 1) : h;
  }

  static void setHostOverride(String? host) {
    _hostOverride = host?.trim().isEmpty == true ? null : _normalizeHost(host!.trim());
  }

  static String get host {
    if (_hostOverride != null) return _hostOverride!;
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  static String get apiBaseUrl => '$host/api';

  static const Duration requestTimeout = Duration(seconds: 30);
  static const int defaultPageSize = 20;

  /// Hint shown on physical devices — emulator alias won't work on a real phone.
  static String get defaultPhysicalDeviceHint {
    return 'http://YOUR_PC_IP:8000';
  }
}
