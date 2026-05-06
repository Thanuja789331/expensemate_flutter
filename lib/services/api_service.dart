import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ── API URLs ─────────────────────────────────────────────────
  static const String _exchangeRateUrl =
      'https://api.exchangerate-api.com/v4/latest/LKR';
  static const String _tipsUrl =
      'https://jsonplaceholder.typicode.com/posts?_limit=5';

  // ── LOCAL JSON path ──────────────────────────────────────────
  static const String _localDataPath = 'assets/json/app_data.json';

  // ── Load Local JSON (offline fallback) ───────────────────────
  Future<Map<String, dynamic>> loadLocalData() async {
    try {
      final String data = await rootBundle.loadString(_localDataPath);
      return json.decode(data);
    } catch (e) {
      return {};
    }
  }

  // ── Get Categories from local JSON ───────────────────────────
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final data = await loadLocalData();
      final categories = data['categories'] as List<dynamic>? ?? [];
      return categories.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // ── Get Tips from local JSON (offline fallback) ──────────────
  Future<List<Map<String, dynamic>>> getLocalTips() async {
    try {
      final data = await loadLocalData();
      final tips = data['tips'] as List<dynamic>? ?? [];
      return tips.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // ── Get Tips from API (online) ───────────────────────────────
  Future<List<Map<String, dynamic>>> getTipsFromApi() async {
    try {
      final response = await http
          .get(Uri.parse(_tipsUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Map JSONPlaceholder posts to tip format
        return data.map((post) {
          return {
            'id': post['id'].toString(),
            'title': post['title'].toString().length > 40
                ? post['title'].toString().substring(0, 40)
                : post['title'].toString(),
            'description': post['body'].toString().length > 100
                ? post['body'].toString().substring(0, 100)
                : post['body'].toString(),
          };
        }).toList();
      } else {
        // If API fails, return local tips
        return await getLocalTips();
      }
    } catch (e) {
      // If no internet, return local tips
      return await getLocalTips();
    }
  }

  // ── Get Exchange Rates from API ──────────────────────────────
  Future<Map<String, dynamic>> getExchangeRates() async {
    try {
      final response = await http
          .get(Uri.parse(_exchangeRateUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;

        // Return only the currencies we need
        return {
          'LKR': 1.0,
          'USD': rates['USD'] ?? 0.0031,
          'EUR': rates['EUR'] ?? 0.0028,
          'GBP': rates['GBP'] ?? 0.0024,
        };
      } else {
        return _defaultRates();
      }
    } catch (e) {
      // If no internet, return default rates
      return _defaultRates();
    }
  }

  // ── Default rates if API fails ───────────────────────────────
  Map<String, dynamic> _defaultRates() {
    return {
      'LKR': 1.0,
      'USD': 0.0031,
      'EUR': 0.0028,
      'GBP': 0.0024,
    };
  }

  // ── Get Currencies from local JSON ───────────────────────────
  Future<List<Map<String, dynamic>>> getCurrencies() async {
    try {
      final data = await loadLocalData();
      final currencies = data['currencies'] as List<dynamic>? ?? [];
      return currencies.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
}