import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/food_tracker_state.dart';
import 'screens/food_home_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FoodTrackerState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Your Food',
        theme: AppTheme.lightTheme,
        home: const FoodHomePage(),
      ),
    );
  }
}
