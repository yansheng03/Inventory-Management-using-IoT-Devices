// lib/screens/device_page.dart

import 'package:flutter/material.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  // --- State Variables ---
  bool _isConnecting = false;
  String _deviceStatus = 'Offline'; // e.g., 'Offline', 'Online', 'Door Open'
  // String _lastVideoUrl = ''; // <-- FIX: REMOVED THIS UNUSED VARIABLE
  bool _isTakingSnapshot = false;

  // --- Methods ---

  // TODO: Implement BLE connection logic
  void _connectToDevice() {
    setState(() => _isConnecting = true);
    // Simulating connection delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isConnecting = false;
        _deviceStatus = 'Online (Door Closed)';
      });
    });
  }

  // TODO: Implement HTTP request to Arduino /status
  void _fetchDeviceStatus() {
    // This would be an http.get('http://inventory-fridge.local/status')
    // For now, we'll simulate a door open/close
    setState(() {
      if (_deviceStatus.contains('Closed')) {
        _deviceStatus = 'Online (Door Open)';
      } else {
        _deviceStatus = 'Online (Door Closed)';
      }
    });
  }

  // TODO: Implement HTTP request to Arduino /snapshot
  void _takeSnapshot() {
    setState(() => _isTakingSnapshot = true);
    // This would be an http.post('http://inventory-fridge.local/snapshot')
    // Simulating a delay for the snapshot
    Future.delayed(const Duration(seconds: 3), () {
      setState(() => _isTakingSnapshot = false);
      // Show a snackbar on success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Snapshot taken! (Simulated)')),
      );
    });
  }

  // TODO: Implement logic to get last video from Firebase Storage
  void _viewLastVideo() {
    // This would query Firebase Storage for the latest video
    // and then open it, e.g., using a video_player package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loading last video... (Simulated)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // --- Connection Card ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device Connection',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: _deviceStatus == 'Offline'
                                  ? Colors.red
                                  : Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(_deviceStatus,
                                style: theme.textTheme.bodyLarge),
                          ],
                        ),
                        ElevatedButton(
                          // Disable button if not offline
                          onPressed: _deviceStatus == 'Offline' ? _connectToDevice : null,
                          child: _isConnecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Connect'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // --- Controls Card ---
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
                      onTap: _fetchDeviceStatus,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.camera_alt_outlined),
                      title: const Text('Take Manual Snapshot'),
                      subtitle: const Text('Request a new photo now'),
                      trailing: _isTakingSnapshot 
                        ? const CircularProgressIndicator()
                        : null,
                      onTap: _isTakingSnapshot ? null : _takeSnapshot,
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
                    // TODO: Could add a ListView.builder here
                    // to show a list of recent videos from Firebase Storage
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}