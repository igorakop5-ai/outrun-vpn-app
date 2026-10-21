import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'theme/outrun_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set status bar and system navigation bar colors
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: OutrunTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const OutrunVpnApp());
}

class OutrunVpnApp extends StatelessWidget {
  const OutrunVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OutrunVPN',
      debugShowCheckedModeBanner: false,
      theme: OutrunTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
