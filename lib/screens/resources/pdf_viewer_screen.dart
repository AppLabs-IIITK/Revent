import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String url;

  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
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
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF8B949E)),
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
      body: _error != null
          ? _buildError()
          : Stack(
              children: [
                SfPdfViewer.network(
                  widget.url,
                  key: _pdfViewerKey,
                  controller: _pdfController,
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                  canShowPaginationDialog: true,
                  enableDoubleTapZooming: true,
                  onDocumentLoaded: (details) {
                    setState(() {
                      _isLoading = false;
                      _totalPages = details.document.pages.count;
                    });
                  },
                  onDocumentLoadFailed: (details) {
                    setState(() {
                      _isLoading = false;
                      _error = details.description;
                    });
                  },
                  onPageChanged: (details) {
                    setState(() {
                      _currentPage = details.newPageNumber;
                    });
                  },
                ),
                if (_isLoading)
                  Container(
                    color: const Color(0xFF07181F),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF83ACBD)),
                          SizedBox(height: 16),
                          Text(
                            'Loading PDF...',
                            style: TextStyle(color: Color(0xFF8B949E)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: _totalPages > 0
          ? Container(
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF06222F),
                border: Border(
                  top: BorderSide(color: Color(0xFF17323D)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.first_page, color: Color(0xFF8B949E)),
                    onPressed: _currentPage > 1
                        ? () => _pdfController.jumpToPage(1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_before, color: Color(0xFF8B949E)),
                    onPressed: _currentPage > 1
                        ? () => _pdfController.previousPage()
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out, color: Color(0xFF8B949E)),
                    onPressed: () {
                      final currentZoom = _pdfController.zoomLevel;
                      if (currentZoom > 1.0) {
                        _pdfController.zoomLevel = currentZoom - 0.25;
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_in, color: Color(0xFF8B949E)),
                    onPressed: () {
                      final currentZoom = _pdfController.zoomLevel;
                      if (currentZoom < 3.0) {
                        _pdfController.zoomLevel = currentZoom + 0.25;
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_next, color: Color(0xFF8B949E)),
                    onPressed: _currentPage < _totalPages
                        ? () => _pdfController.nextPage()
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page, color: Color(0xFF8B949E)),
                    onPressed: _currentPage < _totalPages
                        ? () => _pdfController.jumpToPage(_totalPages)
                        : null,
                  ),
                ],
              ),
            )
          : null,
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
              size: 64,
              color: Color(0xFFF85149),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load PDF',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8B949E)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isLoading = true;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
