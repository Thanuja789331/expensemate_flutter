import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

class TransactionProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final Uuid _uuid = const Uuid();

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

      await _db.insertTransaction(transaction);
      _transactions.insert(0, transaction);
      notifyListeners();
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
      final index = _transactions.indexWhere((t) => t.id == transaction.id);
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