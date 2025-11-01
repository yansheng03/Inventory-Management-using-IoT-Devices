// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_app/providers/food_tracker_state.dart';
import 'package:capstone_app/providers/theme_provider.dart';
import 'package:capstone_app/screens/food_home_page.dart';
import 'package:capstone_app/screens/login_screen.dart'; 
import 'package:capstone_app/services/firebase_service.dart'; 
import 'package:capstone_app/theme/app_theme.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final firebaseService = FirebaseService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<FirebaseService>(
          create: (_) => firebaseService,
        ),
        ChangeNotifierProvider(
          create: (context) => FoodTrackerState(
            context.read<FirebaseService>(),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Your Food',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.currentTheme,
          
          home: StreamBuilder<User?>(
            stream: context.read<FirebaseService>().authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (snapshot.hasData) {
                // USER IS LOGGED IN
                
                // context.read<FoodTrackerState>().initialize(); // <-- THIS LINE IS REMOVED
                
                return const FoodHomePage();
              }
              
              // USER IS LOGGED OUT
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}