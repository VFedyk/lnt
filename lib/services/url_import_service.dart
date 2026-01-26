import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Result of a URL import operation
class UrlImportResult {
  final String title;
  final String content;
  final String url;
  final String? coverImageUrl;

  UrlImportResult({
    required this.title,
    required this.content,
    required this.url,
    this.coverImageUrl,
  });
}

/// Service for importing text content from URLs
class UrlImportService {
  /// Fetch and extract text content from a URL
  Future<UrlImportResult> importFromUrl(String url) async {
    // Ensure URL has a scheme
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final uri = Uri.parse(url);

    final response = await http.get(
      uri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    );

    if (response.statusCode != 200) {
      throw UrlImportException(
        'Failed to fetch URL: HTTP ${response.statusCode}',
      );
    }

    final document = html_parser.parse(response.body);

    // Extract title
    String title = _extractTitle(document, uri);

    // Extract cover image URL
    String? coverImageUrl = _extractCoverImageUrl(document, uri);

    // Extract main content
    String content = _extractContent(document);

    if (content.trim().isEmpty) {
      throw UrlImportException('No readable content found on the page');
    }

    return UrlImportResult(
      title: title,
      content: content,
      url: url,
      coverImageUrl: coverImageUrl,
    );
  }

  /// Extract the page title
  String _extractTitle(Document document, Uri uri) {
    // Try <title> tag first
    final titleElement = document.querySelector('title');
    if (titleElement != null && titleElement.text.trim().isNotEmpty) {
      return titleElement.text.trim();
    }

    // Try <h1> tag
    final h1Element = document.querySelector('h1');
    if (h1Element != null && h1Element.text.trim().isNotEmpty) {
      return h1Element.text.trim();
    }

    // Try og:title meta tag
    final ogTitle = document.querySelector('meta[property="og:title"]');
    if (ogTitle != null) {
      final content = ogTitle.attributes['content'];
      if (content != null && content.trim().isNotEmpty) {
        return content.trim();
      }
    }

    // Fallback to domain name
    return uri.host;
  }

  /// Extract cover image URL from the page (does not download)
  String? _extractCoverImageUrl(Document document, Uri pageUri) {
    String? imageUrl;

    // Try og:image meta tag first (most reliable for articles)
    final ogImage = document.querySelector('meta[property="og:image"]');
    if (ogImage != null) {
      imageUrl = ogImage.attributes['content'];
    }

    // Try twitter:image meta tag
    if (imageUrl == null || imageUrl.isEmpty) {
      final twitterImage = document.querySelector('meta[name="twitter:image"]');
      if (twitterImage != null) {
        imageUrl = twitterImage.attributes['content'];
      }
    }

    // Try article image
    if (imageUrl == null || imageUrl.isEmpty) {
      final articleImg = document.querySelector('article img[src]');
      if (articleImg != null) {
        imageUrl = articleImg.attributes['src'];
      }
    }

    // Try first significant image in main content
    if (imageUrl == null || imageUrl.isEmpty) {
      final mainImg = document.querySelector('main img[src], .content img[src], .article img[src]');
      if (mainImg != null) {
        imageUrl = mainImg.attributes['src'];
      }
    }

    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    // Resolve relative URLs
    if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
      if (imageUrl.startsWith('//')) {
        imageUrl = '${pageUri.scheme}:$imageUrl';
      } else if (imageUrl.startsWith('/')) {
        imageUrl = '${pageUri.scheme}://${pageUri.host}$imageUrl';
      } else {
        final basePath = pageUri.path.substring(0, pageUri.path.lastIndexOf('/') + 1);
        imageUrl = '${pageUri.scheme}://${pageUri.host}$basePath$imageUrl';
      }
    }

    return imageUrl;
  }

  /// Download and save a cover image from URL
  Future<String?> downloadCoverImage(String imageUrl) async {
    try {
      final imageResponse = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
          'Accept': 'image/*,*/*;q=0.8',
        },
      );

      if (imageResponse.statusCode != 200) {
        return null;
      }

      // Determine file extension from content-type or URL
      String extension = 'jpg';
      final contentType = imageResponse.headers['content-type'] ?? '';
      if (contentType.contains('png')) {
        extension = 'png';
      } else if (contentType.contains('gif')) {
        extension = 'gif';
      } else if (contentType.contains('webp')) {
        extension = 'webp';
      } else if (imageUrl.toLowerCase().contains('.png')) {
        extension = 'png';
      } else if (imageUrl.toLowerCase().contains('.gif')) {
        extension = 'gif';
      } else if (imageUrl.toLowerCase().contains('.webp')) {
        extension = 'webp';
      }

      // Save to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = p.join(coversDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(imageResponse.bodyBytes);

      return filePath;
    } catch (e) {
      // Image download failed
      return null;
    }
  }

  /// Extract the main text content from the page
  String _extractContent(Document document) {
    // Remove unwanted elements
    _removeElements(document, [
      'script',
      'style',
      'noscript',
      'iframe',
      'nav',
      'header',
      'footer',
      'aside',
      'form',
      'button',
      'input',
      'select',
      'textarea',
      'svg',
      'img',
      'video',
      'audio',
      'canvas',
      'figure',
      'figcaption',
      'menu',
      'menuitem',
    ]);

    // Remove elements with common non-content classes/ids
    _removeElementsBySelector(document, [
      '.nav',
      '.navbar',
      '.navigation',
      '.menu',
      '.sidebar',
      '.footer',
      '.header',
      '.comment',
      '.comments',
      '.advertisement',
      '.ad',
      '.ads',
      '.social',
      '.share',
      '.related',
      '.recommended',
      '#nav',
      '#navbar',
      '#navigation',
      '#menu',
      '#sidebar',
      '#footer',
      '#header',
      '#comments',
    ]);

    // Try to find the main content area
    Element? mainContent;

    // Try common content selectors
    final contentSelectors = [
      'article',
      'main',
      '.article',
      '.post',
      '.content',
      '.entry-content',
      '.post-content',
      '.article-content',
      '.story-body',
      '.article-body',
      '#content',
      '#main',
      '#article',
    ];

    for (final selector in contentSelectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final text = _extractTextFromElement(element);
        if (text.length > 200) {
          // Likely has meaningful content
          mainContent = element;
          break;
        }
      }
    }

    // Fall back to body if no main content area found
    mainContent ??= document.body;

    if (mainContent == null) {
      return '';
    }

    return _extractTextFromElement(mainContent);
  }

  /// Remove all elements matching the given tag names
  void _removeElements(Document document, List<String> tagNames) {
    for (final tagName in tagNames) {
      document.querySelectorAll(tagName).forEach((e) => e.remove());
    }
  }

  /// Remove all elements matching the given selectors
  void _removeElementsBySelector(Document document, List<String> selectors) {
    for (final selector in selectors) {
      try {
        document.querySelectorAll(selector).forEach((e) => e.remove());
      } catch (_) {
        // Invalid selector, skip
      }
    }
  }

  /// Extract readable text from an element
  String _extractTextFromElement(Element element) {
    final buffer = StringBuffer();
    _extractTextRecursive(element, buffer);
    return _cleanText(buffer.toString());
  }

  /// Recursively extract text, preserving some structure
  void _extractTextRecursive(Node node, StringBuffer buffer) {
    if (node is Text) {
      buffer.write(node.text);
      return;
    }

    if (node is Element) {
      // Skip hidden elements
      final style = node.attributes['style'] ?? '';
      if (style.contains('display:none') ||
          style.contains('display: none') ||
          style.contains('visibility:hidden') ||
          style.contains('visibility: hidden')) {
        return;
      }

      // Add spacing for block elements
      final blockElements = {
        'p',
        'div',
        'section',
        'article',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'li',
        'br',
        'hr',
        'blockquote',
        'pre',
        'table',
        'tr',
      };

      final isBlock = blockElements.contains(node.localName?.toLowerCase());

      if (isBlock && buffer.isNotEmpty) {
        buffer.write('\n\n');
      }

      for (final child in node.nodes) {
        _extractTextRecursive(child, buffer);
      }

      if (isBlock) {
        buffer.write('\n');
      }
    }
  }

  /// Clean up extracted text
  String _cleanText(String text) {
    // Replace multiple spaces with single space
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');

    // Replace multiple newlines with double newline (paragraph break)
    text = text.replaceAll(RegExp(r'\n\s*\n+'), '\n\n');

    // Trim each line
    final lines = text.split('\n').map((line) => line.trim()).toList();

    // Remove empty lines at start/end and collapse multiple empty lines
    final result = <String>[];
    bool lastWasEmpty = true;

    for (final line in lines) {
      if (line.isEmpty) {
        if (!lastWasEmpty) {
          result.add('');
          lastWasEmpty = true;
        }
      } else {
        result.add(line);
        lastWasEmpty = false;
      }
    }

    // Trim and return
    return result.join('\n').trim();
  }
}

/// Exception thrown when URL import fails
class UrlImportException implements Exception {
  final String message;
  UrlImportException(this.message);

  @override
  String toString() => message;
}
