// lib/screens/device_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_app/providers/device_provider.dart';
import 'package:capstone_app/screens/ble_setup_page.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {

  Future<void> _confirmForgetDevice(BuildContext context, DeviceProvider provider) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Factory Reset Device?'),
        content: const Text('This will wipe WiFi credentials from the camera and reboot it into Setup Mode.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await provider.forgetWifi();
    }
  }

  // Helper for the Guide
  Widget _buildGuideStep(String step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.blue.shade100, shape: BoxShape.circle),
            child: Text(step, style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => provider.scanForDevice(),
            child: ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                // --- Status Card ---
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        provider.isDeviceFound ? Icons.check_circle_rounded : Icons.wifi_off_rounded,
                        color: provider.isDeviceFound ? Colors.green : Colors.grey,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        provider.isDeviceFound ? provider.deviceName : 'Device Offline',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        provider.isDeviceFound ? "IP: ${provider.deviceIp}" : "Scan to find your camera",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (provider.error != null)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text(provider.error!, style: TextStyle(color: Colors.red.shade700), textAlign: TextAlign.center),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- Buttons or Connected UI ---
                if (!provider.isDeviceFound) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('1. Set Up New Device'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BleSetupPage())),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('2. Find on WiFi'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: provider.isScanning ? null : () => provider.scanForDevice(),
                  ),
                  
                  const SizedBox(height: 40),
                  const Text("SETUP INSTRUCTIONS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 20),
                  
                  // --- DETAILED GUIDE ---
                  _buildGuideStep("1", "Power On", "Plug in the ESP32-CAM. If it was previously set up, you may need to reset it first."),
                  _buildGuideStep("2", "Connect via BLE", "Tap 'Set Up New Device'. The app will scan for the camera via Bluetooth."),
                  _buildGuideStep("3", "Send WiFi Info", "Enter your home WiFi credentials. The camera will save them and restart automatically."),
                  _buildGuideStep("4", "Control", "Once the camera restarts (solid flash or LED), tap 'Find on WiFi' to start using it."),

                ] else ...[
                  // --- Connected Controls ---
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Live Snapshot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: provider.isCommunicating ? null : () => provider.triggerSnapshot(),
                  ),
                  
                  // Snapshot Display
                  if (provider.latestSnapshot != null)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Image.memory(
                        provider.latestSnapshot!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),

                  const SizedBox(height: 24),
                  
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Factory Reset Device'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _confirmForgetDevice(context, provider),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}