import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/ssp_api_service.dart';

// --- TRANSACTION PROVIDER ---
// This class manages all our spending data. 
// It uses an "Offline-First" approach: Save to device first, then sync to cloud.
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

  // --- Calculations for Charts ---
  
  // Sum up all income items
  double get totalIncome => _transactions
      .where((t) => t.type == 'income')
      .fold(0.0, (sum, t) => sum + t.amount);

  // Sum up all expense items
  double get totalExpense => _transactions
      .where((t) => t.type == 'expense')
      .fold(0.0, (sum, t) => sum + t.amount);

  // Remaining balance
  double get balance => totalIncome - totalExpense;

  // Get the last 5 transactions for the Dashboard preview
  List<TransactionModel> get recentTransactions =>
      _transactions.take(5).toList();

  // Simple math to predict monthly spend based on current daily average
  double get predictedMonthlyExpense {
    if (_transactions.isEmpty) return 0;
    final now = DateTime.now();
    final dayOfMonth = now.day;
    final totalDays = DateTime(now.year, now.month + 1, 0).day;
    return (totalExpense / dayOfMonth) * totalDays;
  }

  // --- Loading Data ---

  // Load transactions from SQLite so the app works offline
  Future<void> loadTransactions(String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Fetch from local database
      _transactions = await _db.getTransactions(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load local data.';
      notifyListeners();
    }
  }

  // Pull data from our Laravel SSP API and save it to the local device
  Future<void> loadFromApi(String userId) async {
    try {
      final apiExpenses = await _sspApi.getExpenses();
      for (final expense in apiExpenses) {
        
        // Map API fields (like 'title' or 'amount') to our TransactionModel
        String categoryName = 'Other';
        final cat = expense['category'];
        if (cat is Map) categoryName = cat['name']?.toString() ?? 'Other';
        else if (cat is String) categoryName = cat;

        final transaction = TransactionModel(
          id: 'ssp_${expense['id']?.toString() ?? _uuid.v4()}',
          userId: userId,
          type: expense['type']?.toString().toLowerCase() == 'income' ? 'income' : 'expense',
          category: categoryName,
          amount: double.tryParse(expense['amount'].toString()) ?? 0.0,
          date: expense['date']?.toString().substring(0, 10) ?? '',
          note: expense['note']?.toString() ?? expense['title']?.toString(),
        );

        // Save this API item into our local SQLite
        await _db.insertTransaction(transaction);
      }
      // Refresh the UI list after sync
      await loadTransactions(userId);
    } catch (e) {
      debugPrint('Sync from cloud failed, but that is fine, we have local data.');
    }
  }

  // --- Create Transaction ---
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

      // 1. Save to SQLite immediately (Offline Support)
      await _db.insertTransaction(transaction);
      
      // 2. Update the UI list instantly so the user sees it (Optimistic UI)
      _transactions.insert(0, transaction);
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();

      // 3. Try to sync to the Laravel AWS API in the background
      _syncToApi(transaction);

      return true;
    } catch (e) {
      _errorMessage = 'Failed to save transaction: $e';
      notifyListeners();
      return false;
    }
  }

  // Background sync helper
  Future<void> _syncToApi(TransactionModel transaction) async {
    try {
      await _sspApi.createExpense({
        'title': transaction.note?.isNotEmpty == true ? transaction.note : transaction.category,
        'amount': transaction.amount,
        'type': transaction.type,
        'category': transaction.category,
        'date': transaction.date,
      });
    } catch (e) {
      debugPrint('Offline: Transaction saved on device but not yet synced to cloud.');
    }
  }

  // Reset data on logout
  void clearData() {
    _transactions = [];
    notifyListeners();
  }
}
