import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    setState(() { _isLoading = true; });
    try {
      await Provider.of<AuthService>(context, listen: false).register(
        _usernameController.text,
        _passwordController.text,
      );
      // If registration is successful, show a success message and pop back to login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful! Please log in.'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
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
    appBar: AppBar(title: const Text('Register for PharmPal')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- ADD THE LOGO HERE ---
            Image.asset(
              'assets/icon/logo.png',
              height: 150, // Use the same height for consistency
            ),
            const SizedBox(height: 48),
            // -------------------------

            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
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
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Register'),
                  ),
          ],
        ),
      ),
    ),
  );
}
}