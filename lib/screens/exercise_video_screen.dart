import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/exercise_library.dart';
import '../theme/jinatra_tokens.dart';

/// In-app YouTube view for an exercise's form demonstration.
///
/// When the exercise has a pinned [videoUrl] that URL loads directly;
/// otherwise the catalog's search query is opened on YouTube results. Using a
/// query rather than a baked-in video id means a link can never rot.
class ExerciseVideoScreen extends StatefulWidget {
  final String exerciseName;
  final String videoUrl;

  const ExerciseVideoScreen({
    super.key,
    required this.exerciseName,
    this.videoUrl = '',
  });

  @override
  State<ExerciseVideoScreen> createState() => _ExerciseVideoScreenState();
}

class _ExerciseVideoScreenState extends State<ExerciseVideoScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;

  bool get _isPinned => widget.videoUrl.trim().isNotEmpty;

  String get _targetUrl {
    if (_isPinned) return widget.videoUrl.trim();
    final query = Uri.encodeQueryComponent(
      ExerciseLibrary.queryFor(widget.exerciseName),
    );
    return 'https://m.youtube.com/results?search_query=$query';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(JinatraTokens.sweetCream)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _progress = 100);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _failed = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(_targetUrl));
  }

  void _retry() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    _controller.loadRequest(Uri.parse(_targetUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JinatraTokens.sweetCream,
      appBar: AppBar(
        backgroundColor: JinatraTokens.sweetCream,
        elevation: 0,
        iconTheme: IconThemeData(color: JinatraTokens.ink),
        shape: Border(
          bottom: BorderSide(color: JinatraTokens.ink, width: JinatraTokens.borderControl),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.exerciseName.toUpperCase(),
              style: JinatraTokens.sectionHeader(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _isPinned ? 'PINNED VIDEO' : 'FORM GUIDE',
              style: JinatraTokens.monoData(
                fontSize: 9,
                color: JinatraTokens.ink.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: Icon(Icons.refresh, color: JinatraTokens.ink),
            onPressed: _retry,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100 && !_failed)
            Container(
              height: 6,
              width: double.infinity,
              color: JinatraTokens.mistTeal,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progress / 100,
                child: Container(color: JinatraTokens.signal),
              ),
            ),
          Expanded(
            child: _failed ? _buildOfflineNotice() : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineNotice() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: JinatraTokens.cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 40, color: JinatraTokens.signal),
            const SizedBox(height: 12),
            Text('VIDEO UNAVAILABLE', style: JinatraTokens.sectionHeader(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Form videos stream from YouTube and need a connection. '
              'Your routines, logs and body data stay on-device and work offline.',
              textAlign: TextAlign.center,
              style: JinatraTokens.bodyText(fontSize: 13),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: JinatraTokens.deepTeal,
                  border: Border.all(color: JinatraTokens.ink, width: 3),
                  boxShadow: [JinatraTokens.hardShadow(offset: 3)],
                ),
                child: Text(
                  'RETRY',
                  style: JinatraTokens.monoData(color: JinatraTokens.onPrimary, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
