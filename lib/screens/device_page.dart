// lib/screens/device_page.dart
import 'dart:typed_data'; // For image data
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart'; // <-- Import new provider
import '../providers/food_tracker_state.dart'; // <-- Import food state

class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  // --- NEW: Helper to show snapshot dialog ---
  void _showSnapshotDialog(BuildContext context, Uint8List imageData) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Snapshot Result'),
          content: Image.memory(imageData), // Display the image
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
  // --- END NEW ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Use Consumer to react to changes in DeviceProvider
    return Consumer<DeviceProvider>(
      builder: (context, device, child) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(
                'Connected Devices',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Use the dynamic device card
              _buildDeviceCard(context, device),
              const SizedBox(height: 24),
              Text(
                'Actions',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Trigger Snapshot'),
                subtitle: const Text('Force a new scan and show image'),
                // Disable if no device or already communicating
                enabled: device.isDeviceFound && !device.isCommunicating,
                onTap: () async {
                  bool success = await device.triggerSnapshot();
                  if (success && context.mounted) {
                    // Show the image
                    if (device.latestSnapshot != null) {
                      _showSnapshotDialog(context, device.latestSnapshot!);
                    }
                    // Also refresh inventory list
                    context.read<FoodTrackerState>().fetchInventory();
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(device.error ?? 'Failed to get snapshot')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Device Information'),
                subtitle: const Text('View IP address and status'),
                enabled: device.isDeviceFound,
                onTap: () {
                   _showDeviceInfo(context, device);
                },
              ),
              // Show communication errors
              if (device.error != null && !device.isCommunicating)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Error: ${device.error!}',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              // Show spinner while communicating
              if (device.isCommunicating)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            // Change FAB to scan button
            onPressed: device.isScanning ? null : () {
              device.scanForDevice();
            },
            label: Text(device.isScanning ? 'Scanning...' : 'Scan for Device'),
            icon: device.isScanning 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Icon(Icons.search),
          ),
        );
      },
    );
  }

  // Updated to use dynamic data from the provider
  Widget _buildDeviceCard(BuildContext context, DeviceProvider device) {
    final theme = Theme.of(context);
    
    // Show a different card if no device is found
    if (!device.isDeviceFound) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.wifi_off, size: 40, color: Colors.grey.shade600),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Device Found',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Tap "Scan for Device" to connect',
                      style: TextStyle(color: Colors.grey.shade700)
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // This card shows when a device is found
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.kitchen, size: 40, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceName, // Use dynamic name
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Online', style: TextStyle(color: Colors.green.shade700)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  // Disable button while communicating
                  onPressed: device.isCommunicating ? null : () {
                    device.getLdrStatus();
                  },
                )
              ],
            ),
            const Divider(height: 32),
            Text('IP Address: ${device.deviceIp}', style: const TextStyle(color: Colors.grey)),
            Text('LDR Status: ${device.ldrStatus}', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // New helper to show device info
  void _showDeviceInfo(BuildContext context, DeviceProvider device) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${device.deviceName}'),
            Text('IP Address: ${device.deviceIp}'),
            Text('LDR Status: ${device.ldrStatus}'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}