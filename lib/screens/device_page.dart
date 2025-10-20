import 'package:flutter/material.dart';

class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          _buildDeviceCard(context),
          const SizedBox(height: 24),
          Text(
            'Actions',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync Manually'),
            subtitle: const Text('Force a new scan of your fridge'),
            onTap: () {
              // TODO: Implement manual sync logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Manual sync triggered! (Not implemented)')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Device Information'),
            subtitle: const Text('View firmware version and other details'),
            onTap: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement device pairing flow
        },
        label: const Text('Add Device'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context) {
    final theme = Theme.of(context);
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
                        'Smart Fridge Monitor',
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
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  onPressed: () {},
                )
              ],
            ),
            const Divider(height: 32),
            const Text('ID: FRIDGE-A8B4-C1D9', style: TextStyle(color: Colors.grey)),
            const Text('Last Sync: Just now', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
