import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';

class DeviceService {
  // Singleton pattern
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  // ── Instances ────────────────────────────────────────────────
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final ImagePicker _imagePicker = ImagePicker();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // ═══════════════════════════════════════════════════════════
  // CAMERA
  // ═══════════════════════════════════════════════════════════

  Future<String?> pickImageFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      return photo?.path;
    } catch (e) {
      return null;
    }
  }

  Future<String?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      return image?.path;
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GPS / LOCATION
  // ═══════════════════════════════════════════════════════════

  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  String formatLocation(double? lat, double? lng) {
    if (lat == null || lng == null) return 'No location';
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  // ═══════════════════════════════════════════════════════════
  // BATTERY
  // ═══════════════════════════════════════════════════════════

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

  Stream<BatteryState> get batteryStateStream =>
      _battery.onBatteryStateChanged;

  // ═══════════════════════════════════════════════════════════
  // CONNECTIVITY
  // ═══════════════════════════════════════════════════════════

  Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  Stream<ConnectivityResult> get connectivityStream =>
      _connectivity.onConnectivityChanged.map(
            (results) => results.isNotEmpty
            ? results.first
            : ConnectivityResult.none,
      );

  // ═══════════════════════════════════════════════════════════
  // ACCELEROMETER / SHAKE DETECTION
  // ═══════════════════════════════════════════════════════════

  Stream<AccelerometerEvent> get accelerometerStream =>
      accelerometerEventStream();

  Stream<bool> get shakeStream {
    double lastX = 0, lastY = 0, lastZ = 0;
    const double shakeThreshold = 15.0;

    return accelerometerEventStream().map((event) {
      double deltaX = (event.x - lastX).abs();
      double deltaY = (event.y - lastY).abs();
      double deltaZ = (event.z - lastZ).abs();

      lastX = event.x;
      lastY = event.y;
      lastZ = event.z;

      return (deltaX + deltaY + deltaZ) > shakeThreshold;
    }).where((isShaking) => isShaking);
  }

  // ═══════════════════════════════════════════════════════════
  // GYROSCOPE
  // ═══════════════════════════════════════════════════════════

  // Stream gyroscope events
  Stream<GyroscopeEvent> get gyroscopeStream => gyroscopeEventStream();

  // Get gyroscope tilt description
  String getGyroscopeTilt(double x, double y, double z) {
    if (x.abs() > y.abs() && x.abs() > z.abs()) {
      return x > 0 ? 'Tilting Forward' : 'Tilting Backward';
    } else if (y.abs() > x.abs() && y.abs() > z.abs()) {
      return y > 0 ? 'Tilting Right' : 'Tilting Left';
    } else {
      return z > 0 ? 'Rotating Clockwise' : 'Rotating Counter-clockwise';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // FINGERPRINT / BIOMETRIC
  // ═══════════════════════════════════════════════════════════

  // Check if biometric is available
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Authenticate with biometric
  Future<bool> authenticateWithBiometric() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access ExpenseMate',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}