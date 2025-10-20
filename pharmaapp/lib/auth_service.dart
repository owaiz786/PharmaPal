import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService extends ChangeNotifier {
  // Use the same base URL as your ApiService
  static const String _baseUrl = "http://10.113.175.122:8000"; 
  final _storage = const FlutterSecureStorage();

  String? _token;
  String? get token => _token;

  bool get isAuthenticated => _token != null;

  AuthService() {
    _tryAutoLogin();
  }



  // Check for a saved token when the app starts
  Future<void> _tryAutoLogin() async {
    _token = await _storage.read(key: 'auth_token');
    notifyListeners(); // Notify widgets that the auth state has changed
  }

  Future<void> login(String username, String password) async {
    final url = Uri.parse('$_baseUrl/token');
    
    // The login endpoint expects form data, not JSON
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': username, 'password': password},
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      _token = responseData['access_token'];
      
      // Store the token securely
      await _storage.write(key: 'auth_token', value: _token);
      
      notifyListeners();
    } else {
      // Handle login errors
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to log in.');
    }
  }

  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: 'auth_token');
    notifyListeners();
  }
  Future<void> register(String username, String password) async {
    final url = Uri.parse('$_baseUrl/register');
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      // The register endpoint expects JSON, not form data
      body: json.encode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      // If registration is successful, you could automatically log the user in
      // or simply show a success message and let them log in manually.
      // For simplicity, we'll just let them log in.
      return;
    } else {
      // Handle registration errors (like "username already exists")
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to register.');
    }
  }
}