import 'package:flutter/material.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unauthenticated;
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

  // ── Login (temporary — no Firebase) ─────────────────────────
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Simple validation
      if (email.isEmpty || password.isEmpty) {
        _errorMessage = 'Please enter email and password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (password.length < 6) {
        _errorMessage = 'Password must be at least 6 characters';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Set user data
      _userName = email.split('@')[0];
      _userEmail = email;
      _userId = 'user_${email.hashCode}';
      _status = AuthStatus.authenticated;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Login failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ── Register (temporary — no Firebase) ──────────────────────
  Future<bool> register(String name, String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await Future.delayed(const Duration(seconds: 1));

      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        _errorMessage = 'Please fill in all fields';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Set user data
      _userName = name;
      _userEmail = email;
      _userId = 'user_${email.hashCode}';
      _status = AuthStatus.authenticated;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Registration failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────
  Future<void> signOut() async {
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