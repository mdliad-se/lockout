import 'package:flutter/material.dart';
import '../theme/jinatra_tokens.dart';
import '../services/database_service.dart';
import '../widgets/bottom_nav.dart';
import 'routines_tab.dart';
import 'today_tab.dart';
import 'food_tab.dart';
import 'body_tab.dart';
import 'log_tab.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _foodTabEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabledStr = await DatabaseService.instance.getSetting('food_tab_enabled', defaultValue: 'true');
    setState(() {
      _foodTabEnabled = enabledStr == 'true';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic screens list based on settings
    final List<Widget> screens = [
      const RoutinesTab(),
      const TodayTab(),
      if (_foodTabEnabled) const FoodTab(),
      const BodyTab(),
      const LogTab(),
    ];

    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      appBar: AppBar(
        backgroundColor: JinatraTokens.sweetCream,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: JinatraTokens.deepTeal,
                border: Border.all(color: JinatraTokens.ink, width: 2),
              ),
              child: Text(
                'lockout',
                style: JinatraTokens.monoData(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'JINATRA v1.1',
              style: JinatraTokens.monoData(fontSize: 10, color: JinatraTokens.ink.withOpacity(0.7)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: JinatraTokens.ink),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => SettingsScreen(onSettingsUpdated: _loadSettings),
                ),
              );
            },
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        foodTabEnabled: _foodTabEnabled,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
