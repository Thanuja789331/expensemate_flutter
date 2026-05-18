import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'services/device_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const BiometricLockScreen(
      child: ExpenseMateApp(),
    ),
  );
}

class ExpenseMateApp extends StatelessWidget {
  const ExpenseMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = context.watch<ThemeProvider>();
          final router = AppRouter.createRouter(context);
          return MaterialApp.router(
            title: 'ExpenseMate',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}

// ── Biometric Lock Screen ────────────────────────────────────────
class BiometricLockScreen extends StatefulWidget {
  final Widget child;
  const BiometricLockScreen({super.key, required this.child});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with WidgetsBindingObserver {
  final DeviceService _deviceService = DeviceService();
  bool _isLocked = true;
  bool _isAuthenticating = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndAuthenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Lock app when it goes to background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      setState(() => _isLocked = true);
    } else if (state == AppLifecycleState.resumed && _isLocked) {
      _checkAndAuthenticate();
    }
  }

  Future<void> _checkAndAuthenticate() async {
    final available = await _deviceService.isBiometricAvailable();
    setState(() => _biometricAvailable = available);

    // Check if fingerprint is enabled in settings
    final prefs = await SharedPreferences.getInstance();
    final fingerprintEnabled = prefs.getBool('fingerprint_enabled') ?? false;

    if (available && fingerprintEnabled) {
      await _authenticate();
    } else {
      // Fingerprint disabled or not available — unlock directly
      setState(() => _isLocked = false);
    }
  }

  Future<void> _authenticate() async {
    setState(() => _isAuthenticating = true);
    final success = await _deviceService.authenticateWithBiometric();
    if (mounted) {
      setState(() {
        _isAuthenticating = false;
        _isLocked = !success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocked) return widget.child;

    // Lock screen UI
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/login_bg.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black54,
                BlendMode.darken,
              ),
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App icon
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ExpenseMate',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your finances are protected',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Fingerprint button
                  GestureDetector(
                    onTap: _isAuthenticating ? null : _authenticate,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _isAuthenticating
                            ? Colors.white.withOpacity(0.3)
                            : Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: _isAuthenticating
                          ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                          : const Icon(
                        Icons.fingerprint,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isAuthenticating
                        ? 'Authenticating...'
                        : 'Tap to unlock with fingerprint',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Skip biometric option
                  if (!_isAuthenticating && !_biometricAvailable)
                    TextButton(
                      onPressed: () => setState(() => _isLocked = false),
                      child: const Text(
                        'Continue without biometric',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}