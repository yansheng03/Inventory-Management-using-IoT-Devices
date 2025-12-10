// lib/providers/device_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeviceProvider with ChangeNotifier {
  String _deviceIp = '';
  String _connectionStatus = 'Unknown';
  bool _isScanning = false;
  bool _isCommunicating = false;
  String? _error;
  String _deviceName = 'Smart Fridge Monitor';
  Uint8List? _latestSnapshot;

  String get deviceIp => _deviceIp;
  String get connectionStatus => _connectionStatus;
  bool get isScanning => _isScanning;
  bool get isDeviceFound => _deviceIp.isNotEmpty;
  bool get isCommunicating => _isCommunicating;
  String? get error => _error;
  String get deviceName => _deviceName;
  Uint8List? get latestSnapshot => _latestSnapshot;

  final String _serviceName = '_http._tcp.local';

  DeviceProvider();

  void _resetConnectionState() {
    _deviceIp = '';
    _connectionStatus = 'Unknown';
    _isScanning = false;
    _isCommunicating = false;
    _error = null;
    _deviceName = 'Smart Fridge Monitor';
    _latestSnapshot = null;
    notifyListeners();
  }

  Future<bool> forgetWifi() async {
    if (!isDeviceFound) return false;

    _isCommunicating = true;
    _error = null;
    notifyListeners();

    bool success = false;
    try {
      final response = await http
          .post(Uri.parse('http://$_deviceIp/forget-wifi'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _resetConnectionState();
        success = true;
      } else {
        _error = 'Failed to send forget command (Code: ${response.statusCode})';
      }
    } catch (e) {
      if (e is TimeoutException) {
        _resetConnectionState();
        success = true;
      } else {
        _error = 'Communication failed (forgetWifi).';
      }
    }

    _isCommunicating = false;
    notifyListeners();
    return success;
  }

  Future<void> scanForDevice() async {
    _isScanning = true;
    _deviceIp = '';
    _connectionStatus = 'Unknown';
    _error = null;
    _latestSnapshot = null;
    notifyListeners();

    try {
      // --- STAGE 1: mDNS ---
      final MDnsClient client = MDnsClient();
      await client.start();

      await for (final PtrResourceRecord ptr
          in client.lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(_serviceName),
          )) {
        if (!ptr.domainName.startsWith('inventory-fridge')) {
          continue;
        }

        await for (final SrvResourceRecord srv
            in client.lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            )) {
          await for (final IPAddressResourceRecord a
              in client.lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )) {
            _deviceIp = a.address.address;
            _deviceName = srv.target.split('.').first;
            _isScanning = false;
            client.stop();
            notifyListeners();
            await checkDeviceStatus();
            return;
          }
        }
      }
      client.stop();

      // --- STAGE 2: Cloud Lookup ---
      // If mDNS failed, try finding IP from Firestore
      throw Exception('mDNS scan failed. Trying cloud lookup...');
    } catch (e) {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _isScanning = false;
        _error = 'Not logged in.';
        notifyListeners();
        return;
      }

      String? deviceId;
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          if (data.containsKey('deviceId')) {
            deviceId = data['deviceId'];
          }
        }
      } catch (e) {
        _isScanning = false;
        _error = 'Could not read user profile.';
        notifyListeners();
        return;
      }

      if (deviceId == null || deviceId.isEmpty) {
        _isScanning = false;
        _error = 'No device linked. Please run setup.';
        notifyListeners();
        return;
      }

      try {
        DocumentSnapshot deviceDoc = await FirebaseFirestore.instance
            .collection('device_locations')
            .doc(deviceId)
            .get();

        if (!deviceDoc.exists) throw Exception('No IP record.');

        final deviceData = deviceDoc.data() as Map<String, dynamic>;
        if (!deviceData.containsKey('ip') ||
            (deviceData['ip'] as String).isEmpty) {
          throw Exception('Device IP empty.');
        }

        _deviceIp = deviceData['ip'];
        _deviceName = '$deviceId (Cloud)';
        _isScanning = false;
        notifyListeners();

        await checkDeviceStatus();
      } catch (e) {
        _isScanning = false;
        _error = 'Device not found. Is it powered on?';
        notifyListeners();
      }
    }
  }

  Future<void> syncTimeWithDevice() async {
    if (!isDeviceFound) return;
    try {
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http
          .post(Uri.parse('http://$_deviceIp/set-time?timestamp=$timestamp'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        print("Device Time Synced Successfully");
      }
    } catch (e) {
      print("Time Sync Failed: $e");
    }
  }

  Future<void> checkDeviceStatus() async {
    if (!isDeviceFound) {
      _error = 'Device not connected.';
      notifyListeners();
      return;
    }

    _isCommunicating = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse('http://$_deviceIp/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // ESP32 sends {"status":"online"}
        _connectionStatus = data['status']?.toString().toUpperCase() ?? 'Error';
        syncTimeWithDevice();
      } else {
        _error = 'Status check failed (Code: ${response.statusCode})';
      }
    } catch (e) {
      _error = 'Connection timed out. Check if device is powered.';
      // We don't reset IP here immediately to allow retrying
    }

    _isCommunicating = false;
    notifyListeners();
  }

// --- ADD THIS FUNCTION ---
  Future<bool> clearDeviceLogs() async {
    if (!isDeviceFound) return false;

    _isCommunicating = true;
    notifyListeners();

    bool success = false;
    try {
      final response = await http
          .post(Uri.parse('http://$_deviceIp/clear-logs'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        success = true;
      } else {
        _error = 'Failed to clear logs (Code: ${response.statusCode})';
      }
    } catch (e) {
      _error = 'Connection failed while clearing logs.';
    }

    _isCommunicating = false;
    notifyListeners();
    return success;
  }
  
  Future<bool> triggerSnapshot() async {
    if (!isDeviceFound) {
      _error = 'Device not connected. Please scan first.';
      notifyListeners();
      return false;
    }

    _isCommunicating = true;
    _error = null;
    notifyListeners();

    bool success = false;

    try {
      final response = await http
          .get(Uri.parse('http://$_deviceIp/snapshot'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 &&
          response.headers['content-type']?.contains('image/jpeg') == true) {
        _latestSnapshot = response.bodyBytes;
        success = true;
      } else {
        _error = 'Snapshot failed (Code: ${response.statusCode})';
      }
    } catch (e) {
      _error = 'Connection timed out. Ensure you are close to the device.';
    }

    _isCommunicating = false;
    notifyListeners();
    return success;
  }

}
