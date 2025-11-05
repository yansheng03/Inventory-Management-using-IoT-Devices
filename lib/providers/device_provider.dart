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
  String _ldrStatus = 'Unknown';
  bool _isScanning = false;
  bool _isCommunicating = false;
  String? _error;
  String _deviceName = 'Smart Fridge Monitor';
  Uint8List? _latestSnapshot;

  String get deviceIp => _deviceIp;
  String get ldrStatus => _ldrStatus;
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
    _ldrStatus = 'Unknown';
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
      final response = await http.post(
        Uri.parse('http://$_deviceIp/forget-wifi'),
      ).timeout(const Duration(seconds: 5));

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

  // --- *** THIS FUNCTION IS NOW FIXED *** ---
  Future<void> scanForDevice() async {
    _isScanning = true;
    _deviceIp = '';
    _ldrStatus = 'Unknown';
    _error = null;
    _latestSnapshot = null;
    notifyListeners();

    try {
      // --- STAGE 1: Try mDNS (The fast way) ---
      final MDnsClient client = MDnsClient();
      await client.start();

      await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(_serviceName))) {
        if (!ptr.domainName.startsWith('inventory-fridge')) {
          continue;
        }

        await for (final SrvResourceRecord srv
            in client.lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName))) {
          await for (final IPAddressResourceRecord a
              in client.lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srv.target))) {
            _deviceIp = a.address.address;
            _deviceName = srv.target.split('.').first;
            _isScanning = false;
            client.stop();
            notifyListeners();
            await getLdrStatus();
            return; 
          }
        }
      }

      // mDNS scan timed out
      client.stop();
      throw Exception('mDNS scan failed. Trying cloud lookup...');
      
    } catch (e) {
      // --- STAGE 2: mDNS FAILED. Try Cloud IP Lookup ---
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
         _isScanning = false;
        _error = 'Not logged in. Cannot find device.';
        notifyListeners();
        return;
      }
      
      String? deviceId;
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        
        // --- *** THIS IS THE FIX *** ---
        // Check if the document exists AND has data
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          // Check if the 'deviceId' field exists
          if (data.containsKey('deviceId')) {
            deviceId = data['deviceId'];
          }
        }
        // --- *** END OF FIX *** ---

      } catch (e) {
        _isScanning = false;
        _error = 'Could not read your user profile from Firestore.';
        notifyListeners();
        return;
      }

      if (deviceId == null || deviceId.isEmpty) {
        _isScanning = false;
        _error = 'No deviceId linked to your account. Please run setup.';
        notifyListeners();
        return;
      }
      
      // --- NOW WE CAN QUERY FOR THE IP ---
      try {
        DocumentSnapshot deviceDoc = await FirebaseFirestore.instance
            .collection('device_locations')
            .doc(deviceId)
            .get();

        if (!deviceDoc.exists) {
          throw Exception('Device has never reported its IP address.');
        }

        final deviceData = deviceDoc.data() as Map<String, dynamic>;
        // Check if the 'ip' field exists
        if (!deviceData.containsKey('ip') || (deviceData['ip'] as String).isEmpty) {
           throw Exception('Device IP in database is empty.');
        }
        
        String ip = deviceData['ip'];

        _deviceIp = ip;
        _deviceName = '$deviceId (Cloud)';
        _isScanning = false;
        notifyListeners();
        
        await getLdrStatus(); 

      } catch (e) {
        _isScanning = false;
        // This is the error message you are seeing.
        _error = 'AP Isolation active and cloud lookup failed. Check device power.';
        notifyListeners();
      }
    }
  }

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
      final response = await http.get(Uri.parse('http://$_deviceIp/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _ldrStatus = data['status']?.toString().toUpperCase() ?? 'Error'; 
      } else {
        _error = 'Failed to get status (Code: ${response.statusCode})';
      }
    } catch (e) {
      _error = 'Communication failed (getLdrStatus). Is the device online at $_deviceIp?';
      _resetConnectionState(); 
    }

    _isCommunicating = false;
    notifyListeners();
  }

  Future<bool> triggerSnapshot() async {
    if (!isDeviceFound) {
      _error = 'Device not found. Please scan first.';
      notifyListeners();
      return false;
    }

    _isCommunicating = true;
    _error = null;
    _latestSnapshot = null; 
    notifyListeners();

    bool success = false;

    try {
      final response = await http.post(Uri.parse('http://$_deviceIp/snapshot'))
          .timeout(const Duration(seconds: 20)); 

      if (response.statusCode == 200 &&
          response.headers['content-type']?.contains('image/jpeg') == true) { 
        _latestSnapshot = response.bodyBytes; 
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
}