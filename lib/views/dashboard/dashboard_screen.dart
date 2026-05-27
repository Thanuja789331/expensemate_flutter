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
// It includes: Search, Filters, and "Shake to Refresh".
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
        
        // Give tactile feedback via a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refreshing via Shake!'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
        );
        
        // Reset shaking state after a second
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _isShaking = false);
        });
      }
    });
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
      margin: const EdgeInsets.all(16),
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(image: AssetImage('assets/images/dashboard_banner.jpg'), fit: BoxFit.cover),
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
            Text(item.category, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${item.type == 'income' ? '+' : '-'} Rs. ${item.amount}', style: TextStyle(fontSize: 20, color: item.type == 'income' ? Colors.green : Colors.red)),
            const Divider(height: 32),
            Text('Date: ${item.date}'),
            if (item.note != null) Text('Note: ${item.note}'),
            const SizedBox(height: 24),
            // Button to close
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
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
  const _TransactionListItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Icon(item.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward, color: item.type == 'income' ? Colors.green : Colors.red),
        title: Text(item.category, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(item.date),
        trailing: Text('Rs. ${item.amount}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black)),
        backgroundColor: isSelected ? AppTheme.primaryGreen : Colors.grey[200],
      ),
    );
  }
}
