import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../core/api_exception.dart';
import '../utils/debug_logger.dart';

/// Paginated list response from Django REST Framework.
class PaginatedResponse<T> {
  final List<T> results;
  final int count;
  final String? next;
  final String? previous;

  const PaginatedResponse({
    required this.results,
    required this.count,
    this.next,
    this.previous,
  });

  bool get hasMore => next != null;
}

class ApiService {
  static String get host => AppConfig.host;
  static String get baseUrl => AppConfig.apiBaseUrl;

  static final http.Client _client = http.Client();
  static SharedPreferences? _prefs;
  static String? _token;
  static String? _refreshToken;
  static Map<String, dynamic>? _cachedUser;
  static DateTime? _userCacheTime;
  static const Duration _userCacheTtl = Duration(minutes: 5);

  static Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> setToken(String token, {String? refresh}) async {
    _token = token;
    final prefs = await _preferences;
    await prefs.setString('token', token);
    if (refresh != null) {
      _refreshToken = refresh;
      await prefs.setString('refresh_token', refresh);
    }
  }

  static Future<String?> getRefreshToken() async {
    if (_refreshToken != null) return _refreshToken;
    final prefs = await _preferences;
    _refreshToken = prefs.getString('refresh_token');
    return _refreshToken;
  }

  static Future<bool> refreshAccessToken() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return false;

    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/token/refresh/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final access = data['access'] as String?;
        if (access == null) return false;
        await setToken(access);
        // #region agent log
        DebugLogger.log(
          hypothesisId: 'C',
          location: 'api_service.dart:refreshAccessToken:ok',
          message: 'access token refreshed',
          data: {},
          runId: 'post-fix',
        );
        // #endregion
        return true;
      }
    } catch (e) {
      // #region agent log
      DebugLogger.log(
        hypothesisId: 'C',
        location: 'api_service.dart:refreshAccessToken:fail',
        message: 'refresh failed',
        data: {'error': e.toString()},
        runId: 'post-fix',
      );
      // #endregion
    }
    return false;
  }

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await _preferences;
    _token = prefs.getString('token');
    return _token;
  }

  static Future<void> clearToken() async {
    _token = null;
    _refreshToken = null;
    _cachedUser = null;
    _userCacheTime = null;
    final prefs = await _preferences;
    await prefs.remove('token');
    await prefs.remove('refresh_token');
  }

  static Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final token = _token ?? await getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static PaginatedResponse<Map<String, dynamic>> _parsePaginated(
    dynamic body, {
    bool resolveMedia = false,
  }) {
    List<Map<String, dynamic>> mapResults(List list) {
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((item) => resolveMedia ? _resolveMediaFields(item) : item)
          .toList();
    }

    if (body is List) {
      final results = mapResults(body);
      return PaginatedResponse(results: results, count: results.length);
    }
    if (body is Map && body['results'] is List) {
      final results = mapResults(body['results'] as List);
      return PaginatedResponse(
        results: results,
        count: body['count'] as int? ?? results.length,
        next: body['next'] as String?,
        previous: body['previous'] as String?,
      );
    }
    return const PaginatedResponse(results: [], count: 0);
  }

  static Map<String, dynamic> _resolveMediaFields(Map<String, dynamic> item) {
    final copy = Map<String, dynamic>.from(item);
    for (final key in ['file_url', 'cover_image_url', 'download_url']) {
      if (copy[key] != null) {
        copy[key] = resolveMediaUrl(copy[key] as String);
      }
    }
    return copy;
  }

  static Future<Map<String, dynamic>> _get(
    String path, {
    bool auth = false,
    Map<String, String>? query,
    bool allow401 = false,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
      final response = await _client
          .get(
            uri,
            headers: auth
                ? await _authHeaders()
                : {'Content-Type': 'application/json'},
          )
          .timeout(AppConfig.requestTimeout);
      return _handleResponse(response, allow401: allow401);
    } on SocketException {
      throw const ApiException('No network connection. Is the server running?');
    } on http.ClientException {
      throw const ApiException('Cannot reach server. Check API URL in settings.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Request failed: $e');
    }
  }

  static Future<Map<String, dynamic>> _postAuthenticated(
    String path, {
    Map<String, dynamic>? body,
    bool allow401 = false,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: await _authHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode == 401 && !allow401) {
        if (await refreshAccessToken()) {
          final retry = await _client
              .post(
                Uri.parse('$baseUrl$path'),
                headers: await _authHeaders(),
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(AppConfig.requestTimeout);
          return _handleResponse(retry, allow401: true);
        }
        await clearToken();
        throw const ApiException('Session expired. Please log in again.', statusCode: 401);
      }
      return _handleResponse(response, allow401: allow401);
    } on SocketException {
      throw const ApiException('No network connection.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Request failed: $e');
    }
  }

  static String _parseErrorBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        if (decoded['detail'] != null) return decoded['detail'].toString();
        if (decoded.entries.isNotEmpty) {
          final val = decoded.entries.first.value;
          if (val is List && val.isNotEmpty) return val.first.toString();
          return val.toString();
        }
      }
      if (decoded is List && decoded.isNotEmpty) return decoded.first.toString();
    } catch (_) {}
    return 'Request failed';
  }

  static Map<String, dynamic> _handleResponse(
    http.Response response, {
    bool allow401 = false,
  }) {
    if (response.statusCode == 401 && !allow401) {
      throw const ApiException(
        'Session expired. Please log in again.',
        statusCode: 401,
      );
    }
    return {'statusCode': response.statusCode, 'body': response.body};
  }

  static Future<Map<String, dynamic>> _getAuthenticated(
    String path, {
    Map<String, String>? query,
  }) async {
    var result = await _get(path, auth: true, query: query, allow401: true);
    if (result['statusCode'] == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        result = await _get(path, auth: true, query: query, allow401: true);
      }
      if (result['statusCode'] == 401) {
        await clearToken();
        throw const ApiException(
          'Session expired. Please log in again.',
          statusCode: 401,
        );
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final url = '$baseUrl/token/';
    // #region agent log
    DebugLogger.log(
      hypothesisId: 'A',
      location: 'api_service.dart:login:start',
      message: 'login attempt',
      data: {'url': url, 'username': username},
    );
    // #endregion
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(AppConfig.requestTimeout);
    } on SocketException catch (e) {
      // #region agent log
      DebugLogger.log(
        hypothesisId: 'A',
        location: 'api_service.dart:login:socket',
        message: 'socket exception on token request',
        data: {'error': e.toString(), 'url': url},
      );
      // #endregion
      return {'success': false, 'error': 'No network connection'};
    } catch (e) {
      // #region agent log
      DebugLogger.log(
        hypothesisId: 'D',
        location: 'api_service.dart:login:exception',
        message: 'unexpected exception on token request',
        data: {'error': e.toString(), 'url': url},
      );
      // #endregion
      return {'success': false, 'error': 'Login request failed: $e'};
    }

    // #region agent log
    DebugLogger.log(
      hypothesisId: 'B',
      location: 'api_service.dart:login:response',
      message: 'token endpoint response',
      data: {
        'statusCode': response.statusCode,
        'bodyPreview': response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body,
      },
    );
    // #endregion

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await setToken(
          data['access'] as String,
          refresh: data['refresh'] as String?,
        );
        // #region agent log
        DebugLogger.log(
          hypothesisId: 'C',
          location: 'api_service.dart:login:token_saved',
          message: 'token saved successfully',
          data: {'hasAccess': data.containsKey('access')},
        );
        // #endregion
        return {'success': true, 'data': data};
      } catch (e) {
        // #region agent log
        DebugLogger.log(
          hypothesisId: 'D',
          location: 'api_service.dart:login:json',
          message: 'token json parse failed',
          data: {'error': e.toString()},
        );
        // #endregion
        return {'success': false, 'error': 'Invalid server response'};
      }
    }
    return {
      'success': false,
      'error': _loginErrorMessage(response),
    };
  }

  static String _loginErrorMessage(http.Response response) {
    if (response.statusCode == 401) {
      return 'Invalid username/email or password';
    }
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        if (body['detail'] != null) {
          return body['detail'].toString();
        }
        if (body['username'] != null) {
          final msg = body['username'];
          if (msg is List && msg.isNotEmpty) return msg.first.toString();
          return msg.toString();
        }
        if (body['non_field_errors'] != null) {
          final msg = body['non_field_errors'];
          if (msg is List && msg.isNotEmpty) return msg.first.toString();
        }
      }
    } catch (_) {}
    return 'Login failed (${response.statusCode})';
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String studentId,
    required int departmentId,
    required int courseId,
    String firstName = '',
    String lastName = '',
  }) async {
    final url = '$baseUrl/auth/register/';
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'email': email,
              'password': password,
              'first_name': firstName,
              'last_name': lastName,
              'student_id': studentId,
              'department': departmentId,
              'course': courseId,
            }),
          )
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': jsonDecode(response.body) as Map<String, dynamic>,
        };
      }
      final body = response.body;
      try {
        final errors = jsonDecode(body);
        if (errors is Map) {
          final messages = errors.entries
              .map((e) => '${e.key}: ${e.value}')
              .join('; ');
          return {'success': false, 'error': messages};
        }
      } catch (_) {}
      return {'success': false, 'error': 'Registration failed (${response.statusCode})'};
    } on SocketException {
      return {'success': false, 'error': 'No network connection'};
    } catch (e) {
      return {'success': false, 'error': 'Registration failed: $e'};
    }
  }

  static Future<List<Map<String, dynamic>>> getDepartments() async {
    final result = await _get('/departments/');
    if (result['statusCode'] == 200) {
      final body = jsonDecode(result['body'] as String);
      if (body is List) {
        return body.cast<Map<String, dynamic>>();
      }
      if (body is Map && body['results'] is List) {
        return (body['results'] as List).cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getCourses({int? departmentId}) async {
    final query = departmentId != null
        ? {'department': departmentId.toString()}
        : null;
    final result = await _get('/courses/', query: query);
    if (result['statusCode'] == 200) {
      final body = jsonDecode(result['body'] as String);
      if (body is List) {
        return body.cast<Map<String, dynamic>>();
      }
      if (body is Map && body['results'] is List) {
        return (body['results'] as List).cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  static Future<Map<String, dynamic>> getCurrentUser({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedUser != null &&
        _userCacheTime != null &&
        DateTime.now().difference(_userCacheTime!) < _userCacheTtl) {
      return {'success': true, 'data': _cachedUser};
    }

    final token = await getToken();
    if (token == null) return {'success': false, 'error': 'Not logged in'};

    Map<String, dynamic> result;
    try {
      result = await _getAuthenticated('/users/me/');
    } catch (e) {
      // #region agent log
      DebugLogger.log(
        hypothesisId: 'C',
        location: 'api_service.dart:getCurrentUser:exception',
        message: 'users/me request threw',
        data: {'error': e.toString()},
      );
      // #endregion
      return {'success': false, 'error': e.toString()};
    }
    // #region agent log
    DebugLogger.log(
      hypothesisId: 'C',
      location: 'api_service.dart:getCurrentUser:response',
      message: 'users/me response',
      data: {'statusCode': result['statusCode']},
    );
    // #endregion
    if (result['statusCode'] == 200) {
      final data = jsonDecode(result['body'] as String) as Map<String, dynamic>;
      _cachedUser = data;
      _userCacheTime = DateTime.now();
      return {'success': true, 'data': data};
    }
    return {'success': false, 'error': 'Failed to get user'};
  }

  static Future<PaginatedResponse<Map<String, dynamic>>> getBooks({
    int page = 1,
    int pageSize = AppConfig.defaultPageSize,
    String? search,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }

    try {
      final result = await _getAuthenticated('/books/', query: query);
      if (result['statusCode'] == 200) {
        return _parsePaginated(
          jsonDecode(result['body'] as String),
          resolveMedia: true,
        );
      }
    } on ApiException {
      rethrow;
    }
    return const PaginatedResponse(results: [], count: 0);
  }

  /// Backward-compatible helper returning a flat list (first page).
  static Future<List<dynamic>> getBooksList({String? search}) async {
    final page = await getBooks(page: 1, search: search);
    return page.results;
  }

  static Future<PaginatedResponse<Map<String, dynamic>>> getSupportRequests({
    int page = 1,
    int pageSize = AppConfig.defaultPageSize,
  }) async {
    final token = await getToken();
    if (token == null) {
      return const PaginatedResponse(results: [], count: 0);
    }

    final result = await _getAuthenticated(
      '/support/',
      query: {'page': page.toString(), 'page_size': pageSize.toString()},
    );
    if (result['statusCode'] == 200) {
      return _parsePaginated(jsonDecode(result['body'] as String));
    }
    return const PaginatedResponse(results: [], count: 0);
  }

  static Future<List<dynamic>> getSupportRequestsList() async {
    final page = await getSupportRequests();
    return page.results;
  }

  static Future<Map<String, dynamic>> createSupportRequest(
    String subject,
    String issue,
  ) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'error': 'Not logged in'};

    try {
      final result = await _postAuthenticated(
        '/support/',
        body: {'subject': subject.trim(), 'issue': issue.trim()},
      );

      if (result['statusCode'] == 201) {
        return {
          'success': true,
          'data': jsonDecode(result['body'] as String),
        };
      }
      return {
        'success': false,
        'error': _parseErrorBody(result['body'] as String),
      };
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {'success': false, 'error': 'Failed to create request: $e'};
    }
  }

  static Future<Map<String, dynamic>> markSupportResponseRead(int requestId) async {
    try {
      final result = await _postAuthenticated('/support/$requestId/mark-read/');
      if (result['statusCode'] == 200) {
        return {
          'success': true,
          'data': jsonDecode(result['body'] as String),
        };
      }
      return {'success': false, 'error': _parseErrorBody(result['body'] as String)};
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  static Future<int> countUnreadSupportResponses() async {
    final page = await getSupportRequests(page: 1, pageSize: 100);
    return page.results.where((r) => r['has_unread_response'] == true).length;
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final result = await _postAuthenticated(
        '/users/change-password/',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      if (result['statusCode'] == 200) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': _parseErrorBody(result['body'] as String),
      };
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (firstName != null) body['first_name'] = firstName;
      if (lastName != null) body['last_name'] = lastName;
      if (email != null) body['email'] = email;

      final response = await _client
          .patch(
            Uri.parse('$baseUrl/users/update-profile/'),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        _cachedUser = null;
        _userCacheTime = null;
        return {
          'success': true,
          'data': jsonDecode(response.body) as Map<String, dynamic>,
        };
      }
      return {'success': false, 'error': _parseErrorBody(response.body)};
    } on SocketException {
      return {'success': false, 'error': 'No network connection'};
    } catch (e) {
      return {'success': false, 'error': 'Update failed: $e'};
    }
  }

  static Future<void> logout() async {
    await clearToken();
  }

  static void dispose() {
    _client.close();
  }

  static Future<Map<String, dynamic>> uploadProfilePicture(File file) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'error': 'Not logged in'};

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/students/upload_profile_picture/'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('profile_picture', file.path),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      _cachedUser = null;
      _userCacheTime = null;
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': 'Failed to upload profile picture'};
  }

  static Future<Map<String, dynamic>> uploadBookFile(
    int bookId,
    File file,
  ) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'error': 'Not logged in'};

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/books/upload_file/'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['book_id'] = bookId.toString();
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': 'Failed to upload file'};
  }

  static Future<Map<String, dynamic>> uploadBookCover(
    int bookId,
    File file,
  ) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'error': 'Not logged in'};

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/books/upload_cover/'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['book_id'] = bookId.toString();
    request.files.add(
      await http.MultipartFile.fromPath('cover_image', file.path),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': 'Failed to upload cover image'};
  }

  static Future<Map<String, dynamic>> getBookDownloadUrl(int bookId) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'error': 'Not logged in'};

    try {
      final result = await _getAuthenticated('/books/$bookId/download/');
      if (result['statusCode'] == 200) {
        final data = jsonDecode(result['body'] as String) as Map<String, dynamic>;
        if (data['download_url'] != null) {
          data['download_url'] = resolveMediaUrl(data['download_url'] as String);
        }
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': _parseErrorBody(result['body'] as String)};
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  static Future<PaginatedResponse<Map<String, dynamic>>> getNotes({
    int page = 1,
    int pageSize = AppConfig.defaultPageSize,
  }) async {
    try {
      final result = await _getAuthenticated(
        '/notes/',
        query: {'page': page.toString(), 'page_size': pageSize.toString()},
      );
      if (result['statusCode'] == 200) {
        return _parsePaginated(
          jsonDecode(result['body'] as String),
          resolveMedia: true,
        );
      }
    } on ApiException {
      rethrow;
    }
    return const PaginatedResponse(results: [], count: 0);
  }

  static Future<Map<String, dynamic>> getNoteReadInfo(int noteId) async {
    try {
      final result = await _getAuthenticated('/notes/$noteId/read/');
      if (result['statusCode'] == 200) {
        final data = jsonDecode(result['body'] as String) as Map<String, dynamic>;
        if (data['file_url'] != null) {
          data['file_url'] = resolveMediaUrl(data['file_url'] as String);
        }
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': _parseErrorBody(result['body'] as String)};
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  static Future<Map<String, dynamic>> getNoteDownloadInfo(int noteId) async {
    try {
      final result = await _getAuthenticated('/notes/$noteId/download/');
      if (result['statusCode'] == 200) {
        final data = jsonDecode(result['body'] as String) as Map<String, dynamic>;
        if (data['download_url'] != null) {
          data['download_url'] = resolveMediaUrl(data['download_url'] as String);
        }
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': _parseErrorBody(result['body'] as String)};
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  static Future<List<dynamic>> getMyGroups() async {
    final result = await _get('/groups/', auth: true);
    if (result['statusCode'] == 200) {
      final body = jsonDecode(result['body'] as String);
      if (body is List) return body;
      if (body is Map && body['results'] is List) return body['results'];
    }
    return [];
  }

  static Future<PaginatedResponse<Map<String, dynamic>>> getAssignments({
    int page = 1,
  }) async {
    final result = await _get(
      '/assignments/',
      auth: true,
      query: {'page': page.toString()},
    );
    if (result['statusCode'] == 200) {
      return _parsePaginated(jsonDecode(result['body'] as String));
    }
    return const PaginatedResponse(results: [], count: 0);
  }

  static Future<List<dynamic>> getLecturerGroups() async {
    final result = await _get('/assignments/my_groups/', auth: true);
    if (result['statusCode'] == 200) {
      return jsonDecode(result['body'] as String) as List<dynamic>;
    }
    return [];
  }

  static Future<Map<String, dynamic>> uploadAssignment({
    required String title,
    required String description,
    required File file,
    required List<int> groupIds,
    String? dueDate,
  }) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'error': 'Not logged in'};

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/assignments/'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title;
    request.fields['description'] = description;
    if (dueDate != null) request.fields['due_date'] = dueDate;
    request.fields['group_ids'] = groupIds.join(',');
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 201) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': 'Failed to upload assignment'};
  }

  static Future<Map<String, dynamic>> getAssignmentDownloadInfo(
    int assignmentId,
  ) async {
    final result = await _get('/assignments/$assignmentId/download/', auth: true);
    if (result['statusCode'] == 200) {
      return {
        'success': true,
        'data': jsonDecode(result['body'] as String),
      };
    }
    return {'success': false, 'error': 'Download unavailable'};
  }

  /// Download authenticated file to app documents directory.
  static Future<File?> downloadToDevice(String url, String filename) async {
    final resolved = resolveMediaUrl(url);
    final token = await getToken();
    try {
      final response = await _client.get(
        Uri.parse(resolved),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ).timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200) return null;

      final dir = await getApplicationDocumentsDirectory();
      final safeName = filename.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Download file and open with system viewer.
  static Future<Map<String, dynamic>> downloadAndOpen(
    String url,
    String filename,
  ) async {
    final file = await downloadToDevice(url, filename);
    if (file == null) {
      return {
        'success': false,
        'error': 'Download failed. On a physical device, set Server URL in login settings.',
      };
    }
    final openResult = await OpenFilex.open(file.path);
    if (openResult.type != ResultType.done) {
      return {
        'success': true,
        'file': file,
        'path': file.path,
        'warning': openResult.message,
      };
    }
    return {'success': true, 'file': file, 'path': file.path};
  }

  /// Fetch plain text content for in-app reading.
  static Future<String?> fetchTextContent(String url) async {
    final resolved = resolveMediaUrl(url);
    final token = await getToken();
    try {
      final response = await _client.get(
        Uri.parse(resolved),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ).timeout(AppConfig.requestTimeout);
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      final result = await _getAuthenticated('/dashboard/summary/');
      if (result['statusCode'] == 200) {
        return jsonDecode(result['body'] as String) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  static Future<List<Map<String, dynamic>>> getAnnouncements() async {
    try {
      final result = await _getAuthenticated('/announcements/');
      if (result['statusCode'] == 200) {
        final body = jsonDecode(result['body'] as String);
        if (body is List) return body.cast<Map<String, dynamic>>();
        if (body is Map && body['results'] is List) {
          return (body['results'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getGrades() async {
    try {
      final result = await _getAuthenticated('/grades/');
      if (result['statusCode'] == 200) {
        final body = jsonDecode(result['body'] as String);
        if (body is List) return body.cast<Map<String, dynamic>>();
        if (body is Map && body['results'] is List) {
          return (body['results'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getAttendanceRecords() async {
    try {
      final result = await _getAuthenticated('/attendance/');
      if (result['statusCode'] == 200) {
        final body = jsonDecode(result['body'] as String);
        if (body is List) return body.cast<Map<String, dynamic>>();
        if (body is Map && body['results'] is List) {
          return (body['results'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> getAttendanceSummary() async {
    try {
      final result = await _getAuthenticated('/attendance/summary/');
      if (result['statusCode'] == 200) {
        return jsonDecode(result['body'] as String) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>> downloadBook(int bookId, String title) async {
    final info = await getBookDownloadUrl(bookId);
    if (info['success'] != true) return info;
    final data = info['data'] as Map<String, dynamic>;
    final url = data['download_url']?.toString() ?? data['file_url']?.toString();
    if (url == null) return {'success': false, 'error': 'No download URL'};
    final filename = data['filename']?.toString() ??
        '${title.replaceAll(' ', '_')}.${data['file_type'] ?? 'pdf'}';
    return downloadAndOpen(url, filename);
  }

  static String resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) {
      final uri = Uri.parse(url);
      final appHost = Uri.parse(host);
      // Rewrite localhost / emulator host to current AppConfig host (physical device LAN IP)
      if (uri.host == '127.0.0.1' ||
          uri.host == 'localhost' ||
          uri.host == '10.0.2.2') {
        return Uri(
          scheme: appHost.scheme,
          host: appHost.host,
          port: appHost.hasPort ? appHost.port : null,
          path: uri.path,
          query: uri.query.isEmpty ? null : uri.query,
        ).toString();
      }
      return url;
    }
    return '$host${url.startsWith('/') ? url : '/$url'}';
  }
}
