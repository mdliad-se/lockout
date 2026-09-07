import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'theme/app_palette.dart';
import 'theme/jinatra_tokens.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve the saved palette before the first frame so the app never flashes
  // the default cream theme on top of a dark one.
  final savedTheme = await DatabaseService.instance
      .getSetting('theme_key', defaultValue: AppPalette.fallback.key);
  AppPalette.applyKey(savedTheme);

  await NotificationService.instance.init();

  runApp(const LockoutApp());
}

class LockoutApp extends StatelessWidget {
  const LockoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds the whole tree when the palette changes. JinatraTokens reads
    // colours statically, so a rebuild is all that is needed to repaint.
    return ValueListenableBuilder<int>(
      valueListenable: AppPalette.revision,
      // MainScreen must NOT be const here: a const widget is canonicalised to
      // a single instance, so Flutter sees an identical child and skips
      // rebuilding the subtree — leaving the AppBar and BottomNav painted in
      // the old palette while the body repaints. No key either: a changing key
      // would remount the tabs and discard an in-progress live session.
      // ignore: prefer_const_constructors
      builder: (_, _, _) => MaterialApp(
        title: 'LOCKOUT',
        debugShowCheckedModeBanner: false,
        theme: JinatraTokens.materialTheme(),
        home: MainScreen(),
      ),
    );
  }
}
