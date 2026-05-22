import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const DutyIsApp());
}

class DutyIsApp extends StatelessWidget {
  const DutyIsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dutyIs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C6FF7),
          secondary: Color(0xFFE84393),
          surface: Color(0xFF1A1A2E),
          background: Color(0xFF0D0D1A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D1A),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0D0D1A),
          selectedItemColor: Color(0xFF7C6FF7),
          unselectedItemColor: Colors.white38,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFF7C6FF7),
          thumbColor: Color(0xFF7C6FF7),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}