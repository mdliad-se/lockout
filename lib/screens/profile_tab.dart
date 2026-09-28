import 'package:flutter/material.dart';

import '../theme/lockout_theme.dart';
import 'settings_screen.dart';

/// Settings hosted as a first-class tab.
///
/// It carries its own header rather than an `AppBar`, so it matches the other
/// tabs: `MainScreen` no longer has a global bar, and a tab that grew one back
/// would sit a bar taller than its neighbours.
class ProfileTab extends StatefulWidget {
  final VoidCallback onSettingsUpdated;

  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart. This tab
  // lives in `MainScreen`'s `IndexedStack` and never unmounts, so a skipped
  // rebuild would strand it in the old theme for the process lifetime.
  // ignore: prefer_const_constructors_in_immutables
  ProfileTab({super.key, required this.onSettingsUpdated});

  @override
  State<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
  final _bodyKey = GlobalKey<SettingsBodyState>();

  Future<void> reload() async => _bodyKey.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LockoutTheme.screenPadding,
                LockoutTheme.spaceMd,
                LockoutTheme.screenPadding,
                LockoutTheme.spaceSm,
              ),
              child: Text('Profile', style: theme.textTheme.headlineMedium),
            ),
            Expanded(
              child: SettingsBody(
                key: _bodyKey,
                onSettingsUpdated: widget.onSettingsUpdated,
                showAppBar: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
