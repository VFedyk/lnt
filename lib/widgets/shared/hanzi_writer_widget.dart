import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../utils/constants.dart';

/// Events surfaced from the Hanzi Writer JS quiz.
sealed class HanziWriterEvent {}

class HanziWriterStrokeEvent extends HanziWriterEvent {
  final int strokeNum;
  final int totalStrokes;
  HanziWriterStrokeEvent(this.strokeNum, this.totalStrokes);
}

class HanziWriterMistakeEvent extends HanziWriterEvent {
  final int strokeNum;
  HanziWriterMistakeEvent(this.strokeNum);
}

class HanziWriterCompleteEvent extends HanziWriterEvent {
  final int totalMistakes;
  HanziWriterCompleteEvent(this.totalMistakes);
}

class HanziWriterLoadErrorEvent extends HanziWriterEvent {}

/// Whether the current platform supports [HanziWriterWidget].
/// Linux and Windows lack a bundled WebView engine.
bool get hanziWriterSupported =>
    !Platform.isLinux && !Platform.isWindows;

/// Displays a Hanzi Writer quiz for [character] inside a WebView.
///
/// Requires an internet connection to load the JS library and character
/// stroke data from the jsdelivr CDN.
///
/// On unsupported platforms (Linux, Windows) render [unsupportedChild] instead.
class HanziWriterWidget extends StatefulWidget {
  final String character;
  final void Function(HanziWriterEvent event)? onEvent;
  final Widget? unsupportedChild;

  const HanziWriterWidget({
    super.key,
    required this.character,
    this.onEvent,
    this.unsupportedChild,
  });

  @override
  State<HanziWriterWidget> createState() => _HanziWriterWidgetState();
}

class _HanziWriterWidgetState extends State<HanziWriterWidget> {
  late final WebViewController _controller;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    if (!hanziWriterSupported) return;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // setBackgroundColor uses setOpaque which is not implemented on macOS
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: _onMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (_) {
            if (mounted) setState(() => _loadError = true);
            widget.onEvent?.call(HanziWriterLoadErrorEvent());
          },
        ),
      )
      ..loadHtmlString(_buildHtml(), baseUrl: 'https://cdn.jsdelivr.net');
  }

  void _onMessage(JavaScriptMessage msg) {
    final data = jsonDecode(msg.message) as Map<String, dynamic>;
    final type = data['t'] as String?;
    final event = switch (type) {
      'stroke' => HanziWriterStrokeEvent(
          (data['stroke'] as num).toInt(),
          (data['total'] as num).toInt(),
        ),
      'mistake' => HanziWriterMistakeEvent(
          (data['stroke'] as num).toInt(),
        ),
      'complete' => HanziWriterCompleteEvent(
          (data['mistakes'] as num).toInt(),
        ),
      'error' => HanziWriterLoadErrorEvent(),
      _ => null,
    };
    if (event != null) widget.onEvent?.call(event);
  }

  String _buildHtml() {
    // Escape the character for safe embedding in JS string literal.
    final jsChar = widget.character
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'");

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport"
        content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%; height: 100%;
      display: flex; justify-content: center; align-items: center;
      background: transparent; overflow: hidden;
    }
    #target { touch-action: none; }
    #error {
      display: none; padding: 24px; text-align: center;
      font-family: sans-serif; font-size: 14px; color: #888;
    }
  </style>
</head>
<body>
  <div id="target"></div>
  <div id="error">Could not load stroke data.<br>Check your internet connection.</div>
  <script src="https://cdn.jsdelivr.net/npm/hanzi-writer@3.5/dist/hanzi-writer.min.js"
          onerror="showError()"></script>
  <script>
    function showError() {
      document.getElementById('target').style.display = 'none';
      document.getElementById('error').style.display = 'block';
      FlutterBridge.postMessage(JSON.stringify({t: 'error'}));
    }

    window.addEventListener('load', function () {
      if (typeof HanziWriter === 'undefined') { showError(); return; }

      var size = Math.round(Math.min(window.innerWidth, window.innerHeight) * 0.92);
      var writer = HanziWriter.create('target', '$jsChar', {
        width: size,
        height: size,
        padding: Math.round(size * 0.06),
        showOutline: true,
        strokeColor: '#333333',
        outlineColor: '#cccccc',
        highlightColor: '#4CAF50',
        drawingColor: '#1565C0',
        drawingWidth: Math.max(4, Math.round(size / 70)),
        charDataLoader: function (char, onLoad, onError) {
          fetch(
            'https://cdn.jsdelivr.net/npm/hanzi-writer-data@2/' +
              encodeURIComponent(char) + '.json'
          )
            .then(function (r) {
              if (!r.ok) throw new Error('HTTP ' + r.status);
              return r.json();
            })
            .then(onLoad)
            .catch(function () { showError(); if (onError) onError(); });
        },
      });

      writer.quiz({
        leniency: 1,
        onMistake: function (sd) {
          FlutterBridge.postMessage(
            JSON.stringify({t: 'mistake', stroke: sd.strokeNum})
          );
        },
        onCorrectStroke: function (sd) {
          FlutterBridge.postMessage(
            JSON.stringify({t: 'stroke', stroke: sd.strokeNum,
                            total: sd.totalStrokes})
          );
        },
        onComplete: function (sum) {
          FlutterBridge.postMessage(
            JSON.stringify({t: 'complete', mistakes: sum.totalMistakes})
          );
        },
      });
    });
  </script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    if (!hanziWriterSupported) {
      return widget.unsupportedChild ?? const _UnsupportedPlaceholder();
    }
    if (_loadError) {
      return _ErrorPlaceholder(
        onRetry: () {
          setState(() => _loadError = false);
          _controller.reload();
        },
      );
    }
    return WebViewWidget(controller: _controller);
  }
}

class _UnsupportedPlaceholder extends StatelessWidget {
  const _UnsupportedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.desktop_access_disabled_outlined,
              size: 48,
              color: AppConstants.subtitleColor,
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Radical writing practice is not supported on this platform.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppConstants.subtitleColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorPlaceholder({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_outlined,
              size: 48,
              color: AppConstants.subtitleColor,
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Could not load stroke data.\nCheck your internet connection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppConstants.subtitleColor),
            ),
            const SizedBox(height: AppConstants.spacingL),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
