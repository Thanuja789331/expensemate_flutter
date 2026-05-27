import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:battery_plus/battery_plus.dart';
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
  final DeviceService _deviceService = DeviceService();

  // ── Profile menu items ───────────────────────────────────────
  final List<Map<String, dynamic>> _menuItems = [
    {
      'title': 'Account',
      'subtitle': 'Name, email, profile info',
      'icon': Icons.person_outlined,
      'color': Colors.blue,
    },
    {
      'title': 'Device Info',
      'subtitle': 'Battery, hardware, network',
      'icon': Icons.phone_android_outlined,
      'color': Colors.orange,
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
        _buildProfileHeaderCompact(context),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.35,
                child: _buildMenuList(context, isPortrait: false),
              ),
              const VerticalDivider(width: 1),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withOpacity(0.8)],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: Text(
              authProvider.userName.isNotEmpty ? authProvider.userName[0].toUpperCase() : 'U',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(authProvider.userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(authProvider.userEmail, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  // ── Profile Header Compact (Landscape) ──────────────────────
  Widget _buildProfileHeaderCompact(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.primaryGreen,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: Text(
              authProvider.userName.isNotEmpty ? authProvider.userName[0].toUpperCase() : 'U',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(authProvider.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(authProvider.userEmail, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
      physics: isPortrait ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
      itemCount: _menuItems.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        final isSelected = _selectedIndex == index;

        return ListTile(
          selected: !isPortrait && isSelected,
          selectedTileColor: AppTheme.primaryGreen.withOpacity(0.1),
          leading: Icon(item['icon'], color: item['color'], size: 22),
          title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: isPortrait ? Text(item['subtitle'], style: const TextStyle(fontSize: 12)) : null,
          trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
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

  Widget _buildDetailPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Select a setting to view details', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context, int index) {
    final item = _menuItems[index];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item['title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(item['subtitle'], style: const TextStyle(color: Colors.grey)),
          const Divider(height: 32),
          _buildDetailBody(context, index),
        ],
      ),
    );
  }

  Widget _buildDetailBody(BuildContext context, int index) {
    switch (index) {
      case 0: return _buildAccountDetail();
      case 1: return _buildDeviceInfoDetail();
      case 2: return _buildAppearanceDetail();
      case 3: return _buildCurrencyDetail();
      case 4: return _buildSecurityDetail();
      case 5: return _buildAboutDetail();
      default: return const SizedBox();
    }
  }

  Widget _buildAccountDetail() {
    final auth = context.watch<AuthProvider>();
    return Column(
      children: [
        _DetailRow(label: 'Full Name', value: auth.userName),
        _DetailRow(label: 'Email Address', value: auth.userEmail),
        _DetailRow(label: 'User ID', value: auth.userId),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => _showSignOutDialog(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Sign Out Account'),
        ),
      ],
    );
  }

  Widget _buildDeviceInfoDetail() {
    return FutureBuilder(
      future: Future.wait([
        _deviceService.getBatteryLevel(),
        _deviceService.getBatteryState(),
        _deviceService.isOnline(),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final level = snapshot.data![0] as int;
        final state = snapshot.data![1] as BatteryState;
        final online = snapshot.data![2] as bool;

        return Column(
          children: [
            _DetailRow(label: 'Battery Level', value: '$level%'),
            _DetailRow(label: 'Battery Status', value: state.toString().split('.').last.toUpperCase()),
            _DetailRow(label: 'Network Status', value: online ? 'ONLINE' : 'OFFLINE'),
            _DetailRow(label: 'Device OS', value: 'Android'),
            const SizedBox(height: 16),
            const Text('Real-time device info fetched via sensors.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        );
      },
    );
  }

  Widget _buildAppearanceDetail() {
    final themeProvider = context.watch<ThemeProvider>();
    return Column(
      children: [
        _ThemeOption(label: 'System', icon: Icons.brightness_auto, isSelected: themeProvider.themeMode == ThemeMode.system, onTap: () => themeProvider.setThemeMode(ThemeMode.system)),
        _ThemeOption(label: 'Light Mode', icon: Icons.light_mode, isSelected: themeProvider.themeMode == ThemeMode.light, onTap: () => themeProvider.setThemeMode(ThemeMode.light)),
        _ThemeOption(label: 'Dark Mode', icon: Icons.dark_mode, isSelected: themeProvider.themeMode == ThemeMode.dark, onTap: () => themeProvider.setThemeMode(ThemeMode.dark)),
      ],
    );
  }

  Widget _buildCurrencyDetail() {
    return const Column(
      children: [
        ListTile(title: Text('Sri Lankan Rupee (LKR)'), trailing: Icon(Icons.check_circle, color: AppTheme.primaryGreen)),
        ListTile(title: Text('US Dollar (USD)')),
        ListTile(title: Text('Euro (EUR)')),
      ],
    );
  }

  Widget _buildSecurityDetail() {
    final themeProvider = context.watch<ThemeProvider>();
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Fingerprint Lock'),
          subtitle: const Text('Secure app with biometrics'),
          value: themeProvider.fingerprintEnabled,
          onChanged: (v) async {
            if (v) {
              final success = await _deviceService.authenticateWithBiometric();
              if (success) await themeProvider.setFingerprintEnabled(true);
            } else {
              await themeProvider.setFingerprintEnabled(false);
            }
          },
        ),
      ],
    );
  }

  Widget _buildAboutDetail() {
    return const Column(
      children: [
        _DetailRow(label: 'App Name', value: 'ExpenseMate'),
        _DetailRow(label: 'Version', value: '1.0.0 (Production)'),
        _DetailRow(label: 'Developer', value: 'APIIT Student'),
        _DetailRow(label: 'Framework', value: 'Flutter + Material 3'),
      ],
    );
  }

  void _showDetailDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailContent(context, index),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final trans = context.read<TransactionProvider>();
              trans.clearData();
              await auth.signOut();
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryGreen : Colors.grey),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen) : null,
      onTap: onTap,
    );
  }
}