import 'package:flutter/material.dart';

import '../theme/lockout_theme.dart';
import 'body_tab.dart';
import 'log_tab.dart';

/// Which half of Progress is on screen.
enum ProgressSegment { weight, history }

/// Hosts the two progress views behind one segmented control.
///
/// Only the visible segment is mounted. Both children load from sqflite in
/// `initState`, so keeping the hidden one alive would double every read on a
/// view the user may never open. The cost is that switching re-reads — which
/// is the right trade here, because the other segment's data may well have
/// changed while it was hidden (a session logged, a weight entered).
class ProgressTab extends StatefulWidget {
  final ProgressSegment initialSegment;

  // NOT const — this screen's children read colour from the theme, and a
  // canonicalised instance is skipped on rebuild, stranding them in the
  // previous theme after a switch.
  // ignore: prefer_const_constructors_in_immutables
  ProgressTab({super.key, this.initialSegment = ProgressSegment.weight});

  @override
  State<ProgressTab> createState() => ProgressTabState();
}

class ProgressTabState extends State<ProgressTab> {
  late ProgressSegment _segment = widget.initialSegment;

  final _bodyKey = GlobalKey<BodyTabState>();
  final _logKey = GlobalKey<LogTabState>();

  /// Refreshes whichever segment is visible.
  ///
  /// The hidden one is not mounted, so there is nothing to refresh there — it
  /// reads fresh on the way in.
  Future<void> reload() async {
    switch (_segment) {
      case ProgressSegment.weight:
        await _bodyKey.currentState?.reload();
      case ProgressSegment.history:
        await _logKey.currentState?.reload();
    }
  }

  /// Switches segment from outside — `MainScreen` uses this so Home's
  /// "Weigh in" and "History" actions land on different halves of one tab.
  void showSegment(ProgressSegment segment) {
    if (!mounted || segment == _segment) return;
    setState(() => _segment = segment);
  }

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
              child: Text('Progress', style: theme.textTheme.headlineMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LockoutTheme.screenPadding,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ProgressSegment>(
                  segments: const [
                    ButtonSegment(
                      value: ProgressSegment.weight,
                      label: Text('Weight'),
                      icon: Icon(Icons.monitor_weight_outlined),
                    ),
                    ButtonSegment(
                      value: ProgressSegment.history,
                      label: Text('History'),
                      icon: Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                  selected: {_segment},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      showSegment(selection.first),
                ),
              ),
            ),
            const SizedBox(height: LockoutTheme.spaceMd),
            Expanded(
              child: switch (_segment) {
                ProgressSegment.weight => BodyTab(key: _bodyKey),
                ProgressSegment.history => LogTab(key: _logKey),
              },
            ),
          ],
        ),
      ),
    );
  }
}
