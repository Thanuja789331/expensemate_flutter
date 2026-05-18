import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  Map<String, dynamic> _exchangeRates = {};
  int _touchedPieIndex = -1;
  bool _isLoadingRates = false;
  String _selectedCurrency = 'USD';

  // Chart colours
  final List<Color> _chartColors = [
    const Color(0xFF1B8A5A),
    const Color(0xFF2196F3),
    const Color(0xFFFF9800),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFF00BCD4),
    const Color(0xFFFF5722),
    const Color(0xFF8BC34A),
    const Color(0xFFFFEB3B),
    const Color(0xFF607D8B),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    await transactionProvider.loadTransactions(authProvider.userId);
    await _loadExchangeRates();
  }

  Future<void> _loadExchangeRates() async {
    setState(() => _isLoadingRates = true);
    final rates = await _apiService.getExchangeRates();
    if (mounted) {
      setState(() {
        _exchangeRates = rates;

        _isLoadingRates = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = context.watch<TransactionProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.pie_chart, size: 18)),
            Tab(text: 'Weekly', icon: Icon(Icons.bar_chart, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Overview Tab ───────────────────────────────────
          _buildOverviewTab(transactionProvider, theme),
          // ── Weekly Tab ─────────────────────────────────────
          _buildWeeklyTab(transactionProvider, theme),
        ],
      ),
    );
  }

  // ── Overview Tab ─────────────────────────────────────────────
  Widget _buildOverviewTab(
      TransactionProvider provider, ThemeData theme) {
    final breakdown = provider.categoryBreakdown;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryGreen,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Stats Row ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Income',
                    value: 'Rs. ${provider.totalIncome.toStringAsFixed(2)}',
                    icon: Icons.arrow_downward,
                    color: AppTheme.incomeGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Total Expense',
                    value: 'Rs. ${provider.totalExpense.toStringAsFixed(2)}',
                    icon: Icons.arrow_upward,
                    color: AppTheme.expenseRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Balance',
                    value: 'Rs. ${provider.balance.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet,
                    color: provider.balance >= 0
                        ? AppTheme.primaryGreen
                        : AppTheme.expenseRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Transactions',
                    value: '${provider.transactions.length}',
                    icon: Icons.receipt_long,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Pie Chart ──────────────────────────────────
            Text(
              'Expense Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            breakdown.isEmpty
                ? _buildEmptyChart()
                : _buildPieChart(breakdown),

            const SizedBox(height: 24),

            // ── Currency Converter ─────────────────────────
            Text(
              'Currency Converter',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildCurrencyConverter(provider.balance),
          ],
        ),
      ),
    );
  }

  // ── Pie Chart ────────────────────────────────────────────────
  Widget _buildPieChart(Map<String, double> breakdown) {
    final entries = breakdown.entries.toList();
    final total = breakdown.values.fold(0.0, (a, b) => a + b);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedPieIndex = -1;
                      return;
                    }
                    _touchedPieIndex =
                        response.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sections: entries.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isTouched = index == _touchedPieIndex;
                final percentage = (item.value / total * 100);

                return PieChartSectionData(
                  value: item.value,
                  title: isTouched
                      ? '${percentage.toStringAsFixed(1)}%'
                      : '',
                  radius: isTouched ? 80 : 65,
                  color: _chartColors[index % _chartColors.length],
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: entries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final percentage = (item.value / total * 100);

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _chartColors[index % _chartColors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.key} (${percentage.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Currency Converter ───────────────────────────────────────
  Widget _buildCurrencyConverter(double balanceLKR) {
    if (_isLoadingRates) {
      return const Center(child: CircularProgressIndicator());
    }

    final currencies = [
      {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar', 'flag': '🇺🇸'},
      {'code': 'EUR', 'symbol': '€', 'name': 'Euro', 'flag': '🇪🇺'},
      {'code': 'GBP', 'symbol': '£', 'name': 'British Pound', 'flag': '🇬🇧'},
      {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar', 'flag': '🇦🇺'},
      {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar', 'flag': '🇨🇦'},
      {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen', 'flag': '🇯🇵'},
      {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee', 'flag': '🇮🇳'},
      {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar', 'flag': '🇸🇬'},
      {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham', 'flag': '🇦🇪'},
      {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan', 'flag': '🇨🇳'},
    ];

    final selectedCurrencyData = currencies.firstWhere(
          (c) => c['code'] == _selectedCurrency,
      orElse: () => currencies.first,
    );

    final rate = (_exchangeRates[_selectedCurrency] as num?)?.toDouble() ?? 0.0;
    final converted = balanceLKR * rate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.currency_exchange,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Currency Converter',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadExchangeRates,
                  color: AppTheme.primaryGreen,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Amount in LKR
            Text(
              'Rs. ${balanceLKR.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sri Lankan Rupee',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Currency dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCurrency,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppTheme.primaryGreen,
                  ),
                  items: currencies.map((currency) {
                    return DropdownMenuItem<String>(
                      value: currency['code'],
                      child: Row(
                        children: [
                          Text(
                            currency['flag']!,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currency['name']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                currency['code']!,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCurrency = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Converted amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGreen.withOpacity(0.1),
                    AppTheme.primaryGreen.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${selectedCurrencyData['flag']} ${selectedCurrencyData['symbol']}${converted.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedCurrencyData['name']!,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  if (rate > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '1 LKR = ${rate.toStringAsFixed(6)} ${selectedCurrencyData['code']}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Weekly Tab ───────────────────────────────────────────────
  Widget _buildWeeklyTab(
      TransactionProvider provider, ThemeData theme) {
    final transactions = provider.transactions;

    // Group by day of week
    final Map<String, Map<String, double>> weeklyData = {};
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (var day in days) {
      weeklyData[day] = {'income': 0.0, 'expense': 0.0};
    }

    for (var t in transactions) {
      try {
        final date = DateTime.parse(t.date);
        final dayName = days[date.weekday - 1];
        weeklyData[dayName]![t.type] =
            (weeklyData[dayName]![t.type] ?? 0) + t.amount;
      } catch (e) {
        continue;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Overview',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          transactions.isEmpty
              ? _buildEmptyChart()
              : _buildBarChart(weeklyData, days),

          const SizedBox(height: 24),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: AppTheme.incomeGreen, label: 'Income'),
              const SizedBox(width: 24),
              _LegendItem(color: AppTheme.expenseRed, label: 'Expense'),
            ],
          ),
          const SizedBox(height: 24),

          // Weekly summary cards
          Text(
            'This Week',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildWeeklySummary(provider),
        ],
      ),
    );
  }

  // ── Bar Chart ────────────────────────────────────────────────
  Widget _buildBarChart(
      Map<String, Map<String, double>> weeklyData, List<String> days) {
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMaxValue(weeklyData) * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = days[groupIndex];
                final type = rodIndex == 0 ? 'Income' : 'Expense';
                return BarTooltipItem(
                  '$day\n$type: Rs.${rod.toY.toStringAsFixed(0)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    days[value.toInt()],
                    style: const TextStyle(fontSize: 11),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('');
                  return Text(
                    'Rs.${value.toInt()}',
                    style: const TextStyle(fontSize: 9),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            drawHorizontalLine: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: days.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: weeklyData[day]!['income']!,
                  color: AppTheme.incomeGreen,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                BarChartRodData(
                  toY: weeklyData[day]!['expense']!,
                  color: AppTheme.expenseRed,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Weekly Summary ───────────────────────────────────────────
  Widget _buildWeeklySummary(TransactionProvider provider) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    final weekTransactions = provider.transactions.where((t) {
      try {
        final date = DateTime.parse(t.date);
        return date.isAfter(weekStart.subtract(const Duration(days: 1)));
      } catch (e) {
        return false;
      }
    }).toList();

    final weekIncome = weekTransactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    final weekExpense = weekTransactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Week Income',
            value: 'Rs. ${weekIncome.toStringAsFixed(2)}',
            icon: Icons.trending_up,
            color: AppTheme.incomeGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Week Expense',
            value: 'Rs. ${weekExpense.toStringAsFixed(2)}',
            icon: Icons.trending_down,
            color: AppTheme.expenseRed,
          ),
        ),
      ],
    );
  }

  // ── Empty Chart State ────────────────────────────────────────
  Widget _buildEmptyChart() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              'No data yet',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Get max value for bar chart ──────────────────────────────
  double _getMaxValue(Map<String, Map<String, double>> data) {
    double max = 0;
    for (var day in data.values) {
      for (var value in day.values) {
        if (value > max) max = value;
      }
    }
    return max == 0 ? 100 : max;
  }
}

// ── Stat Card Widget ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Legend Item Widget ───────────────────────────────────────────
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}