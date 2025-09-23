
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import './pages/loginpage1.dart';
import './pages/home_page.dart';

final FlutterSecureStorage secureStorage = FlutterSecureStorage();

class LauncherPage extends StatefulWidget {
  const LauncherPage({super.key});

  @override
  State<LauncherPage> createState() => _LauncherPageState();
}

class _LauncherPageState extends State<LauncherPage> {
  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final token = await secureStorage.read(key: 'jwt_token');

    if (token != null && !JwtDecoder.isExpired(token)) {
      // Token exists and is valid
      final decodedToken = JwtDecoder.decode(token);
      final role = decodedToken['role'] ?? 'user';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(role: role)),
      );
    } else {
      // No token or expired → show login page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking token
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

