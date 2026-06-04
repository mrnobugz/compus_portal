import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus status = AuthStatus.initial;
  Map<String, dynamic>? user;
  String? errorMessage;
  bool isBusy = false;

  bool get isLecturer =>
      user?['is_lecturer'] == true || user?['is_staff'] == true;

  Future<void> bootstrap() async {
    status = AuthStatus.initial;
    errorMessage = null;
    notifyListeners();

    final token = await ApiService.getToken();
    if (token == null) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    await _loadUser(notifyOnFail: false);
    if (user == null) {
      await ApiService.clearToken();
    }
    status = user != null
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await ApiService.login(username, password);
      if (result['success'] == true) {
        await _loadUser();
        if (user == null) {
          errorMessage = 'Login succeeded but profile could not be loaded';
          isBusy = false;
          notifyListeners();
          return false;
        }
        status = AuthStatus.authenticated;
        isBusy = false;
        notifyListeners();
        return true;
      }
      errorMessage = result['error']?.toString() ?? 'Login failed';
    } catch (e) {
      errorMessage = e.toString();
    }

    isBusy = false;
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String studentId,
    required int departmentId,
    required int courseId,
    String firstName = '',
    String lastName = '',
  }) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();

    final result = await ApiService.register(
      username: username,
      email: email,
      password: password,
      studentId: studentId,
      departmentId: departmentId,
      courseId: courseId,
      firstName: firstName,
      lastName: lastName,
    );

    if (result['success'] == true) {
      final loggedIn = await login(username, password);
      isBusy = false;
      notifyListeners();
      return loggedIn;
    }

    errorMessage = result['error']?.toString() ?? 'Registration failed';
    isBusy = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await ApiService.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    await _loadUser(forceRefresh: true);
    notifyListeners();
  }

  Future<void> _loadUser({
    bool forceRefresh = false,
    bool notifyOnFail = true,
  }) async {
    final result = await ApiService.getCurrentUser(forceRefresh: forceRefresh);
    if (result['success'] == true) {
      user = Map<String, dynamic>.from(result['data'] as Map);
    } else {
      user = null;
      if (notifyOnFail) {
        await ApiService.clearToken();
      }
    }
  }
}
