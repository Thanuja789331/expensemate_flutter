import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/api_service.dart';
import '../../services/device_service.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final DeviceService _deviceService = DeviceService();

  bool _isOnline = true;
  List<Map<String, dynamic>> _tips = [];
  int _currentTipIndex = 0;
  StreamSubscription? _shakeSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initDeviceFeatures();
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    super.dispose();
  }

  // ── Load all data ────────────────────────────────────────────
  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    await transactionProvider.loadTransactions(authProvider.userId);
    await _loadTips();
  }

  // ── Load tips from API or local JSON ─────────────────────────
  Future<void> _loadTips() async {
    final tips = await _apiService.getTipsFromApi();
    if (mounted) {
      setState(() => _tips = tips);
    }
  }

  // ── Init device features ─────────────────────────────────────
  Future<void> _initDeviceFeatures() async {
    final online = await _deviceService.isOnline();

    if (mounted) {
      setState(() {
        _isOnline = online;
      });
    }

    // Listen for connectivity changes
    _deviceService.connectivityStream.listen((result) {
      if (mounted) {
        setState(() => _isOnline = result.name != 'none');
      }
    });

    // Shake to refresh
    _shakeSubscription = _deviceService.shakeStream.listen((_) {
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.refresh, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Refreshed!'),
              ],
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primaryGreen,
        child: CustomScrollView(
          slivers: [

            // ── App Bar ──────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: theme.colorScheme.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [


                          // Greeting
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getGreeting(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    authProvider.userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              // Device status — connectivity only
                              Row(
                                children: [
                                  Icon(
                                    _isOnline ? Icons.wifi : Icons.wifi_off,
                                    color: _isOnline ? Colors.white : Colors.red[300],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isOnline ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      color: _isOnline ? Colors.white : Colors.red[300],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Balance
                          const Text(
                            'Total Balance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Rs. ${transactionProvider.balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),

            // ── Body Content ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Offline banner
                    if (!_isOnline)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.wifi_off,
                                color: Colors.orange, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'You are offline. Showing local data.',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                      ).animate().fadeIn().slideY(begin: -0.2),

                    // ── Income / Expense Cards ──────────────
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Income',
                            amount: transactionProvider.totalIncome,
                            icon: Icons.arrow_downward,
                            color: AppTheme.incomeGreen,
                          )
                              .animate()
                              .fadeIn(delay: 200.ms)
                              .slideX(begin: -0.2, end: 0),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Expense',
                            amount: transactionProvider.totalExpense,
                            icon: Icons.arrow_upward,
                            color: AppTheme.expenseRed,
                          )
                              .animate()
                              .fadeIn(delay: 300.ms)
                              .slideX(begin: 0.2, end: 0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Quick Actions ───────────────────────
                    Text(
                      'Quick Actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Row 1 — 3 buttons
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.add,
                            label: 'Add Expense',
                            color: AppTheme.expenseRed,
                            onTap: () => context.go('/add-expense'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.savings,
                            label: 'Add Income',
                            color: AppTheme.incomeGreen,
                            onTap: () => context.go(
                              '/add-expense',
                              extra: {'type': 'income'},
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.bar_chart,
                            label: 'Summary',
                            color: AppTheme.primaryGreen,
                            onTap: () => context.go('/summary'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 2 — Tips button only
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.tips_and_updates,
                            label: 'Tips',
                            color: Colors.blue,
                            onTap: () => context.go('/tips'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Shake Hint Card ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryGreen.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('📳', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Shake to Refresh',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                Text(
                                  'Shake your phone to refresh transactions',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.refresh,
                            color: AppTheme.primaryGreen.withOpacity(0.5),
                            size: 20,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 350.ms),

                    const SizedBox(height: 16),

                    // ── Financial Tip ───────────────────────
                    if (_tips.isNotEmpty) ...[
                      Text(
                        'Financial Tip',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TipCard(tip: _tips[_currentTipIndex])
                          .animate()
                          .fadeIn(delay: 400.ms),
                      const SizedBox(height: 24),
                    ],

                    // ── Recent Transactions ─────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/dashboard'),
                          child: const Text('See All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Transaction list
                    transactionProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : transactionProvider.recentTransactions.isEmpty
                        ? _EmptyState()
                        : Column(
                      children: transactionProvider
                          .recentTransactions
                          .asMap()
                          .entries
                          .map(
                            (entry) => _TransactionTile(
                          transaction: entry.value,
                        )
                            .animate()
                            .fadeIn(
                          delay: Duration(
                            milliseconds:
                            200 + (entry.key * 100),
                          ),
                        )
                            .slideX(begin: 0.2, end: 0),
                      )
                          .toList(),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Greeting based on time ───────────────────────────────────
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }
}

// ── Summary Card Widget ──────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rs. ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Action Button Widget ───────────────────────────────────
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tip Card Widget ──────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final Map<String, dynamic> tip;

  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withOpacity(0.1),
            AppTheme.primaryGreen.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: AppTheme.primaryGreen,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip['title'] ?? '',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip['description'] ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction Tile Widget ──────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == 'expense';
    final color = isExpense ? AppTheme.expenseRed : AppTheme.incomeGreen;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isExpense ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          transaction.category,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          transaction.note ?? transaction.date,
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'}Rs. ${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ── Empty State Widget ───────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + Add Expense to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}