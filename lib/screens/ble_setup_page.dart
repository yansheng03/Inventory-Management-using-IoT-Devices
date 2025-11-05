// lib/screens/ble_setup_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleSetupPage extends StatefulWidget {
  const BleSetupPage({super.key});

  @override
  State<BleSetupPage> createState() => _BleSetupPageState();
}

class _BleSetupPageState extends State<BleSetupPage> {
  // --- Arduino BLE UUIDs (MUST MATCH ARDUINO CODE) ---
  final String serviceUuid = "19B10000-E8F2-537E-4F6C-D104768A1214";
  final String ssidCharUuid = "19B10001-E8F2-537E-4F6C-D104768A1214";
  final String passCharUuid = "19B10002-E8F2-537E-4F6C-D104768A1214";
  final String deviceIdCharUuid = "19B10003-E8F2-537E-4F6C-D104768A1214";
  // ---------------------------------------------------

  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  final _deviceIdController = TextEditingController();

  BluetoothDevice? _targetDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  bool _isSending = false;
  String _statusMessage = 'Awaiting permissions...';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // Required for BLE scanning
    ].request();

    if (statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted) {
      setState(() => _statusMessage = 'Ready. Press "Scan" to begin.');
    } else {
      setState(() =>
          _statusMessage = 'Permissions denied. Please grant permissions in settings.');
    }
  }

  void _startScan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for "InventoryFridge-Setup"...';
      _targetDevice = null;
      _isConnected = false;
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(serviceUuid)],
        timeout: const Duration(seconds: 5),
      );

      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.platformName == 'InventoryFridge-Setup') {
            FlutterBluePlus.stopScan();
            setState(() {
              _targetDevice = r.device;
              _statusMessage = 'Device found! Ready to connect.';
              _isScanning = false;
            });
            break;
          }
        }
      });

      // Handle scan timeout
      await Future.delayed(const Duration(seconds: 5));
      if (_isScanning) {
        FlutterBluePlus.stopScan();
        setState(() {
          _isScanning = false;
          _statusMessage = 'Device not found. Check if it\'s powered on and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Scan Error: $e';
        _isScanning = false;
      });
    }
  }

  void _connectToDevice() async {
    if (_targetDevice == null) return;

    setState(() => _statusMessage = 'Connecting...');
    try {
      await _targetDevice!.connect();
      setState(() {
        _isConnected = true;
        _statusMessage = 'Connected! Please fill in all fields.';
      });
    } catch (e) {
      setState(() {
         _isConnected = false;
        _statusMessage = 'Connection failed: $e';
      });
    }
  }

  void _disconnectDevice() {
    _targetDevice?.disconnect();
    setState(() {
      _isConnected = false;
      _targetDevice = null;
      _statusMessage = 'Disconnected. Ready to scan again.';
    });
  }

  void _sendCredentials() async {
    if (!_isConnected ||
        _ssidController.text.isEmpty ||
        _passController.text.isEmpty ||
        _deviceIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required!')),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _statusMessage = 'Sending credentials...';
    });

    try {
      List<BluetoothService> services = await _targetDevice!.discoverServices();
      BluetoothService targetService = services.firstWhere((s) => s.uuid == Guid(serviceUuid));

      // Find characteristics
      BluetoothCharacteristic ssidChar = targetService.characteristics
          .firstWhere((c) => c.uuid == Guid(ssidCharUuid));
      BluetoothCharacteristic passChar = targetService.characteristics
          .firstWhere((c) => c.uuid == Guid(passCharUuid));
      BluetoothCharacteristic deviceIdChar = targetService.characteristics
          .firstWhere((c) => c.uuid == Guid(deviceIdCharUuid));

      // Write values (as bytes)
      await ssidChar.write(_ssidController.text.codeUnits);
      await Future.delayed(const Duration(milliseconds: 100));
      await passChar.write(_passController.text.codeUnits);
      await Future.delayed(const Duration(milliseconds: 100));
      await deviceIdChar.write(_deviceIdController.text.codeUnits);

      setState(() {
        _statusMessage = 'Credentials sent successfully! The Arduino will now restart.';
        _isSending = false;
      });

      // Disconnect after sending
      _disconnectDevice();
      
      // Pop back to the device page
      if (mounted) {
        Navigator.of(context).pop();
      }

    } catch (e) {
      setState(() {
        _statusMessage = 'Error sending: $e';
        _isSending = false;
      });
    }
  }
  
  @override
  void dispose() {
    _targetDevice?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Setup (BLE)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(_statusMessage, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isScanning || _isConnected ? null : _startScan,
              child: _isScanning
                  ? const CircularProgressIndicator()
                  : const Text('1. Scan for Device'),
            ),
            ElevatedButton(
              onPressed: _targetDevice == null || _isConnected ? null : _connectToDevice,
              child: const Text('2. Connect to Device'),
            ),
            const Divider(height: 32),
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(labelText: 'WiFi SSID'),
            ),
            TextField(
              controller: _passController,
              decoration: const InputDecoration(labelText: 'WiFi Password'),
              obscureText: true,
            ),
            TextField(
              controller: _deviceIdController,
              decoration: const InputDecoration(labelText: 'Device ID (e.g., fridge1)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: !_isConnected || _isSending ? null : _sendCredentials,
              child: _isSending
                  ? const CircularProgressIndicator()
                  : const Text('3. Send Credentials'),
            ),
             if (_isConnected)
              OutlinedButton(
                onPressed: _disconnectDevice,
                child: const Text('Disconnect'),
              ),
          ],
        ),
      ),
    );
  }
}