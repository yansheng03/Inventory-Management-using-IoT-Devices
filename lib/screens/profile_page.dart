import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView(
        children: [
          // -- Profile Header --
          Container(
            padding: const EdgeInsets.all(24),
            color: theme.colorScheme.primary.withAlpha(25),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 60, color: Colors.grey),
                  // backgroundImage: NetworkImage('URL_TO_IMAGE'), // Can add user image later
                ),
                const SizedBox(height: 16),
                Text(
                  'Yan Sheng', // Replace with dynamic user name
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'yansheng@example.com', // Replace with dynamic user email
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),

          // -- Account Section --
          _buildSectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          // -- Settings Section --
          _buildSectionHeader('Settings'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Expiry Notifications'),
            value: true, // TODO: Connect to a state provider
            onChanged: (value) {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          // -- Logout Button --
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TextButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Log Out', style: TextStyle(color: Colors.red)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red.withAlpha(128)),
                ),
              ),
              onPressed: () {},
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
