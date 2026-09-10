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
  bool _settingsLoaded = false;

  // Tabs live inside an IndexedStack so an in-progress live session survives a
  // trip to another tab. Keys let us refresh a tab on the way back in, since
  // its initState no longer re-runs on every switch.
  final _routinesKey = GlobalKey<RoutinesTabState>();
  final _todayKey = GlobalKey<TodayTabState>();
  final _foodKey = GlobalKey<FoodTabState>();
  final _bodyKey = GlobalKey<BodyTabState>();
  final _logKey = GlobalKey<LogTabState>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabledStr = await DatabaseService.instance
        .getSetting('food_tab_enabled', defaultValue: 'true');
    if (!mounted) return;
    setState(() {
      _foodTabEnabled = enabledStr == 'true';
      _settingsLoaded = true;
    });
    _refreshVisibleTab();
  }

  /// `BottomNav.visibleTabs` is the single source of truth for order and
  /// visibility; `_screens` and `_tabIds` are both derived from it so they
  /// cannot silently drift apart from what the nav bar actually shows.
  List<String> get _tabIds => BottomNav.visibleTabs(foodTabEnabled: _foodTabEnabled)
      .map((t) => t.id)
      .toList();

  List<Widget> get _screens =>
      BottomNav.visibleTabs(foodTabEnabled: _foodTabEnabled)
          .map((t) => _screenFor(t.tab))
          .toList();

  /// A switch *expression* over the `NavTab` enum: the compiler rejects this
  /// if a case is missing, so a tab added to `BottomNav._allTabs` without a
  /// matching branch here is a compile error rather than the runtime
  /// `StateError` a `String`-keyed switch could only catch with a
  /// remembered `default`.
  Widget _screenFor(NavTab tab) => switch (tab) {
        NavTab.home => TodayTab(
            key: _todayKey,
            onNavigate: _goToTab,
            foodTabEnabled: _foodTabEnabled,
          ),
        NavTab.routines => RoutinesTab(key: _routinesKey),
        NavTab.food => FoodTab(key: _foodKey),
        NavTab.body => BodyTab(key: _bodyKey),
        NavTab.log => LogTab(key: _logKey),
      };

  void _refreshVisibleTab() {
    if (_currentIndex >= _tabIds.length) return;
    switch (_tabIds[_currentIndex]) {
      case 'home':
        _todayKey.currentState?.reload();
        break;
      case 'routines':
        _routinesKey.currentState?.reload();
        break;
      case 'food':
        _foodKey.currentState?.reload();
        break;
      case 'body':
        _bodyKey.currentState?.reload();
        break;
      case 'log':
        _logKey.currentState?.reload();
        break;
    }
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    // Pull fresh data after the frame so the new tab is mounted first.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshVisibleTab());
  }

  /// Lets HOME's action grid switch tabs by id. Ids rather than indices,
  /// because hiding the Food tab shifts every index after it.
  void _goToTab(String tabId) {
    final index = _tabIds.indexOf(tabId);
    if (index < 0) return;
    _onTabTapped(index);
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return Scaffold(
        backgroundColor: JinatraTokens.sweetCream,
        body: Center(child: CircularProgressIndicator(color: JinatraTokens.deepTeal)),
      );
    }

    final screens = _screens;
    if (_currentIndex >= screens.length) _currentIndex = 0;

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
                  color: JinatraTokens.onPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'JINATRA v1.1',
              style: JinatraTokens.monoData(
                fontSize: 10,
                color: JinatraTokens.ink.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: JinatraTokens.ink),
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
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        foodTabEnabled: _foodTabEnabled,
        onTap: _onTabTapped,
      ),
    );
  }
}
