import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:hymns_latest/theme/christmas_theme.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Widget for viewing PDF song sheets with full rendering support.
/// 
/// Features:
/// - Full PDF page rendering on all platforms (iOS, Android, Web, Desktop)
/// - Aggressive caching for faster loading
/// - Pinch-to-zoom support
/// - Page navigation for multi-page PDFs
/// - Smooth page transitions
/// - Loading states and error handling
/// 
/// Uses the `pdfx` package for cross-platform PDF rendering.
class PdfSongViewer extends StatefulWidget {
  final String pdfPath;

  const PdfSongViewer({
    super.key,
    required this.pdfPath,
  });

  @override
  State<PdfSongViewer> createState() => _PdfSongViewerState();
}

class _PdfSongViewerState extends State<PdfSongViewer> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;
  String _loadingStatus = 'Loading PDF...';

  // Static cache for PDF documents to avoid reloading
  static final Map<String, String> _cachedPaths = {};

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  /// Generates a unique cache key from the URL
  String _getCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _loadingStatus = 'Preparing PDF...';
    });

    try {
      PdfDocument document;
      
      if (widget.pdfPath.startsWith('http')) {
        // Check cache first
        final cacheKey = _getCacheKey(widget.pdfPath);
        String? localPath = _cachedPaths[cacheKey];
        
        if (localPath != null && await File(localPath).exists()) {
          // Use cached file
          setState(() => _loadingStatus = 'Loading from cache...');
          document = await PdfDocument.openFile(localPath);
        } else {
          // Download and cache
          setState(() => _loadingStatus = 'Downloading PDF...');
          localPath = await _downloadAndCachePdf(widget.pdfPath, cacheKey);
          _cachedPaths[cacheKey] = localPath;
          document = await PdfDocument.openFile(localPath);
        }
      } else {
        // Local file path
        final file = File(widget.pdfPath);
        if (await file.exists()) {
          setState(() => _loadingStatus = 'Opening PDF...');
          document = await PdfDocument.openFile(widget.pdfPath);
        } else {
          throw Exception('PDF file not found');
        }
      }

      _pdfController = PdfControllerPinch(
        document: Future.value(document),
        initialPage: 1,
      );

      _totalPages = document.pagesCount;

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<String> _downloadAndCachePdf(String url, String cacheKey) async {
    // Use application documents directory for persistent caching
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/pdf_cache');
    
    // Create cache directory if it doesn't exist
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    final filePath = '${cacheDir.path}/$cacheKey.pdf';
    final file = File(filePath);
    
    // Check if already cached on disk
    if (await file.exists()) {
      return filePath;
    }
    
    // Download the file
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode != 200) {
      throw Exception('Failed to download PDF: ${response.statusCode}');
    }

    // Save to cache
    await file.writeAsBytes(response.bodyBytes);
    
    return filePath;
  }

  void _goToPage(int page) {
    if (_pdfController != null && page >= 1 && page <= _totalPages) {
      _pdfController!.animateToPage(
        pageNumber: page,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 1) {
      _goToPage(_currentPage - 1);
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      _goToPage(_currentPage + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: ChristmasColors.christmasRed,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _loadingStatus,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState(colorScheme, textTheme);
    }

    if (_pdfController == null) {
      return _buildErrorState(colorScheme, textTheme);
    }

    return Column(
      children: [
        // Navigation toolbar (only show if multiple pages)
        if (_totalPages > 1) _buildToolbar(colorScheme, textTheme),
        
        // PDF content area
        Expanded(
          child: Container(
            color: colorScheme.surfaceContainerLow,
            child: PdfViewPinch(
              controller: _pdfController!,
              scrollDirection: Axis.vertical,
              onDocumentLoaded: (document) {
                setState(() {
                  _totalPages = document.pagesCount;
                });
              },
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                options: const DefaultBuilderOptions(),
                documentLoaderBuilder: (_) => Center(
                  child: CircularProgressIndicator(
                    color: ChristmasColors.christmasRed,
                    strokeWidth: 3,
                  ),
                ),
                pageLoaderBuilder: (_) => Center(
                  child: CircularProgressIndicator(
                    color: ChristmasColors.christmasGreen,
                    strokeWidth: 2,
                  ),
                ),
                errorBuilder: (_, error) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading page',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous page button
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            tooltip: 'Previous page',
            onPressed: _currentPage > 1 ? _previousPage : null,
          ),

          // Page indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Text(
              '$_currentPage / $_totalPages',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Next page button
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            tooltip: 'Next page',
            onPressed: _currentPage < _totalPages ? _nextPage : null,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to load PDF',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadPdf,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: ChristmasColors.christmasRed,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Clears the PDF cache (can be called from settings)
  static Future<void> clearCache() async {
    _cachedPaths.clear();
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/pdf_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing PDF cache: $e');
    }
  }
}
