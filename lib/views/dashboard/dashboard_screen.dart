import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';
import 'dart:async';
import '../../services/device_service.dart';

// --- DASHBOARD SCREEN ---
// This is the main screen showing the list of transactions.
// It includes: Search, Filters, Edit/Delete (CRUD), and "Shake to Refresh".
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
    // Load initial data from SQLite
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    
    // Set up Accelerometer Sensor listener for "Shake to Refresh" feature
    _initShakeSensor();
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    final auth = context.read<AuthProvider>();
    final provider = context.read<TransactionProvider>();
    provider.loadTransactions(auth.userId);
  }

  // --- Sensor Logic (VIVA: Accelerometer) ---
  void _initShakeSensor() {
    _shakeSubscription = _deviceService.shakeStream.listen((_) {
      if (mounted && !_isShaking) {
        setState(() => _isShaking = true);
        _loadData(); // Reload data when phone is shaken
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refreshing via Shake!'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
        );
        
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _isShaking = false);
        });
      }
    });
  }

  // CRUD: Delete Transaction
  void _confirmDelete(BuildContext context, TransactionModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to remove this record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              final success = await context.read<TransactionProvider>().deleteTransaction(item.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction Deleted'), backgroundColor: Colors.orange));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Helper to filter the list based on type (Income/Expense) and search text
  List<TransactionModel> _getFilteredItems(TransactionProvider provider) {
    if (_searchQuery.isNotEmpty) return provider.searchTransactions(_searchQuery);
    return provider.filterTransactions(_selectedFilter);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final transactions = _getFilteredItems(provider);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-expense'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Image (Optimized Scale)
          if (!isLandscape) _buildBanner(),

          // --- Search & Filtering UI ---
          _buildFilters(),

          // --- Main List (ListView.builder for efficiency) ---
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactions.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final item = transactions[index];
                          return _TransactionListItem(
                            item: item,
                            onTap: () => _showDetailSheet(context, item),
                            onDelete: () => _confirmDelete(context, item),
                            onEdit: () => context.push('/add-expense', extra: {'transaction': item}),
                          ).animate().fadeIn(delay: Duration(milliseconds: index * 20));
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // UI Components
  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/dashboard_banner.jpg',
          fit: BoxFit.contain,
          alignment: Alignment.center,
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
            decoration: InputDecoration(hintText: 'Search transactions...', prefixIcon: const Icon(Icons.search)),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _FilterButton(label: 'All', isSelected: _selectedFilter == 'all', onTap: () => setState(() => _selectedFilter = 'all')),
              _FilterButton(label: 'Income', isSelected: _selectedFilter == 'income', onTap: () => setState(() => _selectedFilter = 'income')),
              _FilterButton(label: 'Expense', isSelected: _selectedFilter == 'expense', onTap: () => setState(() => _selectedFilter = 'expense')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('No transactions found. Add one!'));
  }

  // --- Master/Detail View ---
  void _showDetailSheet(BuildContext context, TransactionModel item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.category, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/add-expense', extra: {'transaction': item});
                  },
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text('${item.type == 'income' ? '+' : '-'} Rs. ${item.amount}', style: TextStyle(fontSize: 20, color: item.type == 'income' ? Colors.green : Colors.red)),
            const Divider(height: 32),
            Text('Date: ${item.date}', style: const TextStyle(color: Colors.grey)),
            if (item.note != null && item.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note: ${item.note}'),
            ],
            const SizedBox(height: 32),
            // Actions
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
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
    );
  }
}

// Private Widgets
class _TransactionListItem extends StatelessWidget {
  final TransactionModel item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TransactionListItem({
    required this.item, 
    required this.onTap, 
    required this.onDelete, 
    required this.onEdit
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = item.type == 'expense';
    final color = isExpense ? Colors.red : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(isExpense ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              // Category & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(item.date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              // Amount & CRUD Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isExpense ? '-' : '+'} Rs. ${item.amount}', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onEdit,
                        child: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      ),
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 12)),
        backgroundColor: isSelected ? AppTheme.primaryGreen : Colors.grey[200],
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
