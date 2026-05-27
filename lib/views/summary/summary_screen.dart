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

class _SummaryScreenState extends State<SummaryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  Map<String, dynamic> _exchangeRates = {};
  int _touchedPieIndex = -1;
  bool _isLoadingRates = false;
  String _selectedCurrency = 'USD';

  final List<Color> _chartColors = [
    const Color(0xFF1B8A5A),
    const Color(0xFF2196F3),
    const Color(0xFFFF9800),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFF00BCD4),
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
    final auth = context.read<AuthProvider>();
    final trans = context.read<TransactionProvider>();
    await trans.loadTransactions(auth.userId);
    await _loadExchangeRates();
  }

  Future<void> _loadExchangeRates() async {
    if (!mounted) return;
    setState(() => _isLoadingRates = true);
    try {
      final rates = await _apiService.getExchangeRates();
      if (mounted) {
        setState(() {
          _exchangeRates = rates;
          _isLoadingRates = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRates = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trans = context.watch<TransactionProvider>();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Summary'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Categories', icon: Icon(Icons.pie_chart, size: 18)),
            Tab(text: 'Trends', icon: Icon(Icons.bar_chart, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(trans, isLandscape),
          _buildWeeklyTab(trans, isLandscape),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(TransactionProvider provider, bool isLandscape) {
    final breakdown = provider.categoryBreakdown;
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isLandscape) 
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildPieChartSection(breakdown)),
                  const SizedBox(width: 24),
                  Expanded(flex: 3, child: _buildCurrencyConverter(provider.balance)),
                ],
              )
            else ...[
              _buildStatsRow(provider),
              const SizedBox(height: 24),
              _buildPieChartSection(breakdown),
              const SizedBox(height: 24),
              _buildCurrencyConverter(provider.balance),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(TransactionProvider provider) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(title: 'Total Income', value: 'Rs. ${provider.totalIncome.toStringAsFixed(0)}', icon: Icons.arrow_downward, color: AppTheme.incomeGreen)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(title: 'Total Expense', value: 'Rs. ${provider.totalExpense.toStringAsFixed(0)}', icon: Icons.arrow_upward, color: AppTheme.expenseRed)),
          ],
        ),
        const SizedBox(height: 12),
        _StatCard(title: 'Net Balance', value: 'Rs. ${provider.balance.toStringAsFixed(2)}', icon: Icons.account_balance_wallet, color: AppTheme.primaryGreen, isFullWidth: true),
      ],
    );
  }

  Widget _buildPieChartSection(Map<String, double> breakdown) {
    if (breakdown.isEmpty) return _buildEmptyChart('No category data available yet');
    
    final entries = breakdown.entries.toList();
    final total = breakdown.values.fold(0.0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Expense by Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(touchCallback: (event, response) {
                if (mounted) setState(() => _touchedPieIndex = response?.touchedSection?.touchedSectionIndex ?? -1);
              }),
              sections: entries.asMap().entries.map((entry) {
                final isTouched = entry.key == _touchedPieIndex;
                return PieChartSectionData(
                  value: entry.value.value,
                  title: isTouched ? '${(entry.value.value / total * 100).toStringAsFixed(0)}%' : '',
                  radius: isTouched ? 60 : 50,
                  color: _chartColors[entry.key % _chartColors.length],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12, runSpacing: 8,
          children: entries.asMap().entries.map((entry) => _LegendItem(color: _chartColors[entry.key % _chartColors.length], label: entry.value.key)).toList(),
        ),
      ],
    );
  }

  Widget _buildCurrencyConverter(double balanceLKR) {
    if (_isLoadingRates) return const Center(child: CircularProgressIndicator());
    final rate = (_exchangeRates[_selectedCurrency] as num?)?.toDouble() ?? 0.0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.currency_exchange, color: AppTheme.primaryGreen), SizedBox(width: 8), Text('Live Exchange Rates', style: TextStyle(fontWeight: FontWeight.bold))]),
            const Divider(),
            DropdownButton<String>(
              value: _selectedCurrency,
              isExpanded: true,
              items: ['USD', 'EUR', 'GBP', 'INR', 'AUD'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCurrency = v!),
            ),
            const SizedBox(height: 16),
            Text('Rs. ${balanceLKR.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, color: Colors.grey)),
            Text('${_selectedCurrency == 'USD' ? '$' : _selectedCurrency} ${(balanceLKR * rate).toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
            Text('1 LKR = $rate $_selectedCurrency', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTab(TransactionProvider provider, bool isLandscape) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weeklyData = <String, Map<String, double>>{};
    for (var d in days) weeklyData[d] = {'income': 0.0, 'expense': 0.0};
    
    for (var t in provider.transactions) {
      try {
        final d = days[DateTime.parse(t.date).weekday - 1];
        weeklyData[d]![t.type] = (weeklyData[d]![t.type] ?? 0) + t.amount;
      } catch (_) {}
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('Weekly Financial Trends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: days.asMap().entries.map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(toY: weeklyData[e.value]!['income']!, color: AppTheme.incomeGreen, width: 8),
                    BarChartRodData(toY: weeklyData[e.value]!['expense']!, color: AppTheme.expenseRed, width: 8),
                  ],
                )).toList(),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(days[v.toInt()], style: const TextStyle(fontSize: 10)))),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _StatCard(title: 'Estimated Monthly Spending', value: 'Rs. ${provider.predictedMonthlyExpense.toStringAsFixed(0)}', icon: Icons.analytics_outlined, color: Colors.blue, isFullWidth: true),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(String msg) {
    return Center(child: Column(children: [const Icon(Icons.insert_chart_outlined, size: 64, color: Colors.grey), Text(msg, style: const TextStyle(color: Colors.grey))]));
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final bool isFullWidth;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color, this.isFullWidth = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}