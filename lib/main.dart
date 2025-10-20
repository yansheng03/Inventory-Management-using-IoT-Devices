import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/food_tracker_state.dart';
import 'providers/theme_provider.dart'; // <-- Import ThemeProvider
import 'screens/food_home_page.dart';
import 'theme/app_theme.dart';

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
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // <-- Add ThemeProvider
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Your Food',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme, // <-- Add dark theme
            themeMode: themeProvider.currentTheme, // <-- Control theme mode
            home: const FoodHomePage(),
          );
        },
      ),
    );
  }
}
