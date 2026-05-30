import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/device_service.dart';
import '../../theme/app_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  final TransactionModel? existingTransaction;

  const AddExpenseScreen({super.key, this.existingTransaction});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final DeviceService _deviceService = DeviceService();

  String _selectedType = 'expense';
  String _selectedCategory = 'Food & Drinks';
  String _selectedCurrency = 'LKR';
  DateTime _selectedDate = DateTime.now();
  String? _imagePath;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  bool _isPressed = false;
  bool _isLoadingLocation = false;

  final List<String> _categories = [
    'Food & Drinks',
    'Transport',
    'Shopping',
    'Bills',
    'Health',
    'Entertainment',
    'Education',
    'Salary',
    'Freelance',
    'Other',
  ];

  final List<Map<String, String>> _currencies = [
    {'code': 'LKR', 'symbol': 'Rs', 'flag': '🇱🇰'},
    {'code': 'USD', 'symbol': '\$', 'flag': '🇺🇸'},
    {'code': 'EUR', 'symbol': '€', 'flag': '🇪🇺'},
    {'code': 'GBP', 'symbol': '£', 'flag': '🇬🇧'},
    {'code': 'INR', 'symbol': '₹', 'flag': '🇮🇳'},
    {'code': 'AUD', 'symbol': 'A\$', 'flag': '🇦🇺'},
    {'code': 'CAD', 'symbol': 'C\$', 'flag': '🇨🇦'},
    {'code': 'JPY', 'symbol': '¥', 'flag': '🇯🇵'},
    {'code': 'SGD', 'symbol': 'S\$', 'flag': '🇸🇬'},
    {'code': 'AED', 'symbol': 'د.إ', 'flag': '🇦🇪'},
  ];

  bool get _isEditMode => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final t = widget.existingTransaction!;
      _selectedType = t.type;
      
      // Ensure category exists in list
      if (_categories.contains(t.category)) {
        _selectedCategory = t.category;
      } else {
        _selectedCategory = 'Other';
      }

      _amountController.text = t.amount.toString();
      _noteController.text = t.note ?? '';
      try {
        _selectedDate = DateTime.parse(t.date);
      } catch (e) {
        _selectedDate = DateTime.now();
      }
      _imagePath = t.imagePath;
      _latitude = t.latitude;
      _longitude = t.longitude;
      _selectedCurrency = t.currency;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickImage(bool isCamera) async {
    print('📸 ATTACH RECEIPT TAPPED');
    print('CURRENT ROUTE: ${GoRouterState.of(context).uri}');
    print('IMAGE PICKER OPENING');
    
    try {
      final path = isCamera
          ? await _deviceService.pickImageFromCamera()
          : await _deviceService.pickImageFromGallery();
      
      if (!mounted) {
        print('⚠️ Context unmounted after image pick');
        return;
      }
      
      if (path != null) {
        print('✅ Image selected: $path');
        setState(() => _imagePath = path);
      }
    } catch (e) {
      print('❌ Image Picker Error: $e');
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await _deviceService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          if (position != null) {
            _latitude = position.latitude;
            _longitude = position.longitude;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Attach Receipt',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ImagePickerOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(true);
                    },
                  ),
                  _ImagePickerOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(false);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    print('💾 Saving transaction...');
    // Capture state before async work
    final authProvider = context.read<AuthProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    
    // Safety check for user ID
    if (authProvider.userId.isEmpty) {
      print('❌ Error: User ID is missing - cannot save transaction');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not authenticated')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      bool success;

      if (_isEditMode) {
        final updated = widget.existingTransaction!.copyWith(
          type: _selectedType,
          category: _selectedCategory,
          amount: amount,
          date: dateStr,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          imagePath: _imagePath,
          latitude: _latitude,
          longitude: _longitude,
          currency: _selectedCurrency,
        );
        success = await transactionProvider.updateTransaction(updated);
      } else {
        success = await transactionProvider.addTransaction(
          userId: authProvider.userId,
          type: _selectedType,
          category: _selectedCategory,
          amount: amount,
          date: dateStr,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          imagePath: _imagePath,
          latitude: _latitude,
          longitude: _longitude,
          currency: _selectedCurrency,
        );
      }

      if (!mounted) {
        print('⚠️ Context unmounted after save - cannot navigate');
        return;
      }

      setState(() => _isLoading = false);

      if (success) {
        print('✅ Transaction success - navigating to Dashboard');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(_isEditMode
                    ? 'Transaction updated!'
                    : 'Transaction saved!'),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Use go() to replace current stack
        context.go('/dashboard');
      } else {
        print('❌ Transaction failed: ${transactionProvider.errorMessage}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              transactionProvider.errorMessage ??
                  'Failed to save transaction',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Unexpected Save Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Transaction' : 'Add Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeToggle(),
          const SizedBox(height: 20),
          _buildAmountField(),
          const SizedBox(height: 20),
          _buildCategoryDropdown(),
          const SizedBox(height: 20),
          _buildDatePicker(),
          const SizedBox(height: 20),
          _buildNoteField(),
          const SizedBox(height: 20),
          _buildImagePicker(),
          const SizedBox(height: 20),
          _buildLocationButton(),
          const SizedBox(height: 32),
          _buildSaveButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTypeToggle(),
                const SizedBox(height: 16),
                _buildCategoryDropdown(),
                const SizedBox(height: 16),
                _buildDatePicker(),
                const SizedBox(height: 16),
                _buildLocationButton(),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildAmountField(),
                const SizedBox(height: 16),
                _buildNoteField(),
                const SizedBox(height: 16),
                _buildImagePicker(),
                const SizedBox(height: 24),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeToggle() {
    return Row(
      children: [
        _TypeButton(
          label: 'Expense',
          icon: Icons.arrow_upward,
          color: AppTheme.expenseRed,
          isSelected: _selectedType == 'expense',
          onTap: () => setState(() => _selectedType = 'expense'),
        ),
        const SizedBox(width: 12),
        _TypeButton(
          label: 'Income',
          icon: Icons.arrow_downward,
          color: AppTheme.incomeGreen,
          isSelected: _selectedType == 'income',
          onTap: () => setState(() => _selectedType = 'income'),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildAmountField() {
    final selectedCurrency = _currencies.firstWhere(
      (c) => c['code'] == _selectedCurrency,
      orElse: () => _currencies.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCurrency,
              isExpanded: true,
              items: _currencies.map((c) => DropdownMenuItem(
                value: c['code'],
                child: Text('${c['flag']} ${c['code']} (${c['symbol']})'),
              )).toList(),
              onChanged: (v) => setState(() => _selectedCurrency = v!),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                selectedCurrency['symbol']!,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _selectedType == 'expense' ? AppTheme.expenseRed : AppTheme.incomeGreen,
                ),
              ),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please enter an amount';
            if (double.tryParse(v) == null) return 'Enter a valid number';
            if (double.parse(v) <= 0) return 'Amount must be positive';
            return null;
          },
        ),
      ],
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (v) => setState(() => _selectedCategory = v!),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Text(DateFormat('dd MMMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 16)),
            const Spacer(),
            const Icon(Icons.edit_outlined, color: AppTheme.primaryGreen, size: 18),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Note (optional)',
        prefixIcon: Icon(Icons.note_outlined),
        hintText: 'What was this for?',
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        InkWell(
          onTap: _showImagePickerOptions,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _imagePath != null ? AppTheme.primaryGreen : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: _imagePath != null ? AppTheme.primaryGreen : Colors.grey),
                const SizedBox(width: 12),
                Text(_imagePath != null ? 'Receipt Attached' : 'Attach Receipt Image'),
                const Spacer(),
                if (_imagePath != null) 
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.red),
                    onPressed: () => setState(() => _imagePath = null),
                  )
                else 
                  const Icon(Icons.add_a_photo_outlined, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (_imagePath != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_imagePath!), height: 150, width: double.infinity, fit: BoxFit.cover),
          ),
        ]
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildLocationButton() {
    return InkWell(
      onTap: _isLoadingLocation ? null : _getLocation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _latitude != null ? AppTheme.primaryGreen : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, color: _latitude != null ? AppTheme.primaryGreen : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isLoadingLocation ? 'Getting location...' : 
                _latitude != null ? 'Location tagged (${_latitude!.toStringAsFixed(3)}, ${_longitude!.toStringAsFixed(3)})' : 'Tag GPS Location'
              ),
            ),
            if (_isLoadingLocation)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else if (_latitude != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.red),
                onPressed: () => setState(() { _latitude = null; _longitude = null; }),
              )
          ],
        ),
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveTransaction,
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedType == 'expense' ? AppTheme.expenseRed : AppTheme.incomeGreen,
        minimumSize: const Size(double.infinity, 56),
      ),
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(_isEditMode ? 'Update Transaction' : 'Save Transaction', style: const TextStyle(fontSize: 18)),
    ).animate().fadeIn(delay: 700.ms);
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImagePickerOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}