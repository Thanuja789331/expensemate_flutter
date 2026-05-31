import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SspApiService {
  static final SspApiService _instance = SspApiService._internal();
  factory SspApiService() => _instance;
  SspApiService._internal();

  static const String _baseUrl =
      'http://expensemate-prod.eba-3ztxbse2.ap-southeast-1.elasticbeanstalk.com/api';

  // ── Token management ─────────────────────────────────────────
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ssp_token', token);
    print('✅ Token saved');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ssp_token');
  }

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

  // FIX: Strip ssp_ prefix to get real server numeric ID
  // e.g. 'ssp_41' becomes '41'
  String _cleanId(String id) {
    return id.startsWith('ssp_') ? id.replaceFirst('ssp_', '') : id;
  }

  // Check if response is HTML (means token invalid/expired)
  bool _isHtml(String body) {
    final t = body.trim().toLowerCase();
    return t.startsWith('<!doctype') || t.startsWith('<html');
  }

  // ── Login ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
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

      if (_isHtml(response.body)) {
        return {'success': false, 'message': 'Server error'};
      }

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        if (data['token'] != null) {
          await saveToken(data['token'].toString());
        }
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Login failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
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

      if (_isHtml(response.body)) {
        return {'success': false, 'message': 'Server error'};
      }

      final data = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['token'] != null) {
          await saveToken(data['token'].toString());
        }
        return {'success': true, 'data': data};
      }

      String message = 'Registration failed';
      if (data['errors'] != null) {
        final errors = data['errors'] as Map<String, dynamic>;
        message = errors.values.first[0].toString();
      } else if (data['message'] != null) {
        message = data['message'];
      }
      return {'success': false, 'message': message};
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
      print('⚠️ Logout request failed: $e');
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

      if (_isHtml(response.body)) return {'error': 'unauthorized'};
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      if (response.statusCode == 401) {
        return {'error': 'unauthorized'};
      }
      return {'error': 'network_error'};
    } catch (e) {
      return {'error': 'network_error'};
    }
  }

  // ── Create expense POST /api/expenses ────────────────────────
  Future<Map<String, dynamic>> createExpense(
      Map<String, dynamic> expense) async {
    try {
      final headers = await _authHeaders();
      print('📤 CREATE: ${json.encode(expense)}');

      final response = await http
          .post(
        Uri.parse('$_baseUrl/expenses'),
        headers: headers,
        body: json.encode(expense),
      )
          .timeout(const Duration(seconds: 15));

      print('📥 CREATE STATUS: ${response.statusCode}');
      print('📥 CREATE BODY: ${response.body}');

      if (_isHtml(response.body)) {
        return {'success': false, 'message': 'Token invalid'};
      }

      final data = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Create failed',
      };
    } catch (e) {
      print('❌ CREATE ERROR: $e');
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  // ── Get all expenses GET /api/expenses ───────────────────────
  Future<List<Map<String, dynamic>>> getExpenses() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
        Uri.parse('$_baseUrl/expenses'),
        headers: headers,
      )
          .timeout(const Duration(seconds: 15));

      print('📥 GET EXPENSES STATUS: ${response.statusCode}');
      print('📥 GET EXPENSES BODY: ${response.body}');

      if (_isHtml(response.body)) {
        print('❌ HTML response — token invalid');
        return [];
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // FIX: Handle all possible response formats
        if (data is List) {
          print('✅ Got ${data.length} expenses (array format)');
          return data.cast<Map<String, dynamic>>();
        }

        if (data is Map) {
          // Format: {"data": [...]}
          if (data['data'] is List) {
            final list = data['data'] as List;
            print('✅ Got ${list.length} expenses (data key format)');
            return list.cast<Map<String, dynamic>>();
          }

          // Format: {"expenses": [...]}
          if (data['expenses'] is List) {
            final list = data['expenses'] as List;
            print('✅ Got ${list.length} expenses (expenses key)');
            return list.cast<Map<String, dynamic>>();
          }

          // FIX: Handle paginated response
          // Format: {"current_page": 1, "data": [...]}
          if (data['current_page'] != null && data['data'] is List) {
            final list = data['data'] as List;
            print('✅ Got ${list.length} expenses (paginated)');
            return list.cast<Map<String, dynamic>>();
          }
        }

        print('⚠️ Unexpected response format: ${data.runtimeType}');
        print('Response: $data');
        return [];
      }

      print('❌ GET EXPENSES FAILED: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ GET EXPENSES ERROR: $e');
      return [];
    }
  }

  // ── Update expense PUT /api/expenses/{id} ────────────────────
  // FIX: id can be 'ssp_41' or '41' — we clean it either way
  Future<Map<String, dynamic>> updateExpense(
      String id, Map<String, dynamic> expense) async {
    try {
      // FIX: Always strip ssp_ prefix before building URL
      final cleanId = _cleanId(id);
      final url = '$_baseUrl/expenses/$cleanId';
      final headers = await _authHeaders();

      print('📤 UPDATE ID: $id → cleanId: $cleanId');
      print('📤 UPDATE URL: $url');
      print('📤 UPDATE PAYLOAD: ${json.encode(expense)}');

      final response = await http
          .put(
        Uri.parse(url),
        headers: headers,
        body: json.encode(expense),
      )
          .timeout(const Duration(seconds: 15));

      print('📥 UPDATE STATUS: ${response.statusCode}');
      print('📥 UPDATE BODY: ${response.body}');

      if (_isHtml(response.body)) {
        return {'success': false, 'message': 'Token invalid'};
      }

      if (response.statusCode == 200) {
        print('✅ UPDATE SUCCESS');
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      }

      // FIX: 404 means record not found on server
      if (response.statusCode == 404) {
        print('⚠️ 404 — record not found on server');
        return {'success': false, 'message': 'not_found'};
      }

      return {
        'success': false,
        'message': 'Update failed: ${response.statusCode}',
      };
    } catch (e) {
      print('❌ UPDATE ERROR: $e');
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  // ── Delete expense DELETE /api/expenses/{id} ─────────────────
  // FIX: id parameter should be CLEAN numeric ID (no ssp_ prefix)
  Future<bool> deleteExpense(String id) async {
    try {
      // FIX: Clean the ID — caller may pass '41' or 'ssp_41'
      final cleanId = _cleanId(id);
      final url = '$_baseUrl/expenses/$cleanId';
      final headers = await _authHeaders();

      print('DELETE ID: $id → cleanId: $cleanId');
      print('DELETE URL: $url');

      final response = await http
          .delete(
        Uri.parse(url),
        headers: headers,
      )
          .timeout(const Duration(seconds: 15));

      print('DELETE STATUS: ${response.statusCode}');
      print('DELETE BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ DELETE SUCCESS');
        return true;
      }

      print('❌ DELETE FAILED: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ DELETE ERROR: $e');
      return false;
    }
  }

  // ── Check token exists ───────────────────────────────────────
  Future<bool> hasStoredToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Check if logged in ───────────────────────────────────────
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null) return false;
    final user = await getMe();
    return user != null && user['error'] == null;
  }
}