// lib/providers/device_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data'; // For image data
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';

class DeviceProvider with ChangeNotifier {
  String _deviceIp = '';
  // Removed static dummyDeviceId
  String _ldrStatus = 'Unknown';
  bool _isScanning = false;
  bool _isCommunicating = false;
  String? _error;
  String _deviceName = 'Smart Fridge Monitor'; // Default name before discovery
  Uint8List? _latestSnapshot;

  String get deviceIp => _deviceIp;
  String get ldrStatus => _ldrStatus;
  bool get isScanning => _isScanning;
  bool get isDeviceFound => _deviceIp.isNotEmpty;
  bool get isCommunicating => _isCommunicating;
  String? get error => _error;
  String get deviceName => _deviceName;
  Uint8List? get latestSnapshot => _latestSnapshot;

  // This MUST match the name you set in your Arduino mDNS code
  final String _serviceName = '_inventory-fridge._tcp.local';

  // Constructor is now empty, doesn't connect dummy device
  DeviceProvider();

  // Removed connectDummyDevice() method

  // --- RESTORED: Real Scan Logic ---
  Future<void> scanForDevice() async {
    _isScanning = true;
    _deviceIp = ''; // Clear previous IP
    _deviceName = 'Smart Fridge Monitor'; // Reset name
    _ldrStatus = 'Unknown'; // Reset status
    _error = null;
    _latestSnapshot = null;
    notifyListeners();

    try {
      final MDnsClient client = MDnsClient();
      await client.start();

      await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(_serviceName))) {
        await for (final SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName))) {
          // Use the A record to find the IP
          await for (final IPAddressResourceRecord a
              in client.lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srv.target))) {

            _deviceIp = a.address.address;
            _deviceName = srv.target.split('.').first; // Get name like "arduino"
            _isScanning = false;
            client.stop();
            notifyListeners();
            // After finding, let's get the status
            await getLdrStatus();
            return; // Found device, exit scan
          }
        }
      }

      // If loop finishes without finding, start a timeout
      // Use Timer to handle case where no device responds within a timeframe
      Timer(const Duration(seconds: 10), () {
        if (_isScanning) { // Check if still scanning (ie, not found yet)
          _isScanning = false;
          _error = 'Device not found. Check WiFi and device power.';
          client.stop(); // Ensure client is stopped on timeout
          notifyListeners();
        }
      });
    } catch (e) {
      _isScanning = false;
      _error = 'Network error during scan: $e';
      notifyListeners();
    }
  }
  // --- END RESTORED ---

  // --- RESTORED: Real LDR Status Logic ---
  Future<void> getLdrStatus() async {
    if (!isDeviceFound) {
      _error = 'Device not found. Please scan first.';
      notifyListeners();
      return;
    }

    _isCommunicating = true;
    _error = null;
    notifyListeners();

    try {
      // Your Arduino will host a web server at this address
      final response = await http.get(Uri.parse('http://$_deviceIp/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _ldrStatus = data['ldr_status'] ?? 'Error reading status';
      } else {
        _error = 'Failed to get status (Code: ${response.statusCode})';
      }
    } catch (e) {
      _error = 'Communication failed (getLdrStatus). Is the device online at $_deviceIp?';
    }

    _isCommunicating = false;
    notifyListeners();
  }
  // --- END RESTORED ---

  // --- RESTORED: Real Snapshot Logic ---
  Future<bool> triggerSnapshot() async {
    if (!isDeviceFound) {
      _error = 'Device not found. Please scan first.';
      notifyListeners();
      return false;
    }

    _isCommunicating = true;
    _error = null;
    _latestSnapshot = null; // Clear previous snapshot
    notifyListeners();

    bool success = false;

    try {
      // We expect this endpoint to return the raw image
      final response = await http.post(Uri.parse('http://$_deviceIp/snapshot'))
          .timeout(const Duration(seconds: 15)); // Longer timeout for snapshot+transfer

      if (response.statusCode == 200 &&
          response.headers['content-type']?.contains('image/jpeg') == true) { // More robust content-type check
        _latestSnapshot = response.bodyBytes; // Store the image
        success = true;
      } else {
        _error = 'Failed to get snapshot image (Code: ${response.statusCode}, Type: ${response.headers['content-type']})';
      }
    } catch (e) {
      _error = 'Communication failed (triggerSnapshot). Is the device online at $_deviceIp?';
    }

    _isCommunicating = false;
    notifyListeners();
    return success;
  }
  // --- END RESTORED ---
}