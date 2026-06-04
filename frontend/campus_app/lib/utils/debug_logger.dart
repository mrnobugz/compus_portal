import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Session debug logger — posts NDJSON to host ingest from emulator/device.
class DebugLogger {
  static const _sessionId = '32521d';
  static const _endpoint =
      'http://10.0.2.2:7265/ingest/844a16bf-fb06-40df-ad41-384875df7743';

  static void log({
    required String hypothesisId,
    required String location,
    required String message,
    Map<String, dynamic>? data,
    String runId = 'pre-fix',
  }) {
    final payload = {
      'sessionId': _sessionId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data ?? {},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'runId': runId,
    };
    // #region agent log
    http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': _sessionId,
          },
          body: jsonEncode(payload),
        )
        .catchError((_) => http.Response('', 500));
    if (!Platform.isAndroid && !Platform.isIOS) {
      try {
        final file = File(r'c:\Users\JUVE\Desktop\Compus_portal\debug-32521d.log');
        file.writeAsStringSync('${jsonEncode(payload)}\n', mode: FileMode.append);
      } catch (_) {}
    }
    // #endregion
  }
}
