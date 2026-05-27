import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';

// --- DATABASE SERVICE (SQLite) ---
// This handles all local storage on the phone so the app works offline.
class DatabaseService {
  // Singleton: Only one instance of the database exists in the app
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  // Getter to initialize the database if it doesn't exist
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Set up the database file path
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expensemate.db');

    return await openDatabase(
      path,
      version: 2, // Upgraded from 1 to 2 to add the 'currency' column
      onCreate: _createTables,
      onUpgrade: _onUpgrade, // Migration logic for existing users
    );
  }

  // Runs only if an older version of the database is found on the device
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Viva: This adds a new column without deleting existing user data
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN currency TEXT DEFAULT "LKR"');
      } catch (e) {
        // Safe to ignore if column exists
      }
    }
  }

  // Runs the first time the app is installed
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
      longitude REAL,
      currency TEXT DEFAULT 'LKR'
    )
  ''');
  }

  // --- CRUD METHODS ---

  // Save transaction locally (uses "Replace" to handle duplicates during sync)
  Future<void> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all items for a user, newest items at the top
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

  // Remove a record by its unique ID
  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
