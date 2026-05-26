import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';

class SspApiService {
  // Singleton
  static final SspApiService _instance = SspApiService._internal();
  factory SspApiService() => _instance;
  SspApiService._internal();

  // ── Save token ───────────────────────────────────────────────
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ssp_token', token);
  }

  // ── Get token ────────────────────────────────────────────────
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ssp_token');
  }

  // ── Clear token ──────────────────────────────────────────────
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ssp_token');
  }

  // ── Auth headers ─────────────────────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ═══════════════════════════════════════════════════════════
  // AUTHENTICATION
  // ═══════════════════════════════════════════════════════════

  // ── Login ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http
          .post(
        Uri.parse(AppConstants.sspLoginUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
          'device_name': 'ExpenseMate Mobile',
        }),
      )
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Save token
        if (data['token'] != null) {
          await saveToken(data['token']);
        }
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection failed. Check your internet.',
      };
    }
  }
  // ── Register ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    try {
      final response = await http
          .post(
        Uri.parse('${AppConstants.sspBaseUrl}/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'device_name': 'ExpenseMate Mobile',
        }),
      )
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['token'] != null) {
          await saveToken(data['token']);
        }
        return {'success': true, 'data': data};
      } else {
        // Handle validation errors
        String message = 'Registration failed';
        if (data['errors'] != null) {
          final errors = data['errors'] as Map<String, dynamic>;
          message = errors.values.first[0].toString();
        } else if (data['message'] != null) {
          message = data['message'];
        }
        return {'success': false, 'message': message};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection failed. Check your internet.',
      };
    }
  }

  // ── Logout ───────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      final headers = await _authHeaders();
      await http
          .post(
        Uri.parse(AppConstants.sspLogoutUrl),
        headers: headers,
      )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // Silent fail — clear token anyway
    } finally {
      await clearToken();
    }
  }

  // ── Get current user ─────────────────────────────────────────
  Future<Map<String, dynamic>?> getMe() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
        Uri.parse(AppConstants.sspMeUrl),
        headers: headers,
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // EXPENSES
  // ═══════════════════════════════════════════════════════════

  // ── Get all expenses ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getExpenses() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
        Uri.parse(AppConstants.sspExpensesUrl),
        headers: headers,
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle both array and object with data key
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data['data'] != null) {
          return (data['data'] as List).cast<Map<String, dynamic>>();
        }
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Create expense ───────────────────────────────────────────
  Future<Map<String, dynamic>> createExpense(
      Map<String, dynamic> expense) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
        Uri.parse(AppConstants.sspExpensesUrl),
        headers: headers,
        body: json.encode(expense),
      )
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to create expense',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  // ── Update expense ───────────────────────────────────────────
  Future<Map<String, dynamic>> updateExpense(
      String id, Map<String, dynamic> expense) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .put(
        Uri.parse('${AppConstants.sspExpensesUrl}/$id'),
        headers: headers,
        body: json.encode(expense),
      )
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update expense',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  // ── Delete expense ───────────────────────────────────────────
  Future<bool> deleteExpense(String id) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(
        Uri.parse('${AppConstants.sspExpensesUrl}/$id'),
        headers: headers,
      )
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  // ── Get summary ──────────────────────────────────────────────
  Future<Map<String, dynamic>?> getSummary() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
        Uri.parse(AppConstants.sspSummaryUrl),
        headers: headers,
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Check if logged in ───────────────────────────────────────
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null) return false;
    final user = await getMe();
    return user != null;
  }
}