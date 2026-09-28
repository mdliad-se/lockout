import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/bottom_nav.dart';
import 'food_tab.dart';
import 'profile_tab.dart';
import 'progress_tab.dart';
import 'routines_tab.dart';
import 'today_tab.dart';

class MainScreen extends StatefulWidget {
  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart. Here the
  // palette is read by the AppBar and BottomNav this screen builds, not by
  // the screen itself; canonicalising it strands them just the same.
  // ignore: prefer_const_constructors_in_immutables
  MainScreen({super.key});

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
  final _progressKey = GlobalKey<ProgressTabState>();
  final _profileKey = GlobalKey<ProfileTabState>();

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
        NavTab.workout => RoutinesTab(
            key: _routinesKey,
            onStartToday: _startTodaySession,
          ),
        NavTab.progress => ProgressTab(key: _progressKey),
        NavTab.food => FoodTab(key: _foodKey),
        NavTab.profile => ProfileTab(
            key: _profileKey,
            onSettingsUpdated: _loadSettings,
          ),
      };

  void _refreshVisibleTab() {
    if (_currentIndex >= _tabIds.length) return;
    switch (_tabIds[_currentIndex]) {
      case 'home':
        _todayKey.currentState?.reload();
      case 'workout':
        _routinesKey.currentState?.reload();
      case 'progress':
        _progressKey.currentState?.reload();
      case 'food':
        _foodKey.currentState?.reload();
      case 'profile':
        _profileKey.currentState?.reload();
    }
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    // Pull fresh data after the frame so the new tab is mounted first.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshVisibleTab());
  }

  /// Lets HOME's action grid switch tabs by id. Ids rather than indices,
  /// because hiding the Food tab shifts every index after it.
  ///
  /// [segment] is honoured only for `'progress'`, the one tab with two
  /// destinations behind a single id: Home's "Weigh in" and "History" actions
  /// both land there and must not open the same half. Applied after the frame
  /// so the tab is mounted and its `GlobalKey` resolves.
  void _goToTab(String tabId, {ProgressSegment? segment}) {
    final index = _tabIds.indexOf(tabId);
    if (index < 0) return;
    _onTabTapped(index);
    if (tabId == 'progress' && segment != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _progressKey.currentState?.showSegment(segment),
      );
    }
  }

  /// Starts today's session from the Workout tab's featured-day card.
  ///
  /// The session engine lives in `TodayTab`, so this switches to Home and
  /// hands off rather than keeping a second copy of the start logic. The
  /// post-frame callback is what makes the hand-off safe: the tab must be
  /// mounted before its `GlobalKey` resolves.
  void _startTodaySession() {
    _goToTab('home');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _todayKey.currentState?.startScheduledSession(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    if (!_settingsLoaded) {
      return Scaffold(
        backgroundColor: surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final screens = _screens;
    if (_currentIndex >= screens.length) _currentIndex = 0;

    // No global AppBar. Each tab owns its own large title, which is what lets
    // Home read as a dashboard rather than a page inside a chrome; settings
    // moved from the old gear icon here into the Profile tab.
    return Scaffold(
      backgroundColor: surface,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        foodTabEnabled: _foodTabEnabled,
        onTap: _onTabTapped,
      ),
    );
  }
}
