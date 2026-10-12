import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/firebase_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CoopConnectApp());
}

class CoopConnectApp extends StatelessWidget {
  const CoopConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: FirebaseService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'CoopConnect Mobile',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        );
      },
    );
  }
}
