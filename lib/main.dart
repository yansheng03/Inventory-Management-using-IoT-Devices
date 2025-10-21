// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/device_provider.dart'; // <-- IMPORT NEW
import 'providers/food_tracker_state.dart';
import 'providers/theme_provider.dart'; 
import 'screens/auth_loading_page.dart'; // <-- IMPORT NEW
import 'theme/app_theme.dart';
// import 'screens/food_home_page.dart'; // <-- No longer needed here

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use MultiProvider to handle multiple states
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FoodTrackerState()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()), // <-- ADD THIS
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Your Food',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.currentTheme,
            home: const AuthLoadingPage(), // <-- UPDATED
          );
        },
      ),
    );
  }
}