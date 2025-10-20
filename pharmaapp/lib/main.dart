// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'api_service.dart'; // Import ApiService
import 'inventory_list_screen.dart';
import 'login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. We wrap our entire app in a MultiProvider.
    return MultiProvider(
      providers: [
        // 2. The first provider creates our AuthService. It's a ChangeNotifier,
        // so it can notify widgets when the user logs in or out.
        ChangeNotifierProvider(
          create: (ctx) => AuthService(),
        ),
        
        // 3. The second provider is a ProxyProvider. This is a special provider
        // that creates an object that depends on another provider.
        // It creates our ApiService by "proxying" the AuthService to it.
        ProxyProvider<AuthService, ApiService>(
          // The 'update' callback is called whenever AuthService changes.
          // It takes the 'auth' object and provides it to the ApiService constructor.
          update: (ctx, auth, previousApiService) => ApiService(auth),
        ),
      ],
      // 4. The Consumer listens to AuthService to decide which screen to show.
      child: Consumer<AuthService>(
        builder: (ctx, auth, _) => MaterialApp(
          title: 'PharmPal',
          debugShowCheckedModeBanner: false,
          
          // Your existing theme data is unchanged
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light),
            useMaterial3: true,
            // ... etc
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
            useMaterial3: true,
            // ... etc
          ),
          themeMode: ThemeMode.system,
          
          // The logic to switch between screens based on authentication state
          home: auth.isAuthenticated 
              ? const InventoryListScreen() 
              : const LoginScreen(),
        ),
      ),
    );
  }
}