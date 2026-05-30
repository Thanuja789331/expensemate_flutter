import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SspApiService {
  static final SspApiService _instance = SspApiService._internal();
  factory SspApiService() => _instance;
  SspApiService._internal();

  static const String _baseUrl =
      'http://expensemate-prod.eba-3ztxbse2.ap-southeast-1.elasticbeanstalk.com/api';

  // ── Save token ───────────────────────────────────────────────
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ssp_token', token);
    print('✅ Token saved: $token');
  }

  // ── Get token ────────────────────────────────────────────────
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('ssp_token');
    print('🔑 Token retrieved: $token');
    return token;
  }

  // ── Clear token ──────────────────────────────────────────────
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ssp_token');
  }

  // ── Auth headers ─────────────────────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    print('📤 Headers: $headers');
    return headers;
  }

  // ── Login ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      print('🔐 Logging in: $email');
      final response = await http
          .post(
        Uri.parse('$_baseUrl/auth/login'),
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

      print('📥 Login response status: ${response.statusCode}');
      print('📥 Login response body: ${response.body}');

      // Check if response is HTML (redirect to login)
      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        return {
          'success': false,
          'message': 'Server error - received HTML instead of JSON'
        };
      }

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['token'] != null) {
          await saveToken(data['token'].toString());
          print('✅ Login successful, token: ${data['token']}');
        }
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      print('❌ Login error: $e');
      return {
        'success': false,
        'message': 'Connection failed: $e',
      };
    }
  }

  // ── Register ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    try {
      final response = await http
          .post(
        Uri.parse('$_baseUrl/auth/register'),
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

      print('📥 Register status: ${response.statusCode}');
      print('📥 Register body: ${response.body}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        return {
          'success': false,
          'message': 'Server error - received HTML'
        };
      }

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['token'] != null) {
          await saveToken(data['token'].toString());
        }
        return {'success': true, 'data': data};
      } else {
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
      return {'success': false, 'message': 'Connection failed: $e'};
    }
  }

  // ── Logout ───────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      final headers = await _authHeaders();
      await http
          .post(
        Uri.parse('$_baseUrl/auth/logout'),
        headers: headers,
      )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      print('❌ Logout error: $e');
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
        Uri.parse('$_baseUrl/auth/me'),
        headers: headers,
      )
          .timeout(const Duration(seconds: 10));

      print('📥 GetMe status: ${response.statusCode}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        print('❌ GetMe received HTML - token invalid!');
        return null;
      }

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ GetMe error: $e');
      return null;
    }
  }

  // ── Create expense ───────────────────────────────────────────
  Future<Map<String, dynamic>> createExpense(
      Map<String, dynamic> expense) async {
    try {
      final headers = await _authHeaders();

      print('📤 Creating expense: ${json.encode(expense)}');

      final response = await http
          .post(
        Uri.parse('$_baseUrl/expenses'),
        headers: headers,
        body: json.encode(expense),
      )
          .timeout(const Duration(seconds: 15));

      print('📥 Create expense status: ${response.statusCode}');
      print('📥 Create expense body: ${response.body}');

      // Check if HTML returned (means token invalid)
      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        print('❌ Received HTML - token is invalid or expired!');
        return {
          'success': false,
          'message': 'Token invalid - please login again'
        };
      }

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Expense created successfully!');
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to create expense',
      };
    } catch (e) {
      print('❌ Create expense error: $e');
      return {'success': false, 'message': 'Connection failed: $e'};
    }
  }

  // ── Get all expenses ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getExpenses() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
        Uri.parse('$_baseUrl/expenses'),
        headers: headers,
      )
          .timeout(const Duration(seconds: 15));

      print('📥 Get expenses status: ${response.statusCode}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        print('❌ Received HTML - token invalid!');
        return [];
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data['data'] != null) {
          return (data['data'] as List).cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      print('❌ Get expenses error: $e');
      return [];
    }
  }

  // ── Update expense ───────────────────────────────────────────
  Future<Map<String, dynamic>> updateExpense(
      String id, Map<String, dynamic> expense) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .put(
        Uri.parse('$_baseUrl/expenses/$id'),
        headers: headers,
        body: json.encode(expense),
      )
          .timeout(const Duration(seconds: 15));

      print('📥 Update expense status: ${response.statusCode}');
      print('📥 Update expense body: ${response.body}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        return {'success': false, 'message': 'Token invalid'};
      }

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection failed: $e'};
    }
  }

  // ── Delete expense ───────────────────────────────────────────
  Future<bool> deleteExpense(String id) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(
        Uri.parse('$_baseUrl/expenses/$id'),
        headers: headers,
      )
          .timeout(const Duration(seconds: 15));

      print('📥 Delete expense status: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('❌ Delete expense error: $e');
      return false;
    }
  }

  // ── Get summary ──────────────────────────────────────────────
  Future<Map<String, dynamic>?> getSummary() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
        Uri.parse('$_baseUrl/summary'),
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
    if (token == null) {
      print('❌ No token found');
      return false;
    }
    final user = await getMe();
    return user != null;
  }
}