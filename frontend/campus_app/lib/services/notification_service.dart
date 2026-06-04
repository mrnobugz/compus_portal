import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Local notifications for new campus announcements (works on physical devices).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Timer? _pollTimer;
  static const _seenKey = 'seen_announcement_ids';
  static const _initKey = 'announcements_baseline_done';
  static const _supportNotifyPrefix = 'support_notify_';

  static const _supportChannel = AndroidNotificationChannel(
    'campus_support',
    'Support Desk',
    description: 'Replies from campus support staff',
    importance: Importance.high,
  );

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));

    const channel = AndroidNotificationChannel(
      'campus_announcements',
      'Campus Announcements',
      description: 'Alerts for new campus announcements',
      importance: Importance.high,
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(channel);
    await androidImpl?.createNotificationChannel(_supportChannel);

    await _requestPermission();
  }

  static Future<void> _requestPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied || status.isLimited) {
      await Permission.notification.request();
    }
  }

  static Future<void> startPolling() async {
    _pollTimer?.cancel();
    await checkForNewAnnouncements();
    await checkForSupportResponses();
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await checkForNewAnnouncements();
      await checkForSupportResponses();
    });
  }

  static void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  static Future<void> checkForNewAnnouncements() async {
    final token = await ApiService.getToken();
    if (token == null) return;

    final announcements = await ApiService.getAnnouncements();
    if (announcements.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final baselineDone = prefs.getBool(_initKey) ?? false;
    final seen =
        prefs
            .getStringList(_seenKey)
            ?.map(int.tryParse)
            .whereType<int>()
            .toSet() ??
        {};

    if (!baselineDone) {
      for (final a in announcements) {
        final id = a['id'] as int?;
        if (id != null) seen.add(id);
      }
      await prefs.setBool(_initKey, true);
      await prefs.setStringList(
        _seenKey,
        seen.map((e) => e.toString()).toList(),
      );
      return;
    }

    var changed = false;
    for (final a in announcements) {
      final id = a['id'] as int?;
      if (id == null || seen.contains(id)) continue;

      await _showNotification(
        id: id,
        title: a['title']?.toString() ?? 'New announcement',
        body: a['body']?.toString() ?? '',
        urgent: a['priority']?.toString() == 'urgent',
      );
      seen.add(id);
      changed = true;
    }

    if (changed) {
      await prefs.setStringList(
        _seenKey,
        seen.map((e) => e.toString()).toList(),
      );
    }
  }

  static Future<void> checkForSupportResponses() async {
    final token = await ApiService.getToken();
    if (token == null) return;

    final requests = await ApiService.getSupportRequests(page: 1, pageSize: 50);
    if (requests.results.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    for (final ticket in requests.results) {
      final id = ticket['id'] as int?;
      final respondedAt = ticket['responded_at']?.toString();
      final hasResponse = ticket['has_staff_response'] == true;
      if (id == null || !hasResponse || respondedAt == null) continue;

      final notifyKey = '$_supportNotifyPrefix$id';
      final lastNotified = prefs.getString(notifyKey);
      if (lastNotified == respondedAt) continue;

      final subject = ticket['subject']?.toString() ?? 'Support request';
      final preview = ticket['staff_response']?.toString() ?? '';
      await _showSupportNotification(
        id: id,
        title: 'Support reply: $subject',
        body: preview,
      );
      await prefs.setString(notifyKey, respondedAt);
    }
  }

  static Future<void> _showSupportNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _supportChannel.id,
        _supportChannel.name,
        channelDescription: _supportChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(
      100000 + id,
      title,
      body.length > 180 ? '${body.substring(0, 177)}…' : body,
      details,
    );
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    bool urgent = false,
  }) async {
    const channel = AndroidNotificationChannel(
      'campus_announcements',
      'Campus Announcements',
      description: 'Alerts for new campus announcements',
      importance: Importance.high,
    );

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: urgent ? Importance.max : Importance.high,
        priority: urgent ? Priority.high : Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(
      id,
      title,
      body.length > 180 ? '${body.substring(0, 177)}…' : body,
      details,
    );
  }
}
