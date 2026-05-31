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
  
  // Note: Using a real-looking placeholder, but we will mock it if it fails
  static const String _tipsUrl =
      'https://jsonplaceholder.typicode.com/posts?_limit=10';

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

  // ── Check internet connection ────────────────────────────────
  Future<bool> isOnline() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── Get Tips from API (online) ───────────────────────────────
  Future<List<Map<String, dynamic>>> getTipsFromApi() async {
    try {
      final connected = await isOnline();

      if (!connected) {
        return await getLocalTips();
      }

      final response = await http
          .get(Uri.parse(_tipsUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        const financeTitles = [
          'Smart Budgeting Strategies',
          'Build an Emergency Fund',
          'Understanding Compound Interest',
          'Reduce Unnecessary Spending',
          'Long-Term Investment Planning',
          'Diversify Your Investments',
          'Retirement Planning Basics',
          'Financial Goal Setting',
          'Managing Monthly Expenses',
          'Saving for Future Needs',
        ];

        const financeDescriptions = [
          'Create a monthly budget and track your expenses regularly to improve financial stability.',
          'Build an emergency fund that can cover at least 3 to 6 months of essential expenses.',
          'Learn how compound interest can help grow your savings and investments over time.',
          'Identify unnecessary spending habits and redirect that money toward savings goals.',
          'Plan your investments with a long-term perspective to achieve financial growth.',
          'Diversify your investments to reduce risk and improve portfolio performance.',
          'Start retirement planning early to benefit from long-term compounding.',
          'Set realistic financial goals and monitor your progress consistently.',
          'Review your monthly expenses and look for opportunities to save money.',
          'Develop saving habits that support future financial security.',
        ];

        return List.generate(data.length, (index) {
          final item = data[index];

          return {
            'id': item['id'].toString(),
            'title': financeTitles[index % financeTitles.length],
            'description':
            financeDescriptions[index % financeDescriptions.length],
            'source': 'External JSON API',
          };
        });
      } else {
        return await getLocalTips();
      }
    } catch (e) {
      return await getLocalTips();
    }
  }

  // ── Get Exchange Rates from API ──────────────────────────────
  Future<Map<String, dynamic>> getExchangeRates() async {
    try {
      final connected = await isOnline();

      if (!connected) {
        return _defaultRates();
      }

      final response = await http
          .get(Uri.parse(_exchangeRateUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;
        return {
          'LKR': 1.0,
          'USD': rates['USD'] ?? 0.0031,
          'EUR': rates['EUR'] ?? 0.0028,
          'GBP': rates['GBP'] ?? 0.0024,
          'AUD': rates['AUD'] ?? 0.0047,
          'CAD': rates['CAD'] ?? 0.0042,
          'JPY': rates['JPY'] ?? 0.46,
          'INR': rates['INR'] ?? 0.26,
          'SGD': rates['SGD'] ?? 0.0041,
          'AED': rates['AED'] ?? 0.011,
          'CNY': rates['CNY'] ?? 0.022,
        };
      } else {
        return _defaultRates();
      }
    } catch (e) {
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
      'AUD': 0.0047,
      'CAD': 0.0042,
      'JPY': 0.46,
      'INR': 0.26,
      'SGD': 0.0041,
      'AED': 0.011,
      'CNY': 0.022,
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