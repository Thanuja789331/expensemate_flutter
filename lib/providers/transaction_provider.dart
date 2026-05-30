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

  // Auto-sync when internet returns
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
  Future<void> loadFromApi(String userId) async {
    try {
      final apiExpenses = await _sspApi.getExpenses();
      for (final expense in apiExpenses) {
        // Extract category name safely
        String categoryName = 'Other';
        final cat = expense['category'];
        if (cat is Map) {
          categoryName = cat['name']?.toString() ?? 'Other';
        } else if (cat is String && cat.isNotEmpty) {
          categoryName = cat;
        }

        // Parse amount safely
        double amount = 0.0;
        final rawAmount = expense['amount'];
        if (rawAmount is num) {
          amount = rawAmount.toDouble();
        } else if (rawAmount is String) {
          amount = double.tryParse(rawAmount) ?? 0.0;
        }

        // Parse type
        final rawType =
            expense['type']?.toString().toLowerCase() ?? '';
        final type = rawType == 'income' ? 'income' : 'expense';

        // Parse date — use expense_date first
        String date = '';
        final rawDate = expense['expense_date'] ??
            expense['date'] ??
            expense['created_at'];
        if (rawDate is String && rawDate.isNotEmpty) {
          date = rawDate.length > 10
              ? rawDate.substring(0, 10)
              : rawDate;
        }

        final transaction = TransactionModel(
          // FIX: Store as ssp_{server_id} so we know it's a server record
          id: 'ssp_${expense['id']?.toString() ?? _uuid.v4()}',
          userId: userId,
          type: type,
          category: categoryName,
          amount: amount,
          date: date,
          note: expense['note']?.toString() ??
              expense['title']?.toString(),
          currency: 'LKR',
          isSynced: true,
        );

        await _db.insertTransaction(transaction);
      }
      await loadTransactions(userId);
    } catch (e) {
      debugPrint('API load failed: $e');
    }
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
        id: _uuid.v4(), // Local UUID until server assigns ID
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
        isSynced: false, // Not synced yet
      );

      // Step 1: Save to SQLite immediately
      await _db.insertTransaction(transaction);

      // Step 2: Update UI instantly
      _transactions.insert(0, transaction);
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();

      // Step 3: Sync to API if online
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

      // Step 1: Update SQLite
      await _db.updateTransaction(transaction);

      // Step 2: Update UI
      final index =
      _transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _transactions[index] = transaction;
        _transactions.sort((a, b) => b.date.compareTo(a.date));
        notifyListeners();
      }

      // Step 3: Sync to API
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none) {
        if (transaction.id.startsWith('ssp_')) {
          // FIX: Has server ID → use PUT to UPDATE existing record
          print('UPDATE ID: ${transaction.id}');
          await _updateOnApi(transaction);
        } else {
          // FIX: No server ID → use POST to CREATE on server
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

      // FIX: Always try API delete if online AND has server ID
      if (isOnline && id.startsWith('ssp_')) {
        // Strip ssp_ prefix to get real server numeric ID
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

      // Always delete from SQLite
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

  // ── Create on API (POST /api/expenses) ───────────────────────
  Future<void> _createOnApi(TransactionModel t) async {
    try {
      final payload = _buildPayload(t);
      print('📤 CREATE PAYLOAD: $payload');

      final result = await _sspApi.createExpense(payload);
      print('📥 CREATE RESULT: $result');

      if (result['success'] == true) {
        // FIX: Extract server ID and update local record
        // This ensures future edits/deletes use the correct server ID
        final responseData =
            result['data']?['data'] ?? result['data'];

        if (responseData != null && responseData['id'] != null) {
          final newId = 'ssp_${responseData['id']}';
          print('✅ Server ID assigned: $newId');

          // Update ID in SQLite
          await _db.updateTransactionId(t.id, newId);

          // Update in memory
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

  // ── Update on API (PUT /api/expenses/{id}) ───────────────────
  Future<void> _updateOnApi(TransactionModel t) async {
    try {
      final payload = _buildPayload(t);
      print('📤 UPDATE ID: ${t.id}');
      print('📤 UPDATE PAYLOAD: $payload');

      // FIX: Pass full ID — updateExpense() strips ssp_ prefix
      final result = await _sspApi.updateExpense(t.id, payload);
      print('📥 UPDATE RESULT: $result');

      if (result['success'] == true) {
        await _db.markAsSynced(t.id);
        _updateMemorySync(t.id, true);
        print('✅ Updated on server: ${t.category}');
      } else if (result['message'] == 'not_found') {
        // FIX: Record not found on server — create it instead
        print('⚠️ Not found on server — creating...');
        await _createOnApi(t);
      } else {
        print('❌ Update failed: ${result['message']}');
      }
    } catch (e) {
      print('❌ Update error: $e');
    }
  }

  // ── Build payload for Laravel API ───────────────────────────
  // FIX: Must match exactly what Laravel store()/update() expects
  Map<String, dynamic> _buildPayload(TransactionModel t) {
    return {
      'title': (t.note != null && t.note!.isNotEmpty)
          ? t.note
          : t.category,
      'amount': t.amount,
      'type': t.type,
      // FIX: Laravel expects category_id (integer) not category name
      'category_id': _getCategoryId(t.category),
      // FIX: Laravel expects expense_date not date
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

  // ── Auto sync all pending when internet returns ──────────────
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
          // Has server ID — update
          await _updateOnApi(t);
        } else {
          // No server ID — create
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

  // ── Category name → Laravel category_id ─────────────────────
  int _getCategoryId(String categoryName) {
    const categoryMap = {
      'Food & Drinks': 1,
      'Transport': 2,
      'Shopping': 3,
      'Bills': 4,
      'Health': 5,
      'Entertainment': 6,
      'Education': 7,
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