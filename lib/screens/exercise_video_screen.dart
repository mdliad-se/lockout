import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/exercise_library.dart';
import '../theme/jinatra_tokens.dart';

/// Schemes the in-app webview will actually load. `javascript:` and
/// `file:` both parse and both answer `hasScheme`, so promoting on that
/// alone would hand them to the platform.
const _loadableSchemes = {'http', 'https'};

/// What a promoted host has to look like before the leading `https://` is
/// assumed: dot-separated labels of letters, digits and hyphens. Without
/// this, `Uri.tryParse('https://watch a video')` succeeds — it percent-
/// encodes the spaces into a host — and a sentence the user typed into the
/// URL field would be handed to the webview as an address.
final _hostShape = RegExp(r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$');

/// The URL to open for a user-pinned video link, or `null` when [raw] holds
/// nothing loadable.
///
/// A top-level function rather than a private method so it can be tested
/// without a WebView platform implementation, which `flutter test` does not
/// provide.
///
/// `webview_flutter_android` validates a request synchronously and throws
/// `ArgumentError: WebViewRequest#uri is required to have a scheme.`
/// Because `initState` is not async, that error used to propagate straight
/// out of it and turn the route into a red error screen — and
/// `Uri.parse('youtube.com/watch?v=x').hasScheme` is `false`, so simply
/// pasting a link without `https://` was enough to trigger it. Prefixing
/// the scheme and re-parsing (rather than rebuilding the Uri field by
/// field) keeps the path, query and fragment of a share link intact.
Uri? pinnedVideoUri(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final asWritten = Uri.tryParse(text);
  if (asWritten != null && asWritten.hasScheme) {
    if (!_loadableSchemes.contains(asWritten.scheme)) return null;
    return asWritten.host.isEmpty ? null : asWritten;
  }

  final promoted = Uri.tryParse('https://$text');
  if (promoted == null || !_hostShape.hasMatch(promoted.host)) return null;
  return promoted;
}

/// The YouTube results page for [exerciseName]'s form query — the unpinned
/// case. A query rather than a baked-in video id means a link cannot rot.
Uri searchVideoUri(String exerciseName) => Uri.parse(
      'https://m.youtube.com/results?search_query='
      '${Uri.encodeQueryComponent(ExerciseLibrary.queryFor(exerciseName))}',
    );

/// In-app YouTube view for an exercise's form demonstration.
///
/// When the exercise has a pinned [videoUrl] that URL loads directly, once
/// [pinnedVideoUri] has made something loadable of it; otherwise the
/// catalog's search query is opened on YouTube results. A link that cannot
/// be normalised at all is a message on screen, never an exception.
class ExerciseVideoScreen extends StatefulWidget {
  final String exerciseName;
  final String videoUrl;

  // NOT const - see `SectionHeading` in lib/widgets/day_block.dart.
  // ignore: prefer_const_constructors_in_immutables
  ExerciseVideoScreen({
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

  /// Resolved once, in [initState]. `null` means the pinned link could not
  /// be made into anything the webview can load, which is a message on
  /// screen rather than an exception out of `initState`.
  Uri? _target;

  @override
  void initState() {
    super.initState();
    _target = _isPinned
        ? pinnedVideoUri(widget.videoUrl)
        : searchVideoUri(widget.exerciseName);
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
      );

    final target = _target;
    // Guarded rather than unconditional: `loadRequest` rejects a
    // schemeless URI synchronously, and nothing here is async, so an
    // unusable pinned link would take the whole route down.
    if (target != null) _controller.loadRequest(target);
  }

  void _retry() {
    final target = _target;
    if (target == null) return;
    setState(() {
      _failed = false;
      _progress = 0;
    });
    _controller.loadRequest(target);
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
          if (_target != null)
            IconButton(
              tooltip: 'Reload',
              icon: Icon(Icons.refresh, color: JinatraTokens.ink),
              onPressed: _retry,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100 && !_failed && _target != null)
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
            child: _target == null
                ? _buildUnusableLinkNotice()
                : _failed
                    ? _buildOfflineNotice()
                    : ClipRRect(
                        borderRadius:
                            BorderRadius.circular(JinatraTokens.radiusCard),
                        child: WebViewWidget(controller: _controller),
                      ),
          ),
        ],
      ),
    );
  }

  /// The pinned link is not a web address at all — no host to promote, or a
  /// scheme the webview will not load. There is nothing to retry, so this
  /// says what is wrong and where to fix it instead of offering a button
  /// that would do nothing.
  Widget _buildUnusableLinkNotice() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: JinatraTokens.cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 40, color: JinatraTokens.signal),
            const SizedBox(height: 12),
            Text('LINK NOT USABLE',
                style: JinatraTokens.sectionHeader(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'The pinned video link for this exercise is not a web address '
              'this app can open. Edit the exercise and paste a full '
              'youtube.com link, or clear the field to search instead.',
              textAlign: TextAlign.center,
              style: JinatraTokens.bodyText(fontSize: 13),
            ),
          ],
        ),
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
                decoration: JinatraTokens.cardDecoration(
                  background: JinatraTokens.deepTeal,
                  shadowOffset: JinatraTokens.shadowSm,
                  radius: JinatraTokens.radiusPill,
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
