import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
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

  // ═══════════════════════════════════════════════════════════
  // CAMERA
  // ═══════════════════════════════════════════════════════════

  // Pick image from camera
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

  // Pick image from gallery
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

  // Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      // Get position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  // Format location as readable string
  String formatLocation(double? lat, double? lng) {
    if (lat == null || lng == null) return 'No location';
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  // ═══════════════════════════════════════════════════════════
  // BATTERY
  // ═══════════════════════════════════════════════════════════

  // Get battery level (0-100)
  Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      return 0;
    }
  }

  // Get battery status
  Future<BatteryState> getBatteryState() async {
    try {
      return await _battery.batteryState;
    } catch (e) {
      return BatteryState.unknown;
    }
  }

  // Stream battery changes
  Stream<BatteryState> get batteryStateStream => _battery.onBatteryStateChanged;

  // ═══════════════════════════════════════════════════════════
  // CONNECTIVITY
  // ═══════════════════════════════════════════════════════════

  // Check if currently online
  Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // Stream connectivity changes
  Stream<ConnectivityResult> get connectivityStream =>
      _connectivity.onConnectivityChanged.map(
            (results) => results.isNotEmpty
            ? results.first
            : ConnectivityResult.none,
      );

  // ═══════════════════════════════════════════════════════════
  // ACCELEROMETER / SHAKE DETECTION
  // ═══════════════════════════════════════════════════════════

  // Stream accelerometer events
  Stream<AccelerometerEvent> get accelerometerStream =>
      accelerometerEventStream();

  // Detect shake gesture
  // Returns a stream that emits true when shake is detected
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
}