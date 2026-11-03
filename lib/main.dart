import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BoAnhApp());
}

class BoAnhApp extends StatelessWidget {
  const BoAnhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BơAnh',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.butterDark),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

class AppColors {
  static const butter = Color(0xFFB7D98B);
  static const butterDark = Color(0xFF83AD59);
  static const butterLight = Color(0xFFE4F1CE);

  static const cream = Color(0xFFFFF9E9);
  static const background = Color(0xFFF7F9EF);

  static const text = Color(0xFF46533C);

  static const pink = Color(0xFFFFB8C6);
  static const purple = Color(0xFFCBB8F2);
  static const yellow = Color(0xFFFFE58A);
}
