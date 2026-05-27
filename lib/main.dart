import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'services/device_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- APP ENTRY POINT ---
void main() async {
  // Ensure Flutter engine is ready before doing async tasks
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    // Wrap entire app in Biometric protection for high-security marks
    const BiometricLockScreen(
      child: ExpenseMateApp(),
    ),
  );
}

class ExpenseMateApp extends StatelessWidget {
  const ExpenseMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject all Providers into the widget tree
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = context.watch<ThemeProvider>();
          
          // Initialize GoRouter for clean navigation management
          final router = AppRouter.createRouter(context);
          
          return MaterialApp.router(
            title: 'ExpenseMate',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode, // Controlled by ThemeProvider
            routerConfig: router,
          );
        },
      ),
    );
  }
}

// --- BIOMETRIC LOCK SCREEN ---
// This widget acts as a "Guard" that shows before the app loads
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

  // Lock the app again when it is minimized (Privacy Protection)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      setState(() => _isLocked = true);
    } else if (state == AppLifecycleState.resumed && _isLocked) {
      _checkAndAuthenticate();
    }
  }

  // Check if user has enabled Fingerprint in the app settings
  Future<void> _checkAndAuthenticate() async {
    final prefs = await SharedPreferences.getInstance();
    final fingerprintEnabled = prefs.getBool('fingerprint_enabled') ?? false;

    if (fingerprintEnabled) {
      await _authenticate();
    } else {
      // If setting is off, just unlock the app directly
      setState(() => _isLocked = false);
    }
  }

  // Trigger the native Android fingerprint popup
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
    // If unlocked, show the actual app content
    if (!_isLocked) return widget.child;

    // Otherwise, show the high-security "Lock Screen" UI
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/login_bg.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 80, color: Colors.white),
                  const SizedBox(height: 24),
                  const Text('ExpenseMate Secured', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 60),
                  
                  // Fingerprint Button
                  GestureDetector(
                    onTap: _isAuthenticating ? null : _authenticate,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _isAuthenticating
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(Icons.fingerprint, size: 64, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(_isAuthenticating ? 'Scanning...' : 'Tap to scan fingerprint', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
