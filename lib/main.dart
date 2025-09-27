import 'package:flutter/material.dart';
import 'splash_screen.dart';

void main() {
  runApp(const MirrorDashApp());
}

class MirrorDashApp extends StatelessWidget {
  const MirrorDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tapnnis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashScreen(),
    );
  }
}
