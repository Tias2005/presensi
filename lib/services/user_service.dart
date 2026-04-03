import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class UserService {
  static Future<void> refreshUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return;

      final res = await http.get(
        Uri.parse("${AppConfig.apiUrl}/user/me"),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await prefs.setString('user_data', jsonEncode(data['user']));
      }
    } catch (e) {
      // print("Refresh user error: $e");
    }
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user_data');

    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }
}