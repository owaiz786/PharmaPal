// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'registration_screen.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() { _isLoading = true; });
    try {
      // Use the AuthService to perform the login
      await Provider.of<AuthService>(context, listen: false).login(
        _usernameController.text,
        _passwordController.text,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", "")), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Login to PharmPal')),
    body: Center( // Use Center for better alignment on different screen sizes
      child: SingleChildScrollView( // Prevents overflow if keyboard is open
        padding: const EdgeInsets.all(24.0), // Increased padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- ADD THE LOGO HERE ---
            Image.asset(
              'assets/icon/logo.png',
              height: 150, // Adjust the height as you see fit
            ),
            const SizedBox(height: 48), // Add more space below the logo
            // -------------------------

            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16), // Increased spacing
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Login'),
                  ),
            
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                child: const Text('Don\'t have an account? Register here.'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}