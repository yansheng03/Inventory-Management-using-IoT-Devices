import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_app/providers/food_tracker_state.dart';
import 'package:capstone_app/providers/theme_provider.dart';
import 'package:capstone_app/screens/food_home_page.dart';
import 'package:capstone_app/screens/login_screen.dart'; 
import 'package:capstone_app/services/firebase_service.dart'; 
import 'package:capstone_app/theme/app_theme.dart';
import 'package:capstone_app/providers/device_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // --- FIX: Robust Initialization ---
  // We try to initialize. If it fails because it already exists (Android/iOS auto-init),
  // we catch the error and continue.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      // Firebase is already initialized, so we are safe to proceed.
      debugPrint("Firebase already initialized: ${e.message}");
    } else {
      // If it's a real error (like missing config), crash so we know.
      rethrow;
    }
  }
  // ----------------------------------

  final firebaseService = FirebaseService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        Provider<FirebaseService>(create: (_) => firebaseService),
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
          title: 'FIT',
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
                return const FoodHomePage(); 
              }
              
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}