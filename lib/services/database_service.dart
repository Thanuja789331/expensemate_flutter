import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';

// --- DATABASE SERVICE (SQLite) ---
// Handles all local storage so the app works fully offline.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expensemate.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  // Handles upgrades without losing user data
  Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN currency TEXT DEFAULT "LKR"',
        );
      } catch (e) {
        // Column may already exist
      }
    }
    if (oldVersion < 3) {
      // 0 = pending sync, 1 = synced to API
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN isSynced INTEGER DEFAULT 1',
        );
      } catch (e) {
        // Column may already exist
      }
    }
  }

  // Runs on fresh install
  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id        TEXT PRIMARY KEY,
        userId    TEXT NOT NULL,
        type      TEXT NOT NULL,
        category  TEXT NOT NULL,
        amount    REAL NOT NULL,
        date      TEXT NOT NULL,
        note      TEXT,
        imagePath TEXT,
        latitude  REAL,
        longitude REAL,
        currency  TEXT DEFAULT 'LKR',
        isSynced  INTEGER DEFAULT 1
      )
    ''');
  }

  // Save transaction — REPLACE handles duplicates during sync
  Future<void> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all transactions for a user newest first
  Future<List<TransactionModel>> getTransactions(String userId) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  // Get only unsynced transactions for background sync
  Future<List<TransactionModel>> getUnsyncedTransactions(
      String userId) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'userId = ? AND isSynced = 0',
      whereArgs: [userId],
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  // Mark a transaction as synced after successful API upload
  Future<void> markAsSynced(String id) async {
    final db = await database;
    await db.update(
      'transactions',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // FIX: Replace local UUID with server-assigned ID after sync
  // Called after a local transaction is successfully created on server
  // e.g. local UUID 'abc-123' becomes 'ssp_41'
  Future<void> updateTransactionId(String oldId, String newId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE transactions SET id = ?, isSynced = 1 WHERE id = ?',
      [newId, oldId],
    );
    print('✅ DB ID updated: $oldId → $newId');
  }

  // Edit an existing record
  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // Remove a record
  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}