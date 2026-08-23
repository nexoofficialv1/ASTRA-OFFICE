import 'package:flutter/material.dart';
import 'features/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AstraOfficeApp());
}

class AstraOfficeApp extends StatelessWidget {
  const AstraOfficeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF247BFF);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ASTRA OFFICE',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF06152F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF071A38),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
