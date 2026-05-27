import 'package:flutter/material.dart';
import '../services/ssp_api_service.dart';

// --- AUTH PROVIDER ---
// This handles Login, Registration, and keeping the user logged in.
// It uses Laravel Sanctum tokens stored in SharedPreferences.
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
    // Every time the app starts, check if we have an existing session token
    _checkExistingSession();
  }

  // --- Session Management ---
  
  // Checks SharedPreferences for a token and validates it with the API
  Future<void> _checkExistingSession() async {
    try {
      final loggedIn = await _sspApi.isLoggedIn();
      if (loggedIn) {
        // Fetch fresh user profile if token is valid
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
    notifyListeners(); // Refresh the Router to show Home or Login screen
  }

  // Helper to parse user details from API response
  void _setUserFromData(Map<String, dynamic> data) {
    final user = data['data'] ?? data['user'] ?? data;
    _userName = user['name']?.toString() ?? '';
    _userEmail = user['email']?.toString() ?? '';
    _userId = user['id']?.toString() ?? '';
  }

  // --- Actions ---

  // Login via Laravel Sanctum
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _sspApi.login(email, password);

      if (result['success'] == true) {
        // Fetch full profile after successful login
        final userData = await _sspApi.getMe();
        if (userData != null) {
          _setUserFromData(userData);
        }
        _status = AuthStatus.authenticated;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Check your credentials.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Server connection failed.';
      notifyListeners();
      return false;
    }
  }

  // Registration for new users
  Future<bool> register(String name, String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _sspApi.register(name, email, password);

      if (result['success'] == true) {
        await _checkExistingSession(); // Verify session after registering
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Registration failed.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Could not reach registration server.';
      notifyListeners();
      return false;
    }
  }

  // Clear local token and reset state
  Future<void> signOut() async {
    await _sspApi.logout();
    _status = AuthStatus.unauthenticated;
    _userName = '';
    _userEmail = '';
    _userId = '';
    notifyListeners();
  }
}
