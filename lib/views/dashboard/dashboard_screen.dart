import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/device_service.dart';
import '../../theme/app_theme.dart';

// --- DASHBOARD SCREEN ---
// Shows all transactions with search, filter, CRUD, and shake to refresh.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  final DeviceService _deviceService = DeviceService();
  StreamSubscription? _shakeSubscription;

  String _selectedFilter = 'all';
  String _searchQuery = '';
  bool _isShaking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    _initShakeSensor();
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final provider = context.read<TransactionProvider>();
    provider.loadTransactions(auth.userId);
  }

  // Accelerometer shake to refresh
  void _initShakeSensor() {
    _shakeSubscription = _deviceService.shakeStream.listen((_) {
      if (mounted && !_isShaking) {
        setState(() => _isShaking = true);
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📳 Refreshing via Shake!'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _isShaking = false);
        });
      }
    });
  }

  void _confirmDelete(BuildContext context, TransactionModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await context
                  .read<TransactionProvider>()
                  .deleteTransaction(item.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction deleted'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  List<TransactionModel> _getFilteredItems(
      TransactionProvider provider) {
    if (_searchQuery.isNotEmpty) {
      return provider.searchTransactions(_searchQuery);
    }
    return provider.filterTransactions(_selectedFilter);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final transactions = _getFilteredItems(provider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-expense'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner — portrait only
          if (!isLandscape) _buildBanner(),

          // Search and filters
          _buildFilters(),

          // Transaction count
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${transactions.length} transaction${transactions.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          // Transaction list
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactions.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: () async => _loadData(),
              color: AppTheme.primaryGreen,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                    16, 8, 16, 80),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final item = transactions[index];
                  return _TransactionListItem(
                    item: item,
                    onTap: () =>
                        _showDetailSheet(context, item),
                    onDelete: () =>
                        _confirmDelete(context, item),
                    onEdit: () => context.push(
                      '/add-expense',
                      extra: {'transaction': item},
                    ),
                  ).animate().fadeIn(
                    delay: Duration(
                        milliseconds: index * 30),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      height: 130,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.primaryGreen.withOpacity(0.1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.asset(
              'assets/images/dashboard_banner.jpg',
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: AppTheme.primaryGreen.withOpacity(0.1),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            const Positioned(
              left: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expense Overview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Track your spending smartly',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search transactions...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
                  : null,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _FilterButton(
                label: 'All',
                isSelected: _selectedFilter == 'all',
                onTap: () => setState(() {
                  _selectedFilter = 'all';
                  _searchQuery = '';
                  _searchController.clear();
                }),
              ),
              const SizedBox(width: 8),
              _FilterButton(
                label: 'Income',
                isSelected: _selectedFilter == 'income',
                color: AppTheme.incomeGreen,
                onTap: () => setState(() {
                  _selectedFilter = 'income';
                  _searchQuery = '';
                  _searchController.clear();
                }),
              ),
              const SizedBox(width: 8),
              _FilterButton(
                label: 'Expense',
                isSelected: _selectedFilter == 'expense',
                color: AppTheme.expenseRed,
                onTap: () => setState(() {
                  _selectedFilter = 'expense';
                  _searchQuery = '';
                  _searchController.clear();
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/empty_wallet.png',
            height: 120,
            errorBuilder: (context, error, stack) => Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results found'
                : 'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap + to add your first transaction',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-expense'),
              icon: const Icon(Icons.add),
              label: const Text('Add Transaction'),
            ),
          ],
        ],
      ),
    );
  }

  // Master/Detail bottom sheet with GPS and image
  void _showDetailSheet(
      BuildContext context, TransactionModel item) {
    final isExpense = item.type == 'expense';
    final color = isExpense ? AppTheme.expenseRed : AppTheme.incomeGreen;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Category + Edit button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isExpense
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.category,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              isExpense ? 'Expense' : 'Income',
                              style: TextStyle(color: color),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(
                          '/add-expense',
                          extra: {'transaction': item},
                        );
                      },
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount
                Text(
                  '${isExpense ? '-' : '+'} ${item.currency} ${item.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Divider(height: 32),

                // Date
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value: item.date,
                ),

                // Note
                if (item.note != null &&
                    item.note!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.note,
                    label: 'Note',
                    value: item.note!,
                  ),
                ],

                // Currency
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.currency_exchange,
                  label: 'Currency',
                  value: item.currency,
                ),

                // GPS Location
                if (item.latitude != null &&
                    item.longitude != null) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.location_on,
                    label: 'Location',
                    value:
                    '${item.latitude!.toStringAsFixed(4)}, ${item.longitude!.toStringAsFixed(4)}',
                    valueColor: Colors.green,
                  ),
                ],

                // Receipt Image
                if (item.imagePath != null &&
                    item.imagePath!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Receipt',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(item.imagePath!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          Container(
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image,
                                size: 40),
                          ),
                    ),
                  ),
                ],

                // Sync status
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      item.isSynced
                          ? Icons.cloud_done
                          : Icons.cloud_upload,
                      size: 16,
                      color: item.isSynced
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.isSynced
                          ? 'Synced to cloud'
                          : 'Pending sync — will sync when online',
                      style: TextStyle(
                        fontSize: 12,
                        color: item.isSynced
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDelete(context, item);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Detail row widget
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

// Transaction list item widget
class _TransactionListItem extends StatelessWidget {
  final TransactionModel item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TransactionListItem({
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = item.type == 'expense';
    final color = isExpense ? AppTheme.expenseRed : AppTheme.incomeGreen;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isExpense
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      item.note?.isNotEmpty == true
                          ? item.note!
                          : item.date,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Show GPS indicator
                    if (item.latitude != null)
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 11, color: Colors.green[400]),
                          Text(
                            ' Location tagged',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[400],
                            ),
                          ),
                        ],
                      ),
                    // Show image indicator
                    if (item.imagePath != null)
                      Row(
                        children: [
                          Icon(Icons.receipt,
                              size: 11, color: Colors.blue[400]),
                          Text(
                            ' Receipt attached',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[400],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isExpense ? '-' : '+'} ${item.currency} ${item.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sync indicator
                      Icon(
                        item.isSynced
                            ? Icons.cloud_done
                            : Icons.cloud_upload,
                        size: 12,
                        color: item.isSynced
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onEdit,
                        child: const Icon(Icons.edit_outlined,
                            size: 18, color: Colors.blue),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Filter button widget
class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryGreen;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : chipColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}