import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';

// --- DEVICE SERVICE ---
// This class acts as a bridge between Flutter and the Phone's Hardware.
// We use it for Camera, GPS, Battery, and Sensors.
class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final ImagePicker _imagePicker = ImagePicker();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // --- CAMERA & GALLERY ---
  
  // Open phone camera to take a photo of a receipt
  Future<String?> pickImageFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // Compressing image to save space
      );
      return photo?.path;
    } catch (e) {
      return null;
    }
  }

  // Pick receipt from the phone gallery
  Future<String?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      return image?.path;
    } catch (e) {
      return null;
    }
  }

  // --- GPS / LOCATION ---

  // Get current GPS coordinates (Viva: Mention Permission Handling)
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // Ask for permission if not already granted
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  // --- BATTERY & NETWORK ---

  Future<int> getBatteryLevel() async => await _battery.batteryLevel;
  Future<BatteryState> getBatteryState() async => await _battery.batteryState;

  // Check if phone has active Wifi or Mobile Data
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // --- ACCELEROMETER (SHAKE) ---

  // Detects if the user shakes the phone (Threshold: 15.0)
  Stream<bool> get shakeStream {
    double lastX = 0, lastY = 0, lastZ = 0;
    const double shakeThreshold = 15.0;

    return accelerometerEventStream().map((event) {
      // Calculate change in motion on all 3 axes
      double deltaX = (event.x - lastX).abs();
      double deltaY = (event.y - lastY).abs();
      double deltaZ = (event.z - lastZ).abs();

      lastX = event.x;
      lastY = event.y;
      lastZ = event.z;

      return (deltaX + deltaY + deltaZ) > shakeThreshold;
    }).where((isShaking) => isShaking);
  }

  // --- BIOMETRICS ---

  // Check if phone has fingerprint or face unlock hardware
  Future<bool> isBiometricAvailable() async {
    return await _localAuth.canCheckBiometrics && await _localAuth.isDeviceSupported();
  }

  // Trigger the system biometric popup
  Future<bool> authenticateWithBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint to unlock ExpenseMate',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (e) {
      return false;
    }
  }
}
