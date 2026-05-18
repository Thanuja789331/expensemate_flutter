import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/device_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int? _selectedIndex;

  // ── Profile menu items ───────────────────────────────────────
  final List<Map<String, dynamic>> _menuItems = [
    {
      'title': 'Account',
      'subtitle': 'Name, email, profile info',
      'icon': Icons.person_outlined,
      'color': Colors.blue,
    },
    {
      'title': 'Appearance',
      'subtitle': 'Theme, light/dark mode',
      'icon': Icons.palette_outlined,
      'color': Colors.purple,
    },
    {
      'title': 'Currency',
      'subtitle': 'LKR, USD, EUR, GBP',
      'icon': Icons.currency_exchange,
      'color': Colors.green,
    },
    {
      'title': 'Notifications',
      'subtitle': 'Alerts and reminders',
      'icon': Icons.notifications_outlined,
      'color': Colors.orange,
    },
    {
      'title': 'Security',
      'subtitle': 'Password and privacy',
      'icon': Icons.security_outlined,
      'color': Colors.red,
    },
    {
      'title': 'About',
      'subtitle': 'App version, help',
      'icon': Icons.info_outlined,
      'color': Colors.teal,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showSignOutDialog(context),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: isLandscape
          ? _buildLandscapeLayout(context)
          : _buildPortraitLayout(context),
    );
  }

  // ── Portrait Layout ──────────────────────────────────────────
  Widget _buildPortraitLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProfileHeader(context),
          const SizedBox(height: 8),
          _buildMenuList(context, isPortrait: true),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Landscape Layout (Master/Detail) ─────────────────────────
  Widget _buildLandscapeLayout(BuildContext context) {
    return Column(
      children: [
        // Compact header — just one line
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          color: Theme.of(context).colorScheme.primary,
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withOpacity(0.3),
                child: Text(
                  context.read<AuthProvider>().userName.isNotEmpty
                      ? context
                      .read<AuthProvider>()
                      .userName[0]
                      .toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.read<AuthProvider>().userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                context.read<AuthProvider>().userEmail,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Master/Detail row
        Expanded(
          child: Row(
            children: [
              // Master list
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.32,
                child: _buildMenuList(context, isPortrait: false),
              ),
              Container(
                width: 1,
                color: Colors.grey.withOpacity(0.2),
              ),
              // Detail panel
              Expanded(
                child: _selectedIndex == null
                    ? _buildDetailPlaceholder()
                    : _buildDetailContent(context, _selectedIndex!),
              ),
            ],
          ),
        ),
      ],
    );
  }
  // ── Profile Header (Portrait) ────────────────────────────────
  Widget _buildProfileHeader(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: Text(
              authProvider.userName.isNotEmpty
                  ? authProvider.userName[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            authProvider.userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            authProvider.userEmail,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile Header Compact (Landscape) ──────────────────────
  Widget _buildProfileHeaderCompact(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: theme.colorScheme.primary,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: Text(
              authProvider.userName.isNotEmpty
                  ? authProvider.userName[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  authProvider.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  authProvider.userEmail,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Menu List ────────────────────────────────────────────────
  Widget _buildMenuList(BuildContext context, {required bool isPortrait}) {
    return ListView.separated(
      shrinkWrap: isPortrait,
      physics: isPortrait
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      itemCount: _menuItems.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        final isSelected = _selectedIndex == index;

        return ListTile(
          dense: !isPortrait,
          selected: isSelected && !isPortrait,
          selectedTileColor: AppTheme.primaryGreen.withOpacity(0.1),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isPortrait ? 16 : 12,
            vertical: isPortrait ? 4 : 0,
          ),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (item['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: item['color'] as Color,
              size: isPortrait ? 20 : 18,
            ),
          ),
          title: Text(
            item['title'] as String,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isPortrait ? 14 : 13,
            ),
          ),
          subtitle: isPortrait
              ? Text(
            item['subtitle'] as String,
            style: const TextStyle(fontSize: 12),
          )
              : null,
          trailing: Icon(
            Icons.chevron_right,
            color: Colors.grey,
            size: isPortrait ? 24 : 18,
          ),
          onTap: () {
            if (isPortrait) {
              _showDetailDialog(context, index);
            } else {
              setState(() => _selectedIndex = index);
            }
          },
        );
      },
    );
  }

  // ── Detail Placeholder ───────────────────────────────────────
  Widget _buildDetailPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 48,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            'Select a setting',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose from the left panel',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }
  // ── Detail Content ───────────────────────────────────────────
  Widget _buildDetailContent(BuildContext context, int index) {
    final item = _menuItems[index];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: item['color'] as Color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                item['title'] as String,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Content based on index
          _buildDetailBody(context, index),
        ],
      ),
    );
  }

  // ── Detail Body Content ──────────────────────────────────────
  Widget _buildDetailBody(BuildContext context, int index) {
    switch (index) {
      case 0:
        return _buildAccountDetail(context);
      case 1:
        return _buildAppearanceDetail(context);
      case 2:
        return _buildCurrencyDetail();
      case 3:
        return _buildNotificationsDetail();
      case 4:
        return _buildSecurityDetail();
      case 5:
        return _buildAboutDetail();
      default:
        return const SizedBox();
    }
  }

  // ── Account Detail ───────────────────────────────────────────
  Widget _buildAccountDetail(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailItem(label: 'Full Name', value: authProvider.userName),
        const SizedBox(height: 16),
        _DetailItem(label: 'Email', value: authProvider.userEmail),
        const SizedBox(height: 16),
        _DetailItem(label: 'Account Status', value: 'Active'),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _showSignOutDialog(context),
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  // ── Appearance Detail ────────────────────────────────────────
  Widget _buildAppearanceDetail(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Theme Mode',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _ThemeOption(
          label: 'System Default',
          icon: Icons.brightness_auto,
          isSelected: themeProvider.themeMode == ThemeMode.system,
          onTap: () => themeProvider.setThemeMode(ThemeMode.system),
        ),
        const SizedBox(height: 8),
        _ThemeOption(
          label: 'Light Mode',
          icon: Icons.light_mode,
          isSelected: themeProvider.themeMode == ThemeMode.light,
          onTap: () => themeProvider.setThemeMode(ThemeMode.light),
        ),
        const SizedBox(height: 8),
        _ThemeOption(
          label: 'Dark Mode',
          icon: Icons.dark_mode,
          isSelected: themeProvider.themeMode == ThemeMode.dark,
          onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
        ),
      ],
    );
  }

  // ── Currency Detail ──────────────────────────────────────────
  Widget _buildCurrencyDetail() {
    final currencies = [
      {'code': 'LKR', 'symbol': 'Rs', 'name': 'Sri Lankan Rupee'},
      {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
      {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
      {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Currency',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ...currencies.map((currency) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                currency['symbol']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ),
          title: Text(currency['name']!),
          subtitle: Text(currency['code']!),
          trailing: const Icon(
            Icons.check_circle,
            color: AppTheme.primaryGreen,
          ),
        )),
      ],
    );
  }

  // ── Notifications Detail ─────────────────────────────────────
  Widget _buildNotificationsDetail() {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Daily Reminders'),
          subtitle: const Text('Remind me to log expenses'),
          value: true,
          onChanged: (_) {},
          activeColor: AppTheme.primaryGreen,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Budget Alerts'),
          subtitle: const Text('Alert when near budget limit'),
          value: true,
          onChanged: (_) {},
          activeColor: AppTheme.primaryGreen,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Weekly Summary'),
          subtitle: const Text('Send weekly spending report'),
          value: false,
          onChanged: (_) {},
          activeColor: AppTheme.primaryGreen,
        ),
      ],
    );
  }

  // ── Security Detail ──────────────────────────────────────────
  Widget _buildSecurityDetail() {
    final themeProvider = context.watch<ThemeProvider>();
    final deviceService = DeviceService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailItem(label: 'Authentication', value: 'Local Auth'),
        const SizedBox(height: 16),
        _DetailItem(label: 'Data Encryption', value: 'Enabled'),
        const SizedBox(height: 16),
        _DetailItem(label: 'Local Storage', value: 'SQLite'),
        const SizedBox(height: 24),

        // Fingerprint toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryGreen.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint,
                  color: AppTheme.primaryGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fingerprint Lock',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      themeProvider.fingerprintEnabled
                          ? 'App is locked with fingerprint'
                          : 'Tap to enable fingerprint lock',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: themeProvider.fingerprintEnabled,
                activeColor: AppTheme.primaryGreen,
                onChanged: (value) async {
                  if (value) {
                    // Check if biometric is available first
                    final available =
                    await deviceService.isBiometricAvailable();
                    if (!available) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Biometric not available on this device',
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    // Test authentication before enabling
                    final success =
                    await deviceService.authenticateWithBiometric();
                    if (success) {
                      await themeProvider.setFingerprintEnabled(true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Fingerprint lock enabled!'),
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
                  } else {
                    await themeProvider.setFingerprintEnabled(false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.lock_open,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Fingerprint lock disabled'),
                            ],
                          ),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.lock_reset),
          label: const Text('Change Password'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  // ── About Detail ─────────────────────────────────────────────
  Widget _buildAboutDetail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailItem(label: 'App Name', value: 'ExpenseMate'),
        const SizedBox(height: 16),
        _DetailItem(label: 'Version', value: '1.0.0'),
        const SizedBox(height: 16),
        _DetailItem(label: 'Framework', value: 'Flutter 3.x'),
        const SizedBox(height: 16),
        _DetailItem(label: 'Module', value: 'COMP50011'),
        const SizedBox(height: 16),
        _DetailItem(label: 'Campus', value: 'APIIT Kandy'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryGreen.withOpacity(0.2),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryGreen),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ExpenseMate — Personal Finance Tracker built with Flutter for COMP50011 Mobile App Development.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Show Detail Dialog (Portrait) ────────────────────────────
  void _showDetailDialog(BuildContext context, int index) {
    final item = _menuItems[index];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  child: _buildDetailBody(context, index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sign Out Dialog ──────────────────────────────────────────
  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = context.read<AuthProvider>();
              final transactionProvider =
              context.read<TransactionProvider>();
              transactionProvider.clearData();
              await authProvider.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ── Detail Item Widget ───────────────────────────────────────────
class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Theme Option Widget ──────────────────────────────────────────
class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryGreen
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryGreen : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: isSelected
                    ? AppTheme.primaryGreen
                    : null,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppTheme.primaryGreen,
              ),
          ],
        ),
      ),
    );
  }
}