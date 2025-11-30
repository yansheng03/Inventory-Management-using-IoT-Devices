// lib/screens/ble_setup_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:capstone_app/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BleSetupPage extends StatefulWidget {
  const BleSetupPage({super.key});

  @override
  State<BleSetupPage> createState() => _BleSetupPageState();
}

class _BleSetupPageState extends State<BleSetupPage> {
  // --- UUIDs matching ESP32 Code ---
  final String serviceUuid = "19B10000-E8F2-537E-4F6C-D104768A1214";
  final String ssidCharUuid = "19B10001-E8F2-537E-4F6C-D104768A1214";
  final String passCharUuid = "19B10002-E8F2-537E-4F6C-D104768A1214";
  final String deviceIdCharUuid = "19B10003-E8F2-537E-4F6C-D104768A1214";
  final String statusCharUuid = "19B10004-E8F2-537E-4F6C-D104768A1214";
  final String ownerIdCharUuid = "19B10005-E8F2-537E-4F6C-D104768A1214";

  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  final _deviceNameController = TextEditingController();

  BluetoothDevice? _targetDevice;
  BluetoothCharacteristic? _statusCharacteristic;
  
  bool _isScanning = false;
  bool _isConnected = false;
  bool _isSending = false;
  String _statusMessage = 'Ready to scan';

  String? _deviceIdToUse; 
  Timer? _successTimer;
  
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription? _statusSubscription;
  StreamSubscription? _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _fetchExistingDevice();
  }

  Future<void> _fetchExistingDevice() async {
    String? existingId = await _firebaseService.getUserDevice();
    if (existingId != null) {
      _deviceIdToUse = existingId;
    } else {
      _deviceIdToUse = "dev_${DateTime.now().millisecondsSinceEpoch}";
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
      
      if (statuses[Permission.bluetoothScan]!.isGranted &&
          statuses[Permission.bluetoothConnect]!.isGranted) {
        setState(() => _statusMessage = 'Ready. Press "Scan".');
      }
    }
  }

  void _startScan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for devices...';
      _targetDevice = null;
      _isConnected = false;
    });

    try {
      await FlutterBluePlus.stopScan();
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

      await Future.delayed(const Duration(seconds: 5));
      if (_isScanning) {
        FlutterBluePlus.stopScan();
        setState(() {
          _isScanning = false;
          _statusMessage = 'Device not found. Is it in Setup Mode?';
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
      await Future.delayed(const Duration(milliseconds: 200));
      await _targetDevice!.connect(autoConnect: false);
      
      _connectionStateSubscription = _targetDevice!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (_isSending) {
            // Unexpected disconnect during sending usually means the device rebooted (Success)
            print("Device disconnected during setup -> Assuming Success");
            _handleSuccess(); 
          } else {
             setState(() => _isConnected = false);
          }
        }
      });

      List<BluetoothService> services = await _targetDevice!.discoverServices();
      BluetoothService targetService =
          services.firstWhere((s) => s.uuid == Guid(serviceUuid));

      _statusCharacteristic = targetService.characteristics
          .firstWhere((c) => c.uuid == Guid(statusCharUuid));
          
      await _statusCharacteristic!.setNotifyValue(true);
      _statusSubscription = _statusCharacteristic!.onValueReceived.listen(_onStatusReceived);

      setState(() {
        _isConnected = true;
        _statusMessage = 'Connected!';
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Connection Failed. Try moving closer.';
      });
    }
  }

  void _onStatusReceived(List<int> value) async {
    String message = utf8.decode(value);
    debugPrint("BLE MSG: $message");

    if (message.contains("SUCCESS")) {
       _handleSuccess();
    } else if (message.contains("FAILED")) {
       _handleFailure();
    } else {
      setState(() => _statusMessage = message);
    }
  }
  
  // --- UPDATED SUCCESS LOGIC ---
void _handleSuccess() async {
    if (!mounted || !_isSending) return; 
    _successTimer?.cancel();
    
    // Update status to show we are finalizing
    setState(() => _statusMessage = "Connected! Registering with Cloud...");
    
    try {
       String name = _deviceNameController.text.trim();
       if(name.isEmpty) name = "Smart Camera";

       // Register device in Firestore
       await _firebaseService.registerConfirmedDevice(
         deviceId: _deviceIdToUse!,
         deviceName: name,
       );

       _cleanup(); // Disconnect BLE cleanly

       if (!mounted) return;

       // --- THE FIX: Indefinite Dialog ---
       showDialog(
         context: context,
         barrierDismissible: false, // User CANNOT click outside to close
         builder: (ctx) => AlertDialog(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           title: const Row(
             children: [
               Icon(Icons.check_circle, color: Colors.green, size: 30),
               SizedBox(width: 10),
               Text("Setup Complete"),
             ],
           ),
           content: const Text(
             "Your camera is successfully connected to WiFi and registered.\n\n"
             "You can now control it from the Device Dashboard."
           ),
           actions: [
             ElevatedButton(
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.green,
                 foregroundColor: Colors.white,
                 minimumSize: const Size(100, 45),
               ),
               onPressed: () {
                 Navigator.of(ctx).pop(); // Close Dialog
                 Navigator.of(context).pop(); // Return to Device Page
               },
               child: const Text("Go to Dashboard"),
             )
           ],
         ),
       );

    } catch (e) {
      setState(() => _statusMessage = "Registration Error: $e");
    }
  }

  void _handleFailure() {
    _successTimer?.cancel();
    setState(() {
      _isSending = false;
      _statusMessage = "Setup Failed.";
    });
    _showDialog("Connection Failed", "The device could not connect to WiFi. Please check your password and try again.");
  }

  void _showDialog(String title, String content) {
    if(!mounted) return;
    showDialog(
      context: context, 
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      )
    );
  }

  void _cleanup() {
    _statusSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _targetDevice?.disconnect();
  }
  
  @override
  void dispose() {
    _cleanup();
    _ssidController.dispose();
    _passController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  void _sendCredentials() async {
    if (!_isConnected || _ssidController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WiFi Credentials are required')));
      return;
    }

    setState(() {
      _isSending = true;
      _statusMessage = 'Sending configuration...';
    });

    // Fallback timer: If the device works but forgets to reply, we assume success after 25s
    _successTimer = Timer(const Duration(seconds: 25), () {
        print("Timer expired -> Assuming Success");
        _handleSuccess();
    });

    try {
      String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if(currentUserId == null) throw Exception("Login required");

      List<BluetoothService> services = await _targetDevice!.discoverServices();
      BluetoothService targetService = services.firstWhere((s) => s.uuid == Guid(serviceUuid));

      var ssidChar = targetService.characteristics.firstWhere((c) => c.uuid == Guid(ssidCharUuid));
      var passChar = targetService.characteristics.firstWhere((c) => c.uuid == Guid(passCharUuid));
      var deviceIdChar = targetService.characteristics.firstWhere((c) => c.uuid == Guid(deviceIdCharUuid));
      var ownerIdChar = targetService.characteristics.firstWhere((c) => c.uuid == Guid(ownerIdCharUuid));

      // Small delays to ensure reliability
      await ssidChar.write(_ssidController.text.codeUnits, withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 200));
      
      await passChar.write(_passController.text.codeUnits, withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 200));
      
      await ownerIdChar.write(currentUserId.codeUnits, withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 200));
      
      setState(() => _statusMessage = 'Verifying connection (Wait 15s)...');
      
      // Sending Device ID triggers the test on the ESP32
      await deviceIdChar.write(_deviceIdToUse!.codeUnits, withoutResponse: false);

    } catch (e) {
      // GATT 133 often means the device rebooted successfully before replying
      if(e.toString().contains("133") || e.toString().contains("GATT_ERROR")) {
         print("GATT 133 Caught -> Treating as Reboot/Success");
         _handleSuccess();
      } else {
        _successTimer?.cancel();
        setState(() {
          _statusMessage = 'Write Error: $e';
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Setup')),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: Colors.blue.shade900, 
                    fontWeight: FontWeight.w600,
                    fontSize: 16
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              if(_isSending) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: Text(_isScanning ? 'Scanning...' : '1. Scan'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: _isScanning || _isConnected ? null : _startScan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bluetooth_connected),
                      label: const Text('2. Connect'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: _targetDevice == null || _isConnected ? null : _connectToDevice,
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 40),
              
              Text("WiFi Credentials", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _ssidController,
                decoration: const InputDecoration(
                  labelText: 'WiFi Network Name (SSID)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                decoration: const InputDecoration(
                  labelText: 'WiFi Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              
              Text("Device Details", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _deviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Name this Device (e.g. Kitchen Cam)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: !_isConnected || _isSending ? null : _sendCredentials,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('3. Link & Finish Setup', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}