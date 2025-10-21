// lib/screens/auth_loading_page.dart
import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import 'food_home_page.dart';
import 'login_page.dart';

class AuthLoadingPage extends StatefulWidget {
  const AuthLoadingPage({super.key});

  @override
  State<AuthLoadingPage> createState() => _AuthLoadingPageState();
}

class _AuthLoadingPageState extends State<AuthLoadingPage> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Wait a frame to ensure context is available
    await Future.delayed(Duration.zero);
    
    final pbService = PocketBaseService(); // Use singleton
    final bool loggedIn = await pbService.isLoggedIn();

    if (!mounted) return; // Check if the widget is still in the tree

    if (loggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const FoodHomePage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}