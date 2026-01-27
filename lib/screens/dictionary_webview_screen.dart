// FILE: lib/screens/dictionary_webview_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/generated/app_localizations.dart';

class DictionaryWebViewScreen extends StatefulWidget {
  final String url;
  final String word;

  const DictionaryWebViewScreen({
    super.key,
    required this.url,
    required this.word,
  });

  @override
  State<DictionaryWebViewScreen> createState() =>
      _DictionaryWebViewScreenState();
}

class _DictionaryWebViewScreenState extends State<DictionaryWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  late String _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _initializeWebView();
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
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
          },
          onWebResourceError: (error) {
            setState(() => _isLoading = false);

            // WKErrorDomain error 2 = frame load interrupted
            if (error.errorCode == 2) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.word, style: const TextStyle(fontSize: 18)),
            Text(
              l10n.dictionaryLookup,
              style: TextStyle(fontSize: 12, color: Colors.grey[300]),
            ),
          ],
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                    const SizedBox(width: 8),
                    Text(l10n.back),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'forward',
                child: Row(
                  children: [
                    const Icon(Icons.arrow_forward),
                    const SizedBox(width: 8),
                    Text(l10n.forward),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'open_external',
                child: Row(
                  children: [
                    const Icon(Icons.open_in_browser),
                    const SizedBox(width: 8),
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
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }

  Future<void> _openInExternalBrowser() async {
    try {
      final urlString = _currentUrl.isNotEmpty ? _currentUrl : widget.url;
      final url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorOpeningBrowser(e.toString()))));
      }
    }
  }
}
