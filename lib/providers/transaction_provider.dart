import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/ssp_api_service.dart';

// --- TRANSACTION PROVIDER ---
// Offline-First approach: Save to SQLite first, then sync to cloud.
class TransactionProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final Uuid _uuid = const Uuid();
  final SspApiService _sspApi = SspApiService();

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  // ── Budget calculations ──────────────────────────────────────
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
    final percentage = budgetUsedPercentage;
    if (percentage >= 100) return 'exceeded';
    if (percentage >= 80) return 'warning';
    return 'safe';
  }

  double get dailyAverage {
    if (_transactions.isEmpty) return 0;
    final now = DateTime.now();
    final dayOfMonth = now.day;
    if (dayOfMonth == 0) return 0;
    return totalExpense / dayOfMonth;
  }

  double get predictedMonthlyExpense {
    if (_transactions.isEmpty) return 0;
    final now = DateTime.now();
    final dayOfMonth = now.day;
    final totalDays = DateTime(now.year, now.month + 1, 0).day;
    if (dayOfMonth == 0) return 0;
    return (totalExpense / dayOfMonth) * totalDays;
  }

  // ── Category breakdown for pie chart ─────────────────────────
  Map<String, double> get categoryBreakdown {
    Map<String, double> breakdown = {};
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
      _errorMessage = 'Failed to load local data.';
      notifyListeners();
    }
  }

  // ── Load from SSP API ────────────────────────────────────────
  Future<void> loadFromApi(String userId) async {
    try {
      final apiExpenses = await _sspApi.getExpenses();
      for (final expense in apiExpenses) {
        String categoryName = 'Other';
        final cat = expense['category'];
        if (cat is Map) {
          categoryName = cat['name']?.toString() ?? 'Other';
        } else if (cat is String) {
          categoryName = cat;
        }

        double amount = 0.0;
        final rawAmount = expense['amount'];
        if (rawAmount is num) {
          amount = rawAmount.toDouble();
        } else if (rawAmount is String) {
          amount = double.tryParse(rawAmount) ?? 0.0;
        }

        String type = 'expense';
        final rawType = expense['type'];
        if (rawType is String) {
          type = rawType.toLowerCase() == 'income' ? 'income' : 'expense';
        }

        String date = '';
        final rawDate = expense['expense_date'] ??
            expense['date'] ??
            expense['created_at'];
        if (rawDate is String) {
          date = rawDate.length > 10
              ? rawDate.substring(0, 10)
              : rawDate;
        }

        String? note = expense['note']?.toString() ??
            expense['title']?.toString();

        final transaction = TransactionModel(
          id: 'ssp_${expense['id']?.toString() ?? _uuid.v4()}',
          userId: userId,
          type: type,
          category: categoryName,
          amount: amount,
          date: date,
          note: note,
          currency: 'LKR',
        );

        await _db.insertTransaction(transaction);
      }
      await loadTransactions(userId);
    } catch (e) {
      debugPrint('Cloud sync failed — using local data: $e');
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

      final transaction = TransactionModel(
        id: _uuid.v4(),
        userId: userId,
        type: type,
        category: category,
        amount: amount,
        date: date,
        note: note,
        imagePath: imagePath,
        latitude: latitude,
        longitude: longitude,
        currency: currency,
      );

      // 1 — Save to SQLite immediately (offline-first)
      await _db.insertTransaction(transaction);

      // 2 — Update UI instantly
      _transactions.insert(0, transaction);
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();

      // 3 — Sync to API in background
      _syncToApi(transaction);

      return true;
    } catch (e) {
      _errorMessage = 'Failed to save transaction: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Update transaction ───────────────────────────────────────
  Future<bool> updateTransaction(TransactionModel transaction) async {
    try {
      await _db.updateTransaction(transaction);
      final index =
      _transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _transactions[index] = transaction;
        _transactions.sort((a, b) => b.date.compareTo(a.date));
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update transaction.';
      notifyListeners();
      return false;
    }
  }

  // ── Delete transaction ───────────────────────────────────────
  Future<bool> deleteTransaction(String id) async {
    try {
      await _db.deleteTransaction(id);
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();
      _sspApi.deleteExpense(id);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete transaction.';
      notifyListeners();
      return false;
    }
  }

  // ── Sync to SSP API ──────────────────────────────────────────
  // KEY FIX: Use category_id and expense_date as Laravel expects
  Future<void> _syncToApi(TransactionModel transaction) async {
    try {
      final payload = {
        'title': transaction.note?.isNotEmpty == true
            ? transaction.note
            : transaction.category,
        'amount': transaction.amount,
        'type': transaction.type,
        'category_id': _getCategoryId(transaction.category),
        'expense_date': transaction.date,
        'note': transaction.note ?? '',
      };

      print('📤 Syncing to API: $payload');
      final result = await _sspApi.createExpense(payload);
      print('📥 Sync result: $result');

      if (result['success'] == true) {
        print('✅ Expense synced to SSP API successfully!');
      } else {
        print('❌ Sync failed: ${result['message']}');
      }
    } catch (e) {
      print('❌ Sync error: $e');
      debugPrint('Offline: Transaction saved locally, sync failed.');
    }
  }

  // ── Map category name → Laravel category_id ─────────────────
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

  // ── Search & Filter ──────────────────────────────────────────
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

  // ── Clear data on logout ─────────────────────────────────────
  void clearData() {
    _transactions = [];
    notifyListeners();
  }
}