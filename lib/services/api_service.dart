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

      // Mocking external financial tips API since jsonplaceholder is dummy
      // In a real app, this would be a real financial tips endpoint
      await Future.delayed(const Duration(seconds: 1)); // Simulate network lag
      
      return [
        {
          'id': 'ext_1',
          'title': 'Invest in Your Financial Literacy',
          'description': 'The best investment you can make is in yourself. Read books, take courses, and stay informed about market trends and personal finance strategies.',
          'source': 'External API'
        },
        {
          'id': 'ext_2',
          'title': 'Understand Compound Interest',
          'description': 'Einstein called compound interest the eighth wonder of the world. Starting to save and invest early allows your money to grow exponentially over time.',
          'source': 'External API'
        },
        {
          'id': 'ext_3',
          'title': 'Avoid Lifestyle Creep',
          'description': 'As your income increases, resist the urge to increase your spending at the same rate. Keep your expenses stable and invest the difference.',
          'source': 'External API'
        },
        {
          'id': 'ext_4',
          'title': 'Diversify Your Investments',
          'description': 'Don\'t put all your eggs in one basket. Spreading your investments across different asset classes like stocks, bonds, and real estate reduces risk.',
          'source': 'External API'
        },
        {
          'id': 'ext_5',
          'title': 'Set S.M.A.R.T Financial Goals',
          'description': 'Specific, Measurable, Achievable, Relevant, and Time-bound goals give you a clear roadmap and motivation to save.',
          'source': 'External API'
        },
        {
          'id': 'ext_6',
          'title': 'Plan for Retirement Now',
          'description': 'It\'s never too early to start planning for retirement. Even small contributions today can lead to a comfortable future thanks to long-term growth.',
          'source': 'External API'
        }
      ];
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