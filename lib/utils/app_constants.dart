class AppConstants {
  AppConstants._();

  // ── App Info ─────────────────────────────────────────────────
  static const String appName = 'ExpenseMate';
  static const String appVersion = '1.0.0';

  // ── SQLite ───────────────────────────────────────────────────
  static const String dbName = 'expensemate.db';
  static const int dbVersion = 1;
  static const String transactionsTable = 'transactions';

  // ── SharedPreferences keys ───────────────────────────────────
  static const String prefThemeMode = 'theme_mode';
  static const String prefCurrency = 'currency';
  static const String prefMonthlyBudget = 'monthly_budget';

  // ── SSP API ──────────────────────────────────────────────────
  static const String sspBaseUrl =
      'http://expensemate-prod.eba-3ztxbse2.ap-southeast-1.elasticbeanstalk.com/api';
  static const String sspLoginUrl = '$sspBaseUrl/auth/login';
  static const String sspLogoutUrl = '$sspBaseUrl/auth/logout';
  static const String sspMeUrl = '$sspBaseUrl/auth/me';
  static const String sspExpensesUrl = '$sspBaseUrl/expenses';
  static const String sspSummaryUrl = '$sspBaseUrl/summary';

  // ── Public APIs ──────────────────────────────────────────────
  static const String jsonPlaceholderBaseUrl =
      'https://jsonplaceholder.typicode.com';
  static const String exchangeRateBaseUrl =
      'https://api.exchangerate-api.com/v4/latest/LKR';

  // ── Currencies ───────────────────────────────────────────────
  static const List<Map<String, String>> supportedCurrencies = [
    {'code': 'LKR', 'symbol': 'Rs', 'name': 'Sri Lankan Rupee'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
  ];

  // ── Transaction types ────────────────────────────────────────
  static const String typeExpense = 'expense';
  static const String typeIncome = 'income';

  // ── Animation durations ──────────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 400);
  static const Duration animSlow = Duration(milliseconds: 600);

  // ── Default budget ───────────────────────────────────────────
  static const double defaultMonthlyBudget = 50000.0;
}