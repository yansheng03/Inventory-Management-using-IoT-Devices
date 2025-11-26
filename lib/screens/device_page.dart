// lib/screens/device_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_app/providers/device_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  // --- State Variables ---
  bool _isConnectingBLE = false;
  String _bleStatusMessage = 'Ready to start setup';

  // --- Arduino BLE UUIDs (MUST MATCH ARDUINO CODE) ---
  final String serviceUuid = "19B10000-E8F2-537E-4F6C-D104768A1214";
  final String ssidCharUuid = "19B10001-E8F2-537E-4F6C-D104768A1214";
  final String passCharUuid = "19B10002-E8F2-537E-4F6C-D104768A1214";
  final String deviceIdCharUuid = "19B10003-E8F2-537E-4F6C-D104768A1214";
  // ---------------------------------------------------

  // --- How-to-Guide Widget ---
  Widget _buildSetupGuide() {
    final theme = Theme.of(context);
    return ExpansionTile(
      leading: Icon(Icons.help_outline, color: theme.colorScheme.primary),
      title: const Text('How to Set Up Your Device'),
      children: [
        ListTile(
          dense: true,
          leading: const CircleAvatar(child: Text('1')),
          title: const Text('Go to Device Setup'),
          subtitle: const Text('Press the "1. Start Device Setup (BLE)" button below.'),
        ),
        ListTile(
          dense: true,
          leading: const CircleAvatar(child: Text('2')),
          title: const Text('Scan and Select'),
          subtitle: const Text('Wait for "InventoryFridge-Setup" to appear in the list and tap it.'),
        ),
        ListTile(
          dense: true,
          leading: const CircleAvatar(child: Text('3')),
          title: const Text('Enter Credentials'),
          subtitle: const Text('Enter your 2.4GHz WiFi SSID, password, and a unique Device ID (e.g., "fridge1").'),
        ),
        ListTile(
          dense: true,
          leading: const CircleAvatar(child: Text('4')),
          title: const Text('**Manually Reboot Device**'),
          subtitle: const Text('After success, the Arduino light will blink. **Unplug your Arduino, wait 5s, and plug it back in.**'),
        ),
         ListTile(
          dense: true,
          leading: const CircleAvatar(child: Text('5')),
          title: const Text('Restart App & Find Device'),
          subtitle: const Text('Completely restart this app, then press the "2. Find Device on WiFi" button.'),
        ),
      ],
    );
  }

  // --- BLE Scan & Selection Popup ---
  Future<BluetoothDevice?> _showBleScanDialog() async {
    // Start scan
    FlutterBluePlus.startScan(
      withServices: [Guid(serviceUuid)],
      timeout: const Duration(seconds: 5),
    );

    // Show a modal bottom sheet with the scan results
    return await showModalBottomSheet<BluetoothDevice?>(
      context: context,
      isScrollControlled: true,
      builder: (builderContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.4,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Scanning for Devices...', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Look for "InventoryFridge-Setup"'),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<List<ScanResult>>(
                      stream: FlutterBluePlus.scanResults,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        // Filter for non-empty names
                        final results = snapshot.data!
                            .where((r) => r.device.platformName.isNotEmpty)
                            .toList();

                        if (results.isEmpty) {
                           return const Center(child: Text('No devices found yet...'));
                        }

                        return ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final result = results[index];
                            return Card(
                              child: ListTile(
                                title: Text(result.device.platformName),
                                subtitle: Text(result.device.remoteId.toString()),
                                leading: const Icon(Icons.bluetooth),
                                onTap: () {
                                  FlutterBluePlus.stopScan();
                                  Navigator.of(context).pop(result.device); // Return the selected device
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- *** MODIFIED Restart App Dialog *** ---
  Future<void> _showRebootDialog() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Setup Successful!'),
        content: const Text(
          'The device has saved your credentials and its light should be blinking.\n\n'
          '**1. Unplug your Arduino.**\n'
          '**2. Wait 5 seconds.**\n'
          '**3. Plug it back in.**\n\n'
          'After it reboots, completely close and re-open this app.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), 
            child: const Text('OK'),
          )
        ],
      )
    );
  }

  // --- MODIFIED: The full BLE setup flow ---
  Future<void> _startBleSetup() async {
    // 1. Request permissions
    setState(() {
      _isConnectingBLE = true;
      _bleStatusMessage = 'Requesting permissions...';
    });
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (!statuses[Permission.bluetoothScan]!.isGranted ||
        !statuses[Permission.bluetoothConnect]!.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth & Location permissions are required for setup.')),
        );
      }
      setState(() => _isConnectingBLE = false);
      return;
    }

    // 2. Show Scan Dialog and let user pick a device
    setState(() => _bleStatusMessage = 'Opening device scanner...');
    final BluetoothDevice? targetDevice = await _showBleScanDialog();

    if (targetDevice == null) {
      // User cancelled the scan dialog
      setState(() => _isConnectingBLE = false);
      return;
    }

    // 3. Device selected, now connect
    try {
      setState(() => _bleStatusMessage = 'Connecting to ${targetDevice.platformName}...');
      await targetDevice.connect();

      // 4. Connected! Now ask for credentials
      setState(() => _bleStatusMessage = 'Connected! Awaiting credentials...');
      final creds = await _showCredentialsDialog();
      if (creds == null) { // User cancelled dialog
           setState(() => _isConnectingBLE = false);
           await targetDevice.disconnect(); // This disconnect is OK, user cancelled.
           return;
      }

      // 5. Send credentials
      setState(() => _bleStatusMessage = 'Discovering services...');
      List<BluetoothService> services = await targetDevice.discoverServices();
      BluetoothService targetService = services.firstWhere((s) => s.uuid == Guid(serviceUuid));

      BluetoothCharacteristic ssidChar = targetService.characteristics.firstWhere((c) => c.uuid == Guid(ssidCharUuid));
      BluetoothCharacteristic passChar = targetService.characteristics.firstWhere((c) => c.uuid == Guid(passCharUuid));
      BluetoothCharacteristic deviceIdChar = targetService.characteristics.firstWhere((c) => c.uuid == Guid(deviceIdCharUuid));

      setState(() => _bleStatusMessage = 'Sending credentials...');
      
      // We use "withoutResponse" to "fire and forget"
      await ssidChar.write(creds['ssid']!.codeUnits, withoutResponse: true);
      await Future.delayed(const Duration(milliseconds: 50));
      await passChar.write(creds['pass']!.codeUnits, withoutResponse: true);
      await Future.delayed(const Duration(milliseconds: 50));
      await deviceIdChar.write(creds['deviceId']!.codeUnits, withoutResponse: true);
      
      
      // --- SAVE DEVICEID TO FIREBASE PROFILE ---
      setState(() => _bleStatusMessage = 'Saving device to your profile...');
      try {
        String? userId = FirebaseAuth.instance.currentUser?.uid;
        String deviceId = creds['deviceId']!;
        
        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .set({'deviceId': deviceId}, SetOptions(merge: true));
        } else {
          throw Exception("No user logged in.");
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save device to profile: $e')),
          );
        }
      }
      // --- END OF SAVE ---

      setState(() {
        _isConnectingBLE = false;
        _bleStatusMessage = 'Success! Device is saving...';
      });

      // 6. Show the new reboot dialog
      await _showRebootDialog();
      
      // 7. Disconnect
      await targetDevice.disconnect();

    } catch (e) {
      setState(() {
        _isConnectingBLE = false;
        _bleStatusMessage = 'Error: ${e.toString()}';
      });
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup Failed: ${e.toString()}')),
        );
      }
      targetDevice.disconnect(); // Also disconnect on error
    }
  }

  // --- Helper to show credentials dialog ---
  Future<Map<String, String>?> _showCredentialsDialog() {
    final ssidController = TextEditingController();
    final passController = TextEditingController();
    final deviceIdController = TextEditingController();

    return showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter WiFi Credentials'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: ssidController, decoration: const InputDecoration(labelText: 'WiFi SSID (2.4GHz Only)')),
              TextField(controller: passController, decoration: const InputDecoration(labelText: 'WiFi Password'), obscureText: true),
              TextField(controller: deviceIdController, decoration: const InputDecoration(labelText: 'Device ID (e.g., fridge1)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (ssidController.text.isEmpty || passController.text.isEmpty || deviceIdController.text.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All fields are required.'))
                   );
                } else {
                  Navigator.of(context).pop({
                    'ssid': ssidController.text,
                    'pass': passController.text,
                    'deviceId': deviceIdController.text,
                  });
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  // --- Confirmation Dialog for Forget ---
  Future<void> _confirmForgetDevice(BuildContext context, DeviceProvider provider) async {
    bool? didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forget Device?'),
          content: const Text(
              'This will make the device forget its WiFi settings and reboot.\n\nYou will need to run the Bluetooth setup again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('FORGET', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (didConfirm == true) {
      final snackbar = ScaffoldMessenger.of(context);
      bool success = await provider.forgetWifi();
      if (success) {
        snackbar.showSnackBar(
          const SnackBar(content: Text('Device has been reset and is rebooting into setup mode.')),
        );
      } else {
         snackbar.showSnackBar(
          const SnackBar(content: Text('Failed to reset device. Please try again.')),
        );
      }
    }
  }

  // --- Functions to call provider ---
  void _findOnWiFi(DeviceProvider provider) {
    provider.scanForDevice();
  }

  void _fetchDeviceStatus(DeviceProvider provider) {
    provider.getLdrStatus();
  }

  void _takeSnapshot(DeviceProvider provider) {
    provider.triggerSnapshot();
  }

  void _viewLastVideo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loading last video... (Not Implemented)')),
    );
  }

  // --- Smart Widgets for Offline/Online state ---
  Widget _buildConnectionCard(BuildContext context, DeviceProvider provider, ThemeData theme) {
    if (provider.isDeviceFound) {
      // --- STATE 1: DEVICE IS ONLINE ---
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device Status', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.wifi, color: Colors.green, size: 32),
                title: Text(provider.deviceName, style: theme.textTheme.titleMedium),
                subtitle: Text('Online at ${provider.deviceIp}\nDoor: ${provider.ldrStatus}'),
              ),
              if (provider.isCommunicating)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(),
                ),
              const Divider(height: 20),
              // --- "Forget" Button ---
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.wifi_off),
                  label: const Text('Forget this Device'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withValues()),
                  ),
                  onPressed: provider.isCommunicating 
                    ? null 
                    : () => _confirmForgetDevice(context, provider),
                ),
              )
            ],
          ),
        ),
      );
    } else {
      // --- STATE 2: DEVICE IS OFFLINE ---
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device Offline', style: theme.textTheme.titleLarge?.copyWith(color: Colors.red)),
              const SizedBox(height: 16),
              
              _buildSetupGuide(), // The "How-to" guide
              
              const SizedBox(height: 16),
              
              if (_isConnectingBLE)
                Text(_bleStatusMessage, style: theme.textTheme.bodyMedium),
              if (provider.isScanning)
                const LinearProgressIndicator(),
              if (provider.error != null)
                Text(provider.error!, style: const TextStyle(color: Colors.red)),
                
              const SizedBox(height: 16),

              // --- THE TWO CLEAR BUTTONS ---
              ElevatedButton.icon(
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('1. Start Device Setup (BLE)'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                onPressed: _isConnectingBLE ? null : _startBleSetup,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.wifi_find),
                label: const Text('2. Find Device on WiFi'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                onPressed: provider.isScanning ? null : () => _findOnWiFi(provider),
              ),
            ],
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use Consumer to get data from the provider
    return Consumer<DeviceProvider>(
      builder: (context, provider, child) {
        
        final bool isOnline = provider.isDeviceFound;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // --- This is the new "smart" card ---
                _buildConnectionCard(context, provider, theme),
                
                const SizedBox(height: 20),

                // --- Controls Card (now enabled/disabled by state) ---
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live Controls', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.refresh),
                          title: const Text('Refresh Status'),
                          subtitle: const Text('Get door open/closed state'),
                          enabled: isOnline && !provider.isCommunicating,
                          onTap: () => _fetchDeviceStatus(provider),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.camera_alt_outlined),
                          title: const Text('Take Manual Snapshot'),
                          subtitle: const Text('Request a new photo now'),
                          enabled: isOnline && !provider.isCommunicating,
                          trailing: (provider.isCommunicating && provider.latestSnapshot == null)
                            ? const CircularProgressIndicator()
                            : null,
                          onTap: () => _takeSnapshot(provider),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // --- Snapshot Viewer Card ---
                if (provider.latestSnapshot != null)
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(top: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Latest Snapshot', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 16),
                          Center(
                            child: Image.memory(
                              provider.latestSnapshot!,
                              gaplessPlayback: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // --- Video Log Card ---
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Processing Log', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.videocam_outlined),
                          title: const Text('View Last Processed Video'),
                          subtitle: const Text('See the last recording sent for analysis'),
                          onTap: _viewLastVideo,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}