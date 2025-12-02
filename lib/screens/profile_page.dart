// lib/screens/profile_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_app/providers/theme_provider.dart';
import 'package:capstone_app/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Future<void> _showEditProfileDialog(FirebaseService service, User user) async {
    final TextEditingController nameController = TextEditingController(text: user.displayName);
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Profile"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Display Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await service.updateDisplayName(nameController.text.trim());
                
                // --- FIX 1: Check ctx.mounted before using ctx ---
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                // --- FIX 2: Check mounted (this class) before using context/setState ---
                if (mounted) {
                  _showSnackBar("Profile updated successfully");
                  setState(() {}); 
                }
              } catch (e) {
                // --- FIX 3: Check ctx.mounted here too ---
                if (ctx.mounted) {
                   Navigator.of(ctx).pop();
                }
                if (mounted) {
                   _showSnackBar("Failed to update profile: $e", isError: true);
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(FirebaseService service) async {
    final TextEditingController passwordController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Change Password"),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: "New Password"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPass = passwordController.text.trim();
              if (newPass.length < 6) {
                 _showSnackBar("Password must be at least 6 characters", isError: true);
                 return;
              }

              try {
                await service.updatePassword(newPass);
                
                // --- FIX 4: Check ctx.mounted ---
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  _showSnackBar("Password updated! Please login again.");
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  _showSnackBar("Error: ${e.toString()}", isError: true);
                }
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final user = firebaseService.currentUser;

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
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null 
                      ? const Icon(Icons.person, size: 60, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? 'No Name', 
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  user?.email ?? 'No Email', 
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
            onTap: () {
              if (user != null) _showEditProfileDialog(firebaseService, user);
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
               _showChangePasswordDialog(firebaseService);
            },
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
          
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
               showAboutDialog(
                 context: context, 
                 applicationName: "FIT",
                 applicationVersion: "1.0.0",
               );
            },
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
              onPressed: () {
                firebaseService.logout();
              },
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