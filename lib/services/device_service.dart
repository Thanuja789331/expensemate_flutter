import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

// --- DEVICE SERVICE ---
// Bridge between Flutter and Phone Hardware.
// Handles Camera, GPS, Battery, Sensors, Biometrics.
class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final ImagePicker _imagePicker = ImagePicker();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // ── CAMERA ───────────────────────────────────────────────────
  // FIX: Request camera permission before opening camera
  // Viva: Permission handling is required for Android 6.0+
  Future<String?> pickImageFromCamera() async {
    try {
      // Request camera permission at runtime
      final status = await Permission.camera.request();

      if (status.isDenied) {
        print('❌ Camera permission denied');
        return null;
      }

      if (status.isPermanentlyDenied) {
        // User selected "Never ask again" — must go to settings
        print('❌ Camera permanently denied — opening settings');
        await openAppSettings();
        return null;
      }

      // Permission granted — open camera
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // Compress to save space
      );
      return photo?.path;
    } catch (e) {
      print('❌ Camera error: $e');
      return null;
    }
  }

  // FIX: Request storage/photos permission before gallery
  Future<String?> pickImageFromGallery() async {
    try {
      // Android 13+ uses READ_MEDIA_IMAGES (Permission.photos)
      // Android 12 and below uses READ_EXTERNAL_STORAGE
      PermissionStatus status = await Permission.photos.request();

      if (status.isDenied) {
        // Fallback for older Android versions
        status = await Permission.storage.request();
      }

      if (status.isDenied) {
        print('❌ Storage permission denied');
        return null;
      }

      if (status.isPermanentlyDenied) {
        print('❌ Storage permanently denied — opening settings');
        await openAppSettings();
        return null;
      }

      // Permission granted — open gallery
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      return image?.path;
    } catch (e) {
      print('❌ Gallery error: $e');
      return null;
    }
  }

  // ── GPS LOCATION ─────────────────────────────────────────────
  // Viva: Geolocator handles its own permission flow
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location service is enabled on device
      bool serviceEnabled =
      await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services disabled on device');
        return null;
      }

      // Check current permission status
      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // Request permission from user
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied by user');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Must open app settings
        print('❌ Location permanently denied — opening settings');
        await Geolocator.openAppSettings();
        return null;
      }

      // Permission granted — get GPS coordinates
      print('✅ Location permission granted — fetching position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      print(
        '✅ Got location: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      print('❌ Location error: $e');
      return null;
    }
  }

  // Format GPS coordinates for display
  String formatLocation(double? lat, double? lng) {
    if (lat == null || lng == null) return 'No location';
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  // ── BATTERY ──────────────────────────────────────────────────
  Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      return 0;
    }
  }

  Future<BatteryState> getBatteryState() async {
    try {
      return await _battery.batteryState;
    } catch (e) {
      return BatteryState.unknown;
    }
  }

  // ── CONNECTIVITY ─────────────────────────────────────────────
  // Check if phone has active WiFi or Mobile Data
  Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // Stream for real-time network changes
  Stream<ConnectivityResult> get connectivityStream =>
      _connectivity.onConnectivityChanged.map(
            (results) => results.isNotEmpty
            ? results.first
            : ConnectivityResult.none,
      );

  // ── SENSORS ──────────────────────────────────────────────────
  // Raw accelerometer stream for live display
  Stream<AccelerometerEvent> get accelerometerStream =>
      accelerometerEventStream();

  // Raw gyroscope stream
  Stream<GyroscopeEvent> get gyroscopeStream =>
      gyroscopeEventStream();

  // Convert gyroscope values to human-readable tilt
  String getGyroscopeTilt(double x, double y, double z) {
    if (x.abs() > y.abs() && x.abs() > z.abs()) {
      return x > 0 ? 'Tilting Forward' : 'Tilting Backward';
    } else if (y.abs() > x.abs() && y.abs() > z.abs()) {
      return y > 0 ? 'Tilting Right' : 'Tilting Left';
    } else {
      return z > 0
          ? 'Rotating Clockwise'
          : 'Rotating Counter-clockwise';
    }
  }

  // Shake detection — threshold 15.0 m/s²
  // Viva: Calculate delta between readings on all 3 axes
  Stream<bool> get shakeStream {
    double lastX = 0, lastY = 0, lastZ = 0;
    const double shakeThreshold = 15.0;

    return accelerometerEventStream().map((event) {
      // Calculate change in motion on each axis
      double deltaX = (event.x - lastX).abs();
      double deltaY = (event.y - lastY).abs();
      double deltaZ = (event.z - lastZ).abs();

      lastX = event.x;
      lastY = event.y;
      lastZ = event.z;

      // If total change exceeds threshold — shake detected
      return (deltaX + deltaY + deltaZ) > shakeThreshold;
    }).where((isShaking) => isShaking);
  }

  // ── BIOMETRICS ───────────────────────────────────────────────
  // Check if fingerprint/face hardware exists
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  // List supported biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Show biometric authentication dialog
  Future<bool> authenticateWithBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint to unlock ExpenseMate',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN fallback
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      print('❌ Biometric error: $e');
      return false;
    }
  }
}