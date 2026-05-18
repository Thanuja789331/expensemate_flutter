import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/device_service.dart';
import '../../theme/app_theme.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  final DeviceService _deviceService = DeviceService();

  // Gyroscope
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;
  String _tiltDescription = 'Hold your phone';
  StreamSubscription? _gyroSubscription;

  // Accelerometer
  double _accelX = 0, _accelY = 0, _accelZ = 0;
  StreamSubscription? _accelSubscription;

  // Biometric
  bool _isBiometricAvailable = false;
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  List<String> _biometricTypes = [];

  @override
  void initState() {
    super.initState();
    _initSensors();
    _checkBiometric();
  }

  @override
  void dispose() {
    _gyroSubscription?.cancel();
    _accelSubscription?.cancel();
    super.dispose();
  }

  // ── Init sensors ─────────────────────────────────────────────
  void _initSensors() {
    // Gyroscope
    _gyroSubscription = _deviceService.gyroscopeStream.listen((event) {
      if (mounted) {
        setState(() {
          _gyroX = event.x;
          _gyroY = event.y;
          _gyroZ = event.z;
          _tiltDescription =
              _deviceService.getGyroscopeTilt(event.x, event.y, event.z);
        });
      }
    });

    // Accelerometer
    _accelSubscription =
        _deviceService.accelerometerStream.listen((event) {
          if (mounted) {
            setState(() {
              _accelX = event.x;
              _accelY = event.y;
              _accelZ = event.z;
            });
          }
        });
  }

  // ── Check biometric ──────────────────────────────────────────
  Future<void> _checkBiometric() async {
    final available = await _deviceService.isBiometricAvailable();
    final types = await _deviceService.getAvailableBiometrics();

    if (mounted) {
      setState(() {
        _isBiometricAvailable = available;
        _biometricTypes = types.map((t) => t.toString()).toList();
      });
    }
  }

  // ── Authenticate ─────────────────────────────────────────────
  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _isAuthenticated = false;
    });

    final success = await _deviceService.authenticateWithBiometric();

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
        _isAuthenticated = success;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(success
                  ? 'Authentication successful!'
                  : 'Authentication failed'),
            ],
          ),
          backgroundColor: success ? AppTheme.primaryGreen : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Sensors'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Gyroscope Card ───────────────────────────────
            Text(
              'Gyroscope',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Tilt description
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.screen_rotation,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _tiltDescription,
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Values
                    _SensorValueRow(
                      label: 'X axis',
                      value: _gyroX,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    _SensorValueRow(
                      label: 'Y axis',
                      value: _gyroY,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _SensorValueRow(
                      label: 'Z axis',
                      value: _gyroZ,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 24),

            // ── Accelerometer Card ───────────────────────────
            Text(
              'Accelerometer',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SensorValueRow(
                      label: 'X axis',
                      value: _accelX,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    _SensorValueRow(
                      label: 'Y axis',
                      value: _accelY,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _SensorValueRow(
                      label: 'Z axis',
                      value: _accelZ,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '💡 Shake your phone to refresh the home screen!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 24),

            // ── Fingerprint Card ─────────────────────────────
            Text(
              'Biometric Authentication',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Status
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isBiometricAvailable
                                ? AppTheme.primaryGreen.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.fingerprint,
                            size: 40,
                            color: _isBiometricAvailable
                                ? AppTheme.primaryGreen
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isBiometricAvailable
                                    ? 'Biometric Available'
                                    : 'Biometric Not Available',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isBiometricAvailable
                                      ? AppTheme.primaryGreen
                                      : Colors.grey,
                                ),
                              ),
                              if (_biometricTypes.isNotEmpty)
                                Text(
                                  _biometricTypes.join(', '),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              if (_isAuthenticated)
                                const Text(
                                  '✅ Authenticated!',
                                  style: TextStyle(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Authenticate button
                    ElevatedButton.icon(
                      onPressed: _isAuthenticating ? null : _authenticate,
                      icon: _isAuthenticating
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.fingerprint),
                      label: Text(
                        _isAuthenticating
                            ? 'Authenticating...'
                            : 'Authenticate with Biometric',
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ── Sensor Value Row Widget ──────────────────────────────────────
class _SensorValueRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SensorValueRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value.abs() / 10).clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}