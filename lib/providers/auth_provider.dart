import 'package:flutter/material.dart';
import '../services/ssp_api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final SspApiService _sspApi = SspApiService();

  AuthStatus _status = AuthStatus.unknown;
  String _userName = '';
  String _userEmail = '';
  String _userId = '';
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  String get userName => _userName.isNotEmpty ? _userName : 'User';
  String get userEmail => _userEmail;
  String get userId => _userId;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _checkExistingSession();
  }

  // ── Check existing session on app start ──────────────────────
  Future<void> _checkExistingSession() async {
    try {
      final loggedIn = await _sspApi.isLoggedIn();
      if (loggedIn) {
        final userData = await _sspApi.getMe();
        if (userData != null) {
          _setUserFromData(userData);
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ── Set user data from API response ──────────────────────────
  void _setUserFromData(Map<String, dynamic> data) {
    // Handle nested data structure
    final user = data['data'] ?? data['user'] ?? data;
    _userName = user['name']?.toString() ?? '';
    _userEmail = user['email']?.toString() ?? '';
    _userId = user['id']?.toString() ?? '';
  }

  // ── Login via SSP API ────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _sspApi.login(email, password);

      if (result['success'] == true) {
        // Get user data after login
        final userData = await _sspApi.getMe();
        if (userData != null) {
          _setUserFromData(userData);
        } else {
          // Fallback — extract from login response
          final loginData = result['data'];
          if (loginData['user'] != null) {
            _setUserFromData(loginData['user']);
          } else {
            _userName = email.split('@')[0];
            _userEmail = email;
            _userId = 'user_${email.hashCode}';
          }
        }
        _status = AuthStatus.authenticated;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Connection failed. Please check your internet.';
      notifyListeners();
      return false;
    }
  }

  // ── Register ─────────────────────────────────────────────────
  Future<bool> register(
      String name, String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // SSP API doesn't support register via API
      // Try login first — if account exists use it
      // Otherwise show message to register via web
      _isLoading = false;
      _errorMessage =
      'Please register at: expensemate-prod.eba-3ztxbse2.ap-southeast-1.elasticbeanstalk.com';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Registration failed';
      notifyListeners();
      return false;
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────
  Future<void> signOut() async {
    await _sspApi.logout();
    _status = AuthStatus.unauthenticated;
    _userName = '';
    _userEmail = '';
    _userId = '';
    notifyListeners();
  }

  // ── Reset Password ───────────────────────────────────────────
  Future<bool> resetPassword(String email) async {
    return true;
  }

  // ── Clear error ──────────────────────────────────────────────
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}