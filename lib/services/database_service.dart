import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';

class DatabaseService {
  // Singleton pattern — only one instance of database
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  // ── Get Database ─────────────────────────────────────────────
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // ── Initialise Database ──────────────────────────────────────
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expensemate.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  // ── Create Tables ────────────────────────────────────────────
  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        imagePath TEXT,
        latitude REAL,
        longitude REAL
      )
    ''');
  }

  // ── CREATE — Insert new transaction ──────────────────────────
  Future<void> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── READ — Get all transactions for a user ───────────────────
  Future<List<TransactionModel>> getTransactions(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  // ── READ — Get single transaction by id ─────────────────────
  Future<TransactionModel?> getTransactionById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return TransactionModel.fromMap(maps.first);
  }

  // ── UPDATE — Edit existing transaction ───────────────────────
  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // ── DELETE — Remove a transaction ────────────────────────────
  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── DELETE — Remove all transactions for a user ──────────────
  Future<void> deleteAllTransactions(String userId) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  // ── SUMMARY — Total income for a user ────────────────────────
  Future<double> getTotalIncome(String userId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM transactions 
      WHERE userId = ? AND type = 'income'
    ''', [userId]);
    return (result.first['total'] as double?) ?? 0.0;
  }

  // ── SUMMARY — Total expense for a user ───────────────────────
  Future<double> getTotalExpense(String userId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM transactions 
      WHERE userId = ? AND type = 'expense'
    ''', [userId]);
    return (result.first['total'] as double?) ?? 0.0;
  }

  // ── SUMMARY — Spending by category ───────────────────────────
  Future<Map<String, double>> getCategoryBreakdown(String userId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE userId = ? AND type = 'expense'
      GROUP BY category
    ''', [userId]);

    Map<String, double> breakdown = {};
    for (var row in result) {
      breakdown[row['category'] as String] = (row['total'] as double?) ?? 0.0;
    }
    return breakdown;
  }

  // ── SUMMARY — Weekly data for bar chart ──────────────────────
  Future<Map<String, Map<String, double>>> getWeeklyData(
      String userId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT date, type, SUM(amount) as total
      FROM transactions
      WHERE userId = ?
      GROUP BY date, type
      ORDER BY date DESC
      LIMIT 14
    ''', [userId]);

    Map<String, Map<String, double>> weeklyData = {};
    for (var row in result) {
      final date = row['date'] as String;
      final type = row['type'] as String;
      final total = (row['total'] as double?) ?? 0.0;

      weeklyData[date] ??= {'income': 0.0, 'expense': 0.0};
      weeklyData[date]![type] = total;
    }
    return weeklyData;
  }
}