import 'package:flutter/material.dart';
import 'theme/jinatra_tokens.dart';
import 'screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LockoutApp());
}

class LockoutApp extends StatelessWidget {
  const LockoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LOCKOUT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: JinatraTokens.sweetCream,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: JinatraTokens.deepTeal,
          primary: JinatraTokens.deepTeal,
          secondary: JinatraTokens.signal,
          surface: JinatraTokens.sweetCream,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
