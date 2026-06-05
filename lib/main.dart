import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
    // Step 1: Move Providers to the very top. 
    // This ensures AuthState is NEVER destroyed when the screen locks.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: const BiometricLockScreen(
        child: ExpenseMateApp(),
      ),
    ),
  );
}

class ExpenseMateApp extends StatefulWidget {
  const ExpenseMateApp({super.key});

  @override
  State<ExpenseMateApp> createState() => _ExpenseMateAppState();
}

class _ExpenseMateAppState extends State<ExpenseMateApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Initialize the router once to avoid navigation resets on rebuild
    _router = AppRouter.createRouter(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    
    return MaterialApp.router(
      title: 'ExpenseMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      routerConfig: _router,
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
    print('📱 Lifecycle State: $state');
    if (state == AppLifecycleState.resumed && _isLocked) {
      print('▶️ App Resumed - currently locked, checking auth...');
      _checkAndAuthenticate();
    } else if (state == AppLifecycleState.inactive) {
      // Inactive is usually when the app is being swiped away or minimized
      // But it also triggers when system dialogs (Camera/Gallery) open.
      // We check if it's already locked to avoid double-locking.
      print('⚪ App Inactive');
      if (!_isLocked) {
        // Set locked to true so it must be scanned on return
        setState(() => _isLocked = true);
      }
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
    // Step 2: Use a Stack so the app child is ALWAYS in the tree.
    // If it's removed and re-added (like before), GoRouter resets to /login.
    // By keeping it in the tree, we preserve the current route and form data.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // The actual app is always running in the background
          widget.child,

          // If locked, we show a full-screen overlay
          if (_isLocked)
            Positioned.fill(
              child: MaterialApp(
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
                            Image.asset(
                              'assets/images/app_logo.png',
                              width: 100,
                              height: 100,
                            ),
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
              ),
            ),
        ],
      ),
    );
  }
}
