// FILE: lib/screens/dictionary_webview_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../utils/async_helpers.dart';
import '../../utils/constants.dart';
import '../../utils/dictionary_page_style.dart';

abstract class _WebViewConstants {
  static const int frameLoadInterruptedError = 2;
  static const Duration revealFallback = Duration(seconds: 8);
  static const Duration coverFade = Duration(milliseconds: 180);
  static const String darkSheetMarker = '__lntDarkSheet';
}

class DictionaryWebViewScreen extends StatefulWidget {
  final String url;
  final String word;
  final String? customCss;

  /// Invert page colours while the app's effective theme is dark. Ignored when
  /// [customCss] is non-empty.
  final bool darkenPages;

  /// Also cover the page on in-page navigation, not only on the first load.
  final bool coverOnNavigation;

  const DictionaryWebViewScreen({
    super.key,
    required this.url,
    required this.word,
    this.customCss,
    this.darkenPages = false,
    this.coverOnNavigation = false,
  });

  @override
  State<DictionaryWebViewScreen> createState() =>
      _DictionaryWebViewScreenState();
}

class _DictionaryWebViewScreenState extends State<DictionaryWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  late String _currentUrl;
  bool _contentVisible = false;
  bool _firstLoadDone = false;
  Timer? _revealTimer;
  Color? _appliedBackground;
  Brightness _brightness = Brightness.light;
  Color _surface = Colors.white;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _initializeWebView();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    _brightness = theme.brightness;
    _surface = theme.colorScheme.surface;
    // setBackgroundColor uses setOpaque, which isn't implemented on macOS; the
    // cover overlay handles it there.
    if (_surface != _appliedBackground &&
        !kIsWeb &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      _appliedBackground = _surface;
      _controller.setBackgroundColor(_surface);
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _reveal() {
    _revealTimer?.cancel();
    if (mounted) setState(() => _contentVisible = true);
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            // Fallback for pages whose onPageFinished arrives very late.
            _revealTimer?.cancel();
            _revealTimer = Timer(_WebViewConstants.revealFallback, _reveal);
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _currentUrl = url;
              if (widget.coverOnNavigation && _firstLoadDone) {
                _contentVisible = false;
              }
            });
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _currentUrl = url;
              });
            }
            _firstLoadDone = true;
            try {
              await _injectStyles();
            } catch (_) {
              // A JS failure must never leave the page covered.
            } finally {
              _reveal();
            }
          },
          onWebResourceError: (error) {
            // A failed ad or font must not clear the loading state early.
            if (error.isForMainFrame != false) {
              if (mounted) setState(() => _isLoading = false);
              _reveal();
            }

            // WKErrorDomain error 2 = frame load interrupted
            if (error.errorCode ==
                _WebViewConstants.frameLoadInterruptedError) {
              // This is often a false positive, page may still load
              return;
            }

            if (mounted) {
              final l10n = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.errorLoadingPage(error.description)),
                  action: SnackBarAction(
                    label: l10n.retry,
                    onPressed: () => _controller.reload(),
                  ),
                ),
              );
            }
          },
          onNavigationRequest: (request) {
            // Allow all navigation
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

  }

  Future<void> _injectStyles() async {
    final custom = widget.customCss;
    if (custom != null && custom.isNotEmpty) {
      // The dictionary's own CSS wins; darkening it too would double-invert.
      await _injectCss(custom, forceImportant: true);
    } else if (widget.darkenPages && _brightness == Brightness.dark) {
      await _injectCss(
        buildDarkenCss(_surface),
        forceImportant: false,
        marker: _WebViewConstants.darkSheetMarker,
      );
    }
  }

  Future<void> _injectCss(
    String css, {
    required bool forceImportant,
    String? marker,
  }) async {
    final cssJson = jsonEncode(css);
    // Constructable Stylesheets (new CSSStyleSheet()) bypass CSP style-src
    // restrictions that block <style> element injection. Adding !important to
    // all declarations makes our rules win over inline styles set by React and
    // other frameworks, since author !important > normal inline styles in the
    // CSS cascade.
    final important = forceImportant
        ? 'css=css.replace(/([\\w-]+\\s*:\\s*[^;!{}]+?)\\s*(;|})/g,'
              'function(m,d,e){return d+" !important"+e;});'
        : '';
    // The marker stops a re-run on the same document adding a duplicate sheet.
    final guard = marker == null ? '' : 'if(window.$marker)return;';
    final store = marker == null ? '' : 'window.$marker=sheet;';
    await _controller.runJavaScript(
      '(function(){'
      '$guard'
      'var css=$cssJson;'
      '$important'
      'try{'
      'var sheet=new CSSStyleSheet();'
      'sheet.replaceSync(css);'
      'document.adoptedStyleSheets='
      '(document.adoptedStyleSheets||[]).concat([sheet]);'
      '$store'
      '}catch(e){}'
      '})()',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.word,
              style: const TextStyle(fontSize: AppConstants.fontSizeSubtitle),
            ),
            Text(
              l10n.dictionaryLookup,
              style: TextStyle(
                fontSize: AppConstants.fontSizeCaption,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingL,
                ),
                child: SizedBox(
                  width: AppConstants.progressIndicatorSize,
                  height: AppConstants.progressIndicatorSize,
                  child: CircularProgressIndicator(
                    strokeWidth: AppConstants.progressStrokeWidth,
                    color:
                        Theme.of(context).appBarTheme.foregroundColor ??
                        colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
            tooltip: l10n.reload,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'forward':
                  _controller.canGoForward().then((canGo) {
                    if (canGo) _controller.goForward();
                  });
                  break;
                case 'back':
                  _controller.canGoBack().then((canGo) {
                    if (canGo) _controller.goBack();
                  });
                  break;
                case 'open_external':
                  _openInExternalBrowser();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'back',
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.back),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'forward',
                child: Row(
                  children: [
                    const Icon(Icons.arrow_forward),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.forward),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'open_external',
                child: Row(
                  children: [
                    const Icon(Icons.open_in_browser),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.openInBrowser),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                _LoadingCover(visible: !_contentVisible),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInExternalBrowser() async {
    final l10n = AppLocalizations.of(context);
    await AsyncHelpers.run(
      context,
      operation: () async {
        final urlString = _currentUrl.isNotEmpty ? _currentUrl : widget.url;
        final url = Uri.parse(urlString);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      errorMessageBuilder: (e) => l10n.errorOpeningBrowser(e.toString()),
    );
  }
}

/// Opaque theme-coloured overlay that hides the native view's white flash.
class _LoadingCover extends StatelessWidget {
  final bool visible;

  const _LoadingCover({required this.visible});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: _WebViewConstants.coverFade,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}
