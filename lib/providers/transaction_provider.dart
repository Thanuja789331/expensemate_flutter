import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/ssp_api_service.dart';

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

  // ── Recent transactions (last 5) ─────────────────────────────
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
    if (transactions.isEmpty) return 0;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return totalExpense / daysInMonth;
  }

  double get predictedMonthlyExpense {
    final now = DateTime.now();
    final dayOfMonth = now.day;
    if (dayOfMonth == 0) return 0;
    return (totalExpense / dayOfMonth) *
        DateTime(now.year, now.month + 1, 0).day;
  }

  // ── Category breakdown for pie chart ─────────────────────────
  Map<String, double> get categoryBreakdown {
    Map<String, double> breakdown = {};
    for (var t in _transactions.where((t) => t.type == 'expense')) {
      breakdown[t.category] = (breakdown[t.category] ?? 0) + t.amount;
    }
    return breakdown;
  }

  // ── Load all transactions for a user ─────────────────────────
  Future<void> loadTransactions(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _transactions = await _db.getTransactions(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load transactions.';
      notifyListeners();
    }
  }

  // ── Load transactions from SSP API + SQLite ──────────────────
  Future<void> loadFromApi(String userId) async {
    try {
      final apiExpenses = await _sspApi.getExpenses();
      for (final expense in apiExpenses) {

        // ── Handle category ──────────────────────────────────────
        String categoryName = 'Other';
        final cat = expense['category'];
        if (cat is Map) {
          categoryName = cat['name']?.toString() ?? 'Other';
        } else if (cat is String) {
          categoryName = cat;
        }

        // ── Handle amount ────────────────────────────────────────
        double amount = 0.0;
        final rawAmount = expense['amount'];
        if (rawAmount is num) {
          amount = rawAmount.toDouble();
        } else if (rawAmount is String) {
          amount = double.tryParse(rawAmount) ?? 0.0;
        }

        // ── Handle type ──────────────────────────────────────────
        String type = 'expense';
        final rawType = expense['type'];
        if (rawType is String) {
          type = rawType.toLowerCase() == 'income' ? 'income' : 'expense';
        }

        // ── Handle date ──────────────────────────────────────────
        String date = '';
        final rawDate = expense['date'] ??
            expense['created_at'] ??
            expense['expense_date'];
        if (rawDate is String) {
          date = rawDate.length > 10
              ? rawDate.substring(0, 10)
              : rawDate;
        }

        // ── Handle note/title ────────────────────────────────────
        String? note = expense['note']?.toString() ??
            expense['title']?.toString() ??
            expense['description']?.toString();

        final transaction = TransactionModel(
          id: 'ssp_${expense['id']?.toString() ?? _uuid.v4()}',
          userId: userId,
          type: type,
          category: categoryName,
          amount: amount,
          date: date,
          note: note,
        );

        await _db.insertTransaction(transaction);
      }
      await loadTransactions(userId);
    } catch (e) {
      // Silent fail — use local data
    }
  }

  // ── Add new transaction ──────────────────────────────────────
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
  }) async {
    try {
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
      );

      // Save to SQLite first (offline-first)
      await _db.insertTransaction(transaction);
      _transactions.insert(0, transaction);
      notifyListeners();

      // Sync to SSP API in background
      _syncToApi(transaction);

      return true;
    } catch (e) {
      _errorMessage = 'Failed to add transaction.';
      notifyListeners();
      return false;
    }
  }

  // ── Update existing transaction ──────────────────────────────
  Future<bool> updateTransaction(TransactionModel transaction) async {
    try {
      await _db.updateTransaction(transaction);
      final index =
      _transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _transactions[index] = transaction;
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
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete transaction.';
      notifyListeners();
      return false;
    }
  }

  // ── Filter transactions ──────────────────────────────────────
  List<TransactionModel> filterTransactions(String filter) {
    if (filter == 'all') return _transactions;
    return _transactions.where((t) => t.type == filter).toList();
  }

  // ── Search transactions ──────────────────────────────────────
  List<TransactionModel> searchTransactions(String query) {
    if (query.isEmpty) return _transactions;
    return _transactions.where((t) {
      return t.category.toLowerCase().contains(query.toLowerCase()) ||
          (t.note?.toLowerCase().contains(query.toLowerCase()) ?? false);
    }).toList();
  }

  // ── Sync to SSP API ──────────────────────────────────────────
  Future<void> _syncToApi(TransactionModel transaction) async {
    try {
      await _sspApi.createExpense({
        'title': transaction.note ?? transaction.category,
        'amount': transaction.amount,
        'type': transaction.type,
        'category': transaction.category,
        'category_id': _getCategoryId(transaction.category),
        'date': transaction.date,
        'note': transaction.note ?? '',
        'expense_date': transaction.date,
      });
    } catch (e) {
      // Silent fail
    }
  }

  // ── Map category name to ID ──────────────────────────────────
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
    return categoryMap[categoryName] ?? 1;
  }

  // ── Clear error ──────────────────────────────────────────────
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Clear all data on logout ─────────────────────────────────
  void clearData() {
    _transactions = [];
    notifyListeners();
  }
}