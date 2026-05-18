import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';

class BudgetPlannerScreen extends StatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  State<BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<BudgetPlannerScreen> {
  final _budgetController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransactionProvider>();
    _budgetController.text = provider.monthlyBudget.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  // ── Save budget ──────────────────────────────────────────────
  void _saveBudget() {
    final value = double.tryParse(_budgetController.text);
    if (value != null && value > 0) {
      context.read<TransactionProvider>().setMonthlyBudget(value);
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Budget updated!'),
            ],
          ),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }



  // ── Get status color ─────────────────────────────────────────
  Color _getStatusColor(String status) {
    switch (status) {
      case 'exceeded':
        return AppTheme.expenseRed;
      case 'warning':
        return AppTheme.warningAmber;
      default:
        return AppTheme.primaryGreen;
    }
  }

  // ── Get status icon ──────────────────────────────────────────
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'exceeded':
        return Icons.warning_rounded;
      case 'warning':
        return Icons.info_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  // ── Get status message ───────────────────────────────────────
  String _getStatusMessage(String status, double remaining) {
    switch (status) {
      case 'exceeded':
        return 'Budget exceeded by Rs. ${remaining.abs().toStringAsFixed(2)}!';
      case 'warning':
        return 'Only Rs. ${remaining.toStringAsFixed(2)} remaining!';
      default:
        return 'Rs. ${remaining.toStringAsFixed(2)} remaining — on track!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final theme = Theme.of(context);
    final status = provider.budgetStatus;
    final statusColor = _getStatusColor(status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Planner'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Budget Setting Card ──────────────────────────
            Card(
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
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Monthly Budget',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    //Bg image
                    Center(
                      child: Image.asset(
                        'assets/images/budget.png',
                        height: 180,
                      ),
                    ),

                    // Budget amount or edit field
                    _isEditing
                        ? Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _budgetController,
                            keyboardType: const TextInputType
                                .numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Monthly Budget',
                              prefixText: 'Rs. ',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            autofocus: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _saveBudget,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(80, 52),
                          ),
                          child: const Text('Save'),
                        ),
                      ],
                    )
                        : Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rs. ${provider.monthlyBudget.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _isEditing = true),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Change'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 16),

            // ── Status Banner ────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: statusColor,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status == 'exceeded'
                              ? '⚠️ Budget Exceeded!'
                              : status == 'warning'
                              ? '⚡ Warning!'
                              : '✅ On Track',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          _getStatusMessage(
                              status, provider.remainingBudget),
                          style: TextStyle(
                            color: statusColor.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 16),

            // ── Progress Card ────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Budget Used',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${provider.budgetUsedPercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: provider.budgetUsedPercentage / 100,
                        ),
                        duration: const Duration(milliseconds: 800),
                        builder: (context, value, _) =>
                            LinearProgressIndicator(
                              value: value,
                              minHeight: 16,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                statusColor,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spent: Rs. ${provider.totalExpense.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppTheme.expenseRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Budget: Rs. ${provider.monthlyBudget.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 16),

            // ── Stats Row ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Daily Average',
                    value: 'Rs. ${provider.dailyAverage.toStringAsFixed(2)}',
                    icon: Icons.today,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Predicted Total',
                    value: 'Rs. ${provider.predictedMonthlyExpense.toStringAsFixed(2)}',
                    icon: Icons.trending_up,
                    color: provider.predictedMonthlyExpense >
                        provider.monthlyBudget
                        ? AppTheme.expenseRed
                        : AppTheme.primaryGreen,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 16),

            // ── Prediction Card ──────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.analytics,
                          color: AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Month-End Prediction',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Prediction gauge
                    _buildPredictionGauge(provider),
                    const SizedBox(height: 16),

                    // Prediction message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: provider.predictedMonthlyExpense >
                            provider.monthlyBudget
                            ? AppTheme.expenseRed.withOpacity(0.1)
                            : AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        provider.predictedMonthlyExpense >
                            provider.monthlyBudget
                            ? '⚠️ At this rate you will exceed your budget by Rs. ${(provider.predictedMonthlyExpense - provider.monthlyBudget).toStringAsFixed(2)} this month!'
                            : '✅ At this rate you will be Rs. ${(provider.monthlyBudget - provider.predictedMonthlyExpense).toStringAsFixed(2)} under budget this month!',
                        style: TextStyle(
                          color: provider.predictedMonthlyExpense >
                              provider.monthlyBudget
                              ? AppTheme.expenseRed
                              : AppTheme.primaryGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 16),

            // ── Category Breakdown ───────────────────────────
            if (provider.categoryBreakdown.isNotEmpty) ...[
              Text(
                'Spending by Category',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCategoryBreakdown(provider),
                ),
              ).animate().fadeIn(delay: 600.ms),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── Prediction Gauge ─────────────────────────────────────────
  Widget _buildPredictionGauge(TransactionProvider provider) {
    final predicted = provider.predictedMonthlyExpense;
    final budget = provider.monthlyBudget;
    final maxValue = predicted > budget ? predicted * 1.2 : budget * 1.2;

    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Budget',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Spacer(),
            const Text(
              'Predicted',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            // Background
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // Budget line
            FractionallySizedBox(
              widthFactor: (budget / maxValue).clamp(0.0, 1.0),
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Predicted line
            FractionallySizedBox(
              widthFactor: (predicted / maxValue).clamp(0.0, 1.0),
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  color: predicted > budget
                      ? AppTheme.expenseRed.withOpacity(0.7)
                      : AppTheme.primaryGreen.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Budget: Rs. ${budget.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: predicted > budget
                        ? AppTheme.expenseRed
                        : AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Predicted: Rs. ${predicted.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Category Breakdown ───────────────────────────────────────
  Widget _buildCategoryBreakdown(TransactionProvider provider) {
    final breakdown = provider.categoryBreakdown;
    final total = breakdown.values.fold(0.0, (a, b) => a + b);
    final colors = [
      AppTheme.primaryGreen,
      Colors.blue,
      Colors.orange,
      Colors.pink,
      Colors.purple,
      Colors.teal,
      Colors.red,
      Colors.indigo,
    ];

    return Column(
      children: breakdown.entries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final percentage = total > 0 ? (item.value / total * 100) : 0.0;
        final color = colors[index % colors.length];
        final budgetShare = provider.monthlyBudget > 0
            ? (item.value / provider.monthlyBudget * 100)
            : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    'Rs. ${item.value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (budgetShare / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
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
                fontSize: 13,
                color: color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}