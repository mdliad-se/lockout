import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'screens/main_screen.dart';
import 'services/notification_service.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve the saved appearance before the first frame so the app never
  // flashes the default theme on top of the chosen one.
  await ThemeController.instance.load();

  await NotificationService.instance.init();

  runApp(const LockoutApp());
}

class LockoutApp extends StatelessWidget {
  const LockoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Published after the frame rather than inline: this builder runs
        // during build, and notifying listeners there would rebuild an
        // ancestor mid-build. The controller no-ops when nothing actually
        // changed, so this cannot loop even though the builder fires often.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ThemeController.instance.setDynamicSchemes(
            light: lightDynamic,
            dark: darkDynamic,
          );
        });

        return ListenableBuilder(
          listenable: ThemeController.instance,
          // MainScreen is written without `const` only because its
          // constructor is not const. It is not a theme requirement: see the
          // note at the top of `widgets/day_block.dart`, which works through
          // why a const child cannot be stranded in the old theme (anything
          // reading `Theme.of(context)` is rebuilt through its
          // `InheritedWidget` dependency, not through its parent) and names
          // this call site as one that could be const today. No key either:
          // a changing key would remount the tabs and discard an in-progress
          // live session.
          builder: (_, _) => MaterialApp(
            title: 'LOCKOUT',
            debugShowCheckedModeBanner: false,
            theme: ThemeController.instance.lightTheme,
            darkTheme: ThemeController.instance.darkTheme,
            themeMode: ThemeController.instance.themeMode,
            home: MainScreen(),
          ),
        );
      },
    );
  }
}
