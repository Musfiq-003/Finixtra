import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Using Android Emulator localhost alias for the API Gateway
  static const String _baseUrl = 'http://10.0.2.2:3000/api/v1/auth';

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'current_device_fingerprint': 'device_simulated_id_001',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('jwt_token', data['token']);
        await prefs.setString('refresh_token', data['refresh_token']);
        await prefs.setString('user_id', data['user_id']);
        
        return true;
      } else {
        // Handle OTP Challenge or Invalid Credentials
        final error = jsonDecode(response.body);
        debugPrint("Login failed: ${error['error']}");
        return false;
      }
    } catch (e) {
      debugPrint("Network error: $e. Falling back to mock login for demo.");
      // MOCK FALLBACK for demonstration on real devices without backend access
      if (email == "demo@finixtra.com" && password == "secure123") {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', 'mock_jwt_token');
        await prefs.setString('user_id', 'mock_user_id');
        return true;
      }
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'device_fingerprint': 'device_simulated_id_001',
        }),
      );

      if (response.statusCode == 201) {
        return await login(email, password); // Auto-login after registration
      }
      return false;
    } catch (e) {
      debugPrint("Network error: $e");
      return false;
    }
  }
}
