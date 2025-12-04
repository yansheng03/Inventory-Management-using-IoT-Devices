// lib/screens/profile_page.dart

import 'dart:async';
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
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  _showSnackBar("Profile updated successfully");
                  setState(() {}); 
                }
              } catch (e) {
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) _showSnackBar("Failed to update profile", isError: true);
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
                 if (mounted) _showSnackBar("Password must be at least 6 characters", isError: true);
                 return;
              }
              try {
                await service.updatePassword(newPass);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) _showSnackBar("Password updated! Please login again.");
              } catch (e) {
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) _showSnackBar("Error updating password", isError: true);
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _showCustomAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Text("FIT 1.0.0", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "OUR MISSION",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              _buildValueItem(
                "Prevent Food Waste", 
                "Every year, millions of tons of food go to waste. FIT helps you track expiry and freshness, ensuring you use what you buy before it's too late.",
              ),
              _buildValueItem(
                "Save Money", 
                "Stop throwing cash in the bin. By managing your inventory efficiently, you avoid overbuying and get the most value out of your grocery budget.",
              ),
              _buildValueItem(
                "Smart Living", 
                "Automate your kitchen with AI. Spend less time checking what's in the fridge and more time creating delicious meals with ingredients you already have.",
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                "TERMS AND CONDITIONS",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                "1. Acceptance of Terms\nBy accessing and using the FIT app, you accept and agree to be bound by the terms and provision of this agreement.\n\n"
                "2. AI Accuracy Disclaimer\nFIT uses artificial intelligence to identify food items. While we strive for high accuracy, errors may occur. Users should verify inventory lists manually.\n\n"
                "3. Data Usage\nImages uploaded for analysis are processed securely. We do not share your personal data with third parties without consent.\n\n"
                "4. Food Safety\nFIT tracks inventory dates but is not responsible for food spoilage or safety. Always check your food quality before consumption.",
                style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              showLicensePage(context: context, applicationName: "FIT", applicationVersion: "1.0.0");
            },
            child: const Text("Licenses"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // --- Uses the stateful delete dialog ---
  void _showDeleteAccountDialog(FirebaseService service) {
    showDialog(
      context: context,
      barrierDismissible: false, // Forces user to wait or press cancel
      builder: (ctx) => _DeleteAccountDialog(service: service),
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
            onTap: () => _showCustomAboutDialog(),
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

          // DELETE BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 40.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: const Text("Delete Account"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700, // Explicitly Red
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _showDeleteAccountDialog(firebaseService),
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

  Widget _buildValueItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// Delete Dialog with Timer ---
class _DeleteAccountDialog extends StatefulWidget {
  final FirebaseService service;
  const _DeleteAccountDialog({required this.service});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  int _secondsRemaining = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start the countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only enable if timer hits 0
    final bool canDelete = _secondsRemaining == 0;

    return AlertDialog(
      title: const Text("Delete Account"),
      content: const Text(
        "Are you sure you want to delete your account? This action is permanent and cannot be undone. All your data will be lost immediately.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: canDelete
              ? () async {
                  // Perform Delete
                  Navigator.of(context).pop(); 
                  try {
                    await widget.service.deleteAccount();
                  } catch (e) {
                    final msg = e.toString().replaceAll("Exception: ", "");
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text(msg), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              : null, // Disabled when timer > 0
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.red.withAlpha(100),
            disabledForegroundColor: Colors.white70,
          ),
          child: Text(
            canDelete 
              ? "Delete Forever" 
              : "Wait ${_secondsRemaining}s",
          ),
        ),
      ],
    );
  }
}