import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/ssp_api_service.dart';

// --- TRANSACTION PROVIDER ---
// Offline-first: Save to SQLite first, then sync to Laravel API.
class TransactionProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final Uuid _uuid = const Uuid();
  final SspApiService _sspApi = SspApiService();

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSyncing = false;

  StreamSubscription? _connectivitySubscription;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  TransactionProvider() {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final isOnline = results.isNotEmpty &&
          results.first != ConnectivityResult.none;
      if (isOnline && !_isSyncing) {
        print('📶 Internet returned — syncing pending...');
        await _syncPendingTransactions();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // ── Computed values ──────────────────────────────────────────
  double get totalIncome => _transactions
      .where((t) => t.type == 'income')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _transactions
      .where((t) => t.type == 'expense')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  List<TransactionModel> get recentTransactions =>
      _transactions.take(5).toList();

  // ── Budget ───────────────────────────────────────────────────
  double _monthlyBudget = 50000.0;
  double get monthlyBudget => _monthlyBudget;

  void setMonthlyBudget(double budget) {
    _monthlyBudget = budget;
    notifyListeners();
  }

  double get budgetUsedPercentage {
    if (_monthlyBudget <= 0) return 0;
    return (totalExpense / _monthlyBudget * 100).clamp(0, 100);
  }

  double get remainingBudget => _monthlyBudget - totalExpense;

  String get budgetStatus {
    final pct = budgetUsedPercentage;
    if (pct >= 100) return 'exceeded';
    if (pct >= 80) return 'warning';
    return 'safe';
  }

  double get dailyAverage {
    if (_transactions.isEmpty) return 0;
    final day = DateTime.now().day;
    return day == 0 ? 0 : totalExpense / day;
  }

  double get predictedMonthlyExpense {
    if (_transactions.isEmpty) return 0;
    final now = DateTime.now();
    final day = now.day;
    final totalDays = DateTime(now.year, now.month + 1, 0).day;
    return day == 0 ? 0 : (totalExpense / day) * totalDays;
  }

  Map<String, double> get categoryBreakdown {
    final Map<String, double> breakdown = {};
    for (var t in _transactions.where((t) => t.type == 'expense')) {
      breakdown[t.category] = (breakdown[t.category] ?? 0) + t.amount;
    }
    return breakdown;
  }

  // ── Load from SQLite ─────────────────────────────────────────
  Future<void> loadTransactions(String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      _transactions = await _db.getTransactions(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load: $e';
      notifyListeners();
    }
  }

  // ── Load from SSP API ────────────────────────────────────────
  // Syncs API data to SQLite and removes server-deleted items
  Future<void> loadFromApi(String userId) async {
    try {
      print('🔄 Loading from API...');
      final apiExpenses = await _sspApi.getExpenses();
      print('📥 API returned ${apiExpenses.length} expenses');

      // Get all server IDs from API response
      final serverIds = apiExpenses
          .map((e) => 'ssp_${e['id']?.toString() ?? ''}')
          .where((id) => id != 'ssp_')
          .toSet();

      print('📋 Server IDs: $serverIds');

      // Get existing ssp_ transactions from SQLite
      final existingTransactions =
      await _db.getTransactions(userId);
      final existingSspIds = existingTransactions
          .where((t) => t.id.startsWith('ssp_'))
          .map((t) => t.id)
          .toSet();

      print('📋 Existing SQLite SSP IDs: $existingSspIds');

      // FIX: Find IDs deleted on server — remove from SQLite
      final deletedIds = existingSspIds.difference(serverIds);
      print('🗑️ Deleted on server: $deletedIds');

      for (final deletedId in deletedIds) {
        print('🗑️ Removing from SQLite: $deletedId');
        await _db.deleteTransaction(deletedId);
      }

      // Save all API expenses to SQLite
      for (final expense in apiExpenses) {
        print('📦 Processing: $expense');

        // Extract category
        String categoryName = 'Other';
        final cat = expense['category'];
        if (cat is Map) {
          final catId = cat['id'];
          final catName = cat['name']?.toString() ?? '';
          categoryName = _mapSspCategory(catName, catId);
        } else if (cat is String && cat.isNotEmpty) {
          categoryName = _mapSspCategory(cat, null);
        } else {
          final catId = expense['category_id'];
          if (catId != null) {
            categoryName = _getCategoryNameFromId(
              int.tryParse(catId.toString()) ?? 0,
            );
          }
        }

        // Parse amount
        double amount = 0.0;
        final rawAmount = expense['amount'];
        if (rawAmount is num) {
          amount = rawAmount.toDouble();
        } else if (rawAmount is String) {
          final cleaned =
          rawAmount.replaceAll(RegExp(r'[^0-9.]'), '');
          amount = double.tryParse(cleaned) ?? 0.0;
        }

        // Parse type
        String type = 'expense';
        final rawType =
            expense['type']?.toString().toLowerCase() ?? '';
        if (rawType == 'income') type = 'income';

        // Parse date
        String date = '';
        final rawDate = expense['expense_date'] ??
            expense['date'] ??
            expense['created_at'] ??
            expense['updated_at'];
        if (rawDate is String && rawDate.isNotEmpty) {
          date = _parseSspDate(rawDate);
        }

        // Parse note
        String? note;
        if (expense['note'] != null &&
            expense['note'].toString().isNotEmpty) {
          note = expense['note'].toString();
        } else if (expense['title'] != null &&
            expense['title'].toString().isNotEmpty) {
          note = expense['title'].toString();
        }

        final serverId =
            expense['id']?.toString() ?? _uuid.v4();
        final transactionId = 'ssp_$serverId';

        print(
          '✅ Saving: $transactionId | $categoryName | $amount | $type | $date',
        );

        final transaction = TransactionModel(
          id: transactionId,
          userId: userId,
          type: type,
          category: categoryName,
          amount: amount,
          date: date,
          note: note,
          currency: 'LKR',
          isSynced: true,
        );

        await _db.insertTransaction(transaction);
      }

      print(
        '✅ All ${apiExpenses.length} expenses saved to SQLite',
      );

      await loadTransactions(userId);
    } catch (e) {
      print('❌ API load error: $e');
      debugPrint('API load failed: $e');
    }
  }

  // ── Parse SSP date "25 May 2026" → "2026-05-25" ─────────────
  String _parseSspDate(String rawDate) {
    try {
      final cleanDate = rawDate.split(',')[0].trim();

      if (cleanDate.contains('-') && cleanDate.length == 10) {
        return cleanDate;
      }

      final parts = cleanDate.split(' ');
      if (parts.length == 3) {
        const months = {
          'Jan': '01', 'Feb': '02', 'Mar': '03',
          'Apr': '04', 'May': '05', 'Jun': '06',
          'Jul': '07', 'Aug': '08', 'Sep': '09',
          'Oct': '10', 'Nov': '11', 'Dec': '12',
        };
        final day = parts[0].padLeft(2, '0');
        final month = months[parts[1]] ?? '01';
        final year = parts[2];
        return '$year-$month-$day';
      }

      if (rawDate.length > 10) return rawDate.substring(0, 10);
      return rawDate;
    } catch (e) {
      return rawDate.length > 10
          ? rawDate.substring(0, 10)
          : rawDate;
    }
  }

  // ── Map SSP category names to Flutter names ──────────────────
  String _mapSspCategory(String sspName, dynamic catId) {
    const nameMap = {
      'Food': 'Food & Drinks',
      'food': 'Food & Drinks',
      'Food & Drinks': 'Food & Drinks',
      'Transport': 'Transport',
      'transport': 'Transport',
      'Shopping': 'Shopping',
      'shopping': 'Shopping',
      'Bills': 'Bills',
      'bills': 'Bills',
      'Health': 'Health',
      'health': 'Health',
      'Medical': 'Health',
      'medical': 'Health',
      'Entertainment': 'Entertainment',
      'entertainment': 'Entertainment',
      'Education': 'Education',
      'education': 'Education',
      'Salary': 'Salary',
      'salary': 'Salary',
      'Freelance': 'Freelance',
      'freelance': 'Freelance',
      'Rent': 'Bills',
      'rent': 'Bills',
      'Other': 'Other',
      'other': 'Other',
    };

    if (nameMap.containsKey(sspName)) {
      return nameMap[sspName]!;
    }

    if (catId != null) {
      return _getCategoryNameFromId(
        int.tryParse(catId.toString()) ?? 0,
      );
    }

    return 'Other';
  }

  // ── Map category_id to Flutter name ─────────────────────────
  String _getCategoryNameFromId(int id) {
    const idToName = {
      1: 'Food & Drinks',
      2: 'Transport',
      3: 'Bills',
      4: 'Shopping',
      5: 'Health',
      6: 'Education',
      7: 'Entertainment',
      8: 'Salary',
      9: 'Freelance',
      10: 'Other',
      11: 'Bills',
      12: 'Health',
    };
    return idToName[id] ?? 'Other';
  }

  // ── Add transaction ──────────────────────────────────────────
  Future<bool> addTransaction({
    required String userId,
    required String type,
    required String category,
    required double amount,
    required String date,
    String? note,
    String? imagePath,
    double? latitude,
    double? longitude,
    String currency = 'LKR',
  }) async {
    try {
      _errorMessage = null;

      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      final transaction = TransactionModel(
        id: _uuid.v4(),
        userId: userId,
        type: type,
        category: category,
        amount: amount,
        date: date,
        note: note?.trim().isEmpty == true ? null : note?.trim(),
        imagePath: imagePath,
        latitude: latitude,
        longitude: longitude,
        currency: currency,
        isSynced: false,
      );

      await _db.insertTransaction(transaction);

      _transactions.insert(0, transaction);
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();

      if (isOnline) {
        await _createOnApi(transaction);
      } else {
        print('📴 Offline — will sync when online');
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to save: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Update transaction ───────────────────────────────────────
  Future<bool> updateTransaction(TransactionModel transaction) async {
    try {
      _errorMessage = null;

      await _db.updateTransaction(transaction);

      final index =
      _transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _transactions[index] = transaction;
        _transactions.sort((a, b) => b.date.compareTo(a.date));
        notifyListeners();
      }

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none) {
        if (transaction.id.startsWith('ssp_')) {
          print('UPDATE ID: ${transaction.id}');
          await _updateOnApi(transaction);
        } else {
          print('CREATE ON SERVER (local): ${transaction.id}');
          await _createOnApi(transaction);
        }
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to update: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Delete transaction ───────────────────────────────────────
  Future<bool> deleteTransaction(String id) async {
    try {
      _errorMessage = null;
      print('DELETE ID: $id');

      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      if (isOnline && id.startsWith('ssp_')) {
        final serverId = id.replaceFirst('ssp_', '');
        print('DELETE SERVER ID: $serverId');
        final success = await _sspApi.deleteExpense(serverId);
        print(
          'DELETE STATUS: ${success ? '✅ success' : '❌ failed'}',
        );
      } else if (!id.startsWith('ssp_')) {
        print('DELETE LOCAL ONLY — no server record');
      } else {
        print('DELETE OFFLINE — SQLite only');
      }

      await _db.deleteTransaction(id);
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete: $e';
      print('❌ DELETE ERROR: $e');
      notifyListeners();
      return false;
    }
  }

  // ── Create on API (POST) ─────────────────────────────────────
  Future<void> _createOnApi(TransactionModel t) async {
    try {
      final payload = _buildPayload(t);
      print('📤 CREATE PAYLOAD: $payload');

      final result = await _sspApi.createExpense(payload);
      print('📥 CREATE RESULT: $result');

      if (result['success'] == true) {
        final responseData =
            result['data']?['data'] ?? result['data'];

        if (responseData != null && responseData['id'] != null) {
          final newId = 'ssp_${responseData['id']}';
          print('✅ Server ID assigned: $newId');

          await _db.updateTransactionId(t.id, newId);

          final index =
          _transactions.indexWhere((item) => item.id == t.id);
          if (index != -1) {
            _transactions[index] =
                t.copyWith(id: newId, isSynced: true);
            notifyListeners();
          }
        } else {
          await _db.markAsSynced(t.id);
          _updateMemorySync(t.id, true);
        }
        print('✅ Created on server: ${t.category}');
      } else {
        print('❌ Create failed: ${result['message']}');
      }
    } catch (e) {
      print('❌ Create error: $e');
    }
  }

  // ── Update on API (PUT) ──────────────────────────────────────
  Future<void> _updateOnApi(TransactionModel t) async {
    try {
      final payload = _buildPayload(t);
      print('📤 UPDATE ID: ${t.id}');
      print('📤 UPDATE PAYLOAD: $payload');

      final result = await _sspApi.updateExpense(t.id, payload);
      print('📥 UPDATE RESULT: $result');

      if (result['success'] == true) {
        await _db.markAsSynced(t.id);
        _updateMemorySync(t.id, true);
        print('✅ Updated on server: ${t.category}');
      } else if (result['message'] == 'not_found') {
        print('⚠️ Not found on server — creating...');
        await _createOnApi(t);
      } else {
        print('❌ Update failed: ${result['message']}');
      }
    } catch (e) {
      print('❌ Update error: $e');
    }
  }

  // ── Build API payload ────────────────────────────────────────
  Map<String, dynamic> _buildPayload(TransactionModel t) {
    return {
      'title': (t.note != null && t.note!.isNotEmpty)
          ? t.note
          : t.category,
      'amount': t.amount,
      'type': t.type,
      'category_id': _getCategoryId(t.category),
      'expense_date': t.date,
      'note': t.note ?? '',
    };
  }

  // ── Update sync status in memory ─────────────────────────────
  void _updateMemorySync(String id, bool status) {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index != -1) {
      _transactions[index] =
          _transactions[index].copyWith(isSynced: status);
      notifyListeners();
    }
  }

  // ── Auto sync pending when internet returns ──────────────────
  Future<void> _syncPendingTransactions() async {
    if (_isSyncing || _transactions.isEmpty) return;
    _isSyncing = true;

    try {
      final userId = _transactions.first.userId;
      final pending = await _db.getUnsyncedTransactions(userId);

      if (pending.isEmpty) {
        print('✅ No pending transactions');
        _isSyncing = false;
        return;
      }

      print('🔄 Syncing ${pending.length} pending...');

      for (final t in pending) {
        if (t.id.startsWith('ssp_')) {
          await _updateOnApi(t);
        } else {
          await _createOnApi(t);
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      print('✅ All pending synced!');
    } catch (e) {
      print('❌ Pending sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ── Category name → SSP category_id ─────────────────────────
  int _getCategoryId(String categoryName) {
    const categoryMap = {
      'Food & Drinks': 1,
      'Transport': 2,
      'Bills': 3,
      'Shopping': 4,
      'Health': 5,
      'Education': 6,
      'Entertainment': 7,
      'Salary': 8,
      'Freelance': 9,
      'Other': 10,
    };
    return categoryMap[categoryName] ?? 10;
  }

  // ── Filter and Search ────────────────────────────────────────
  List<TransactionModel> filterTransactions(String filter) {
    if (filter == 'all') return _transactions;
    return _transactions.where((t) => t.type == filter).toList();
  }

  List<TransactionModel> searchTransactions(String query) {
    if (query.isEmpty) return _transactions;
    final q = query.toLowerCase();
    return _transactions.where((t) {
      return t.category.toLowerCase().contains(q) ||
          (t.note?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ── Clear on logout ──────────────────────────────────────────
  void clearData() {
    _transactions = [];
    notifyListeners();
  }
}