import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String title;
  final String url;

  const DocumentViewerScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _error;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller = null;
    super.dispose();
  }

  void _initWebView() {
    // Use Google Docs viewer to render Office documents
    final viewerUrl = 'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.url)}&embedded=true';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF07181F))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!_isDisposed && mounted) {
              setState(() {
                _isLoading = true;
                _error = null;
              });
            }
          },
          onPageFinished: (url) {
            if (!_isDisposed && mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (error) {
            if (!_isDisposed && mounted) {
              setState(() {
                _isLoading = false;
                _error = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(viewerUrl));

    if (!_isDisposed && mounted) {
      setState(() {
        _controller = controller;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07181F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF06222F),
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFFAEE7FF),
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF83ACBD)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download',
            onPressed: () {
              launchUrl(
                Uri.parse(widget.url),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_error != null)
            _buildError()
          else if (_controller != null)
            WebViewWidget(controller: _controller!),
          if (_isLoading)
            Container(
              color: const Color(0xFF07181F),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFAEE7FF)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading document...',
                      style: TextStyle(color: Color(0xFF8B949E)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFF85149),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load document',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFFAEE7FF),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF83ACBD)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _initWebView();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E668A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
