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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ASTRA OFFICE',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3559E0),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
      ),
      home: const HomeScreen(),
    );
  }
}
