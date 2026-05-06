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

  bool get _isEditMode => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final t = widget.existingTransaction!;
      _selectedType = t.type;
      _selectedCategory = t.category;
      _amountController.text = t.amount.toString();
      _noteController.text = t.note ?? '';
      _selectedDate = DateTime.tryParse(t.date) ?? DateTime.now();
      _imagePath = t.imagePath;
      _latitude = t.latitude;
      _longitude = t.longitude;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Pick Date ────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context)
                .colorScheme
                .copyWith(primary: AppTheme.primaryGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Pick Image ───────────────────────────────────────────────
  Future<void> _pickImage(bool isCamera) async {
    final path = isCamera
        ? await _deviceService.pickImageFromCamera()
        : await _deviceService.pickImageFromGallery();
    if (path != null && mounted) {
      setState(() => _imagePath = path);
    }
  }

  // ── Get Location ─────────────────────────────────────────────
  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);
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
  }

  // ── Show Image Picker Bottom Sheet ───────────────────────────
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Attach Receipt',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Save Transaction ─────────────────────────────────────────
  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    bool success;

    if (_isEditMode) {
      final updated = widget.existingTransaction!.copyWith(
        type: _selectedType,
        category: _selectedCategory,
        amount: double.parse(_amountController.text),
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        note: _noteController.text.isEmpty ? null : _noteController.text,
        imagePath: _imagePath,
        latitude: _latitude,
        longitude: _longitude,
      );
      success = await transactionProvider.updateTransaction(updated);
    } else {
      success = await transactionProvider.addTransaction(
        userId: authProvider.userId,
        type: _selectedType,
        category: _selectedCategory,
        amount: double.parse(_amountController.text),
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        note: _noteController.text.isEmpty ? null : _noteController.text,
        imagePath: _imagePath,
        latitude: _latitude,
        longitude: _longitude,
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(_isEditMode
                  ? 'Transaction updated!'
                  : 'Transaction added!'),
            ],
          ),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      context.go('/dashboard');
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Transaction' : 'Add Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: isLandscape
            ? _buildLandscapeLayout()
            : _buildPortraitLayout(),
      ),
    );
  }

  // ── Portrait Layout ──────────────────────────────────────────
  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeToggle(),
          const SizedBox(height: 16),
          _buildAmountField(),
          const SizedBox(height: 16),
          _buildCategoryDropdown(),
          const SizedBox(height: 16),
          _buildDatePicker(),
          const SizedBox(height: 16),
          _buildNoteField(),
          const SizedBox(height: 16),
          _buildImagePicker(),
          const SizedBox(height: 16),
          _buildLocationButton(),
          const SizedBox(height: 24),
          _buildSaveButton(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Landscape Layout ─────────────────────────────────────────
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildAmountField(),
                const SizedBox(height: 16),
                _buildNoteField(),
                const SizedBox(height: 16),
                _buildImagePicker(),
                const SizedBox(height: 16),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Type Toggle ──────────────────────────────────────────────
  Widget _buildTypeToggle() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedType = 'expense'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _selectedType == 'expense'
                    ? AppTheme.expenseRed
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_upward,
                    color: _selectedType == 'expense'
                        ? Colors.white
                        : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Expense',
                    style: TextStyle(
                      color: _selectedType == 'expense'
                          ? Colors.white
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedType = 'income'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _selectedType == 'income'
                    ? AppTheme.incomeGreen
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_downward,
                    color: _selectedType == 'income'
                        ? Colors.white
                        : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Income',
                    style: TextStyle(
                      color: _selectedType == 'income'
                          ? Colors.white
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms);
  }

  // ── Amount Field ─────────────────────────────────────────────
  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Amount',
        hintText: '0.00',
        prefixIcon: Icon(Icons.attach_money),
        prefixText: 'Rs. ',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter an amount';
        if (double.tryParse(value) == null) return 'Please enter a valid number';
        if (double.parse(value) <= 0) return 'Amount must be greater than 0';
        return null;
      },
    ).animate().fadeIn(delay: 200.ms);
  }

  // ── Category Dropdown ────────────────────────────────────────
  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: _categories
          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => _selectedCategory = value);
      },
    ).animate().fadeIn(delay: 300.ms);
  }

  // ── Date Picker ──────────────────────────────────────────────
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: Colors.grey),
            const SizedBox(width: 12),
            Text(
              DateFormat('dd MMM yyyy').format(_selectedDate),
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  // ── Note Field ───────────────────────────────────────────────
  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Note (optional)',
        hintText: 'Add a note...',
        prefixIcon: Icon(Icons.note_outlined),
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  // ── Image Picker ─────────────────────────────────────────────
  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _showImagePickerOptions,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_outlined, color: Colors.grey),
                const SizedBox(width: 12),
                Text(
                  _imagePath != null ? 'Receipt attached' : 'Attach Receipt',
                  style: TextStyle(
                    fontSize: 16,
                    color: _imagePath != null
                        ? AppTheme.primaryGreen
                        : Colors.grey,
                  ),
                ),
                const Spacer(),
                Icon(
                  _imagePath != null
                      ? Icons.check_circle
                      : Icons.add_photo_alternate,
                  color: _imagePath != null
                      ? AppTheme.primaryGreen
                      : Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (_imagePath != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_imagePath!),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 600.ms);
  }

  // ── Location Button ──────────────────────────────────────────
  Widget _buildLocationButton() {
    return GestureDetector(
      onTap: _isLoadingLocation ? null : _getLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _latitude != null
                ? AppTheme.primaryGreen.withOpacity(0.5)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: _latitude != null ? AppTheme.primaryGreen : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isLoadingLocation
                    ? 'Getting location...'
                    : _latitude != null
                    ? _deviceService.formatLocation(_latitude, _longitude)
                    : 'Tag Location (GPS)',
                style: TextStyle(
                  fontSize: 16,
                  color: _latitude != null
                      ? AppTheme.primaryGreen
                      : Colors.grey,
                ),
              ),
            ),
            if (_isLoadingLocation)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                _latitude != null ? Icons.check_circle : Icons.my_location,
                color:
                _latitude != null ? AppTheme.primaryGreen : Colors.grey,
              ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 700.ms);
  }

  // ── Save Button ──────────────────────────────────────────────
  Widget _buildSaveButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedType == 'expense'
                ? AppTheme.expenseRed
                : AppTheme.incomeGreen,
          ),
          child: _isLoading
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
              : Text(
              _isEditMode ? 'Update Transaction' : 'Save Transaction'),
        ),
      ),
    ).animate().fadeIn(delay: 800.ms);
  }
}

// ── Image Picker Option Widget ───────────────────────────────────
class _ImagePickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImagePickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}