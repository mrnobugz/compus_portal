import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_banner.dart';

/// In-app preview for PDF and TXT files (notes, books, etc.).
class DocumentReaderScreen extends StatefulWidget {
  final String title;
  final String fileUrl;
  final String? fileType;

  const DocumentReaderScreen({
    super.key,
    required this.title,
    required this.fileUrl,
    this.fileType,
  });

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  bool _loading = true;
  bool _downloading = false;
  String? _error;
  PdfControllerPinch? _pdfController;
  String? _textContent;
  late String _fileType;

  @override
  void initState() {
    super.initState();
    _fileType = (widget.fileType ?? _extFromUrl(widget.fileUrl)).toLowerCase();
    _load();
  }

  String _extFromUrl(String url) {
    final path = Uri.parse(url).path;
    if (!path.contains('.')) return '';
    return path.split('.').last.split('?').first;
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final url = ApiService.resolveMediaUrl(widget.fileUrl);
    final filename = url.split('/').last.split('?').first;

    try {
      if (_fileType == 'pdf') {
        final file = await ApiService.downloadToDevice(url, filename);
        if (file == null) {
          throw Exception(
            'Could not download PDF. Check server settings on a physical device.',
          );
        }
        _pdfController = PdfControllerPinch(
          document: PdfDocument.openFile(file.path),
        );
        setState(() => _loading = false);
        return;
      }

      if (_fileType == 'txt') {
        final text = await ApiService.fetchTextContent(url);
        if (text == null) {
          throw Exception('Could not load text file.');
        }
        setState(() {
          _textContent = text;
          _loading = false;
        });
        return;
      }

      setState(() {
        _error =
            'In-app preview supports PDF and TXT. Use download for other formats.';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    final url = ApiService.resolveMediaUrl(widget.fileUrl);
    final filename = url.split('/').last.split('?').first;
    final result = await ApiService.downloadAndOpen(url, filename);
    if (mounted) {
      setState(() => _downloading = false);
      if (result['success'] != true) {
        showAppSnackBar(
          context,
          message: result['error']?.toString() ?? 'Download failed',
          success: false,
        );
      } else {
        showAppSnackBar(
          context,
          message: 'File saved and opened',
          success: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _downloading ? null : _download,
            icon: _downloading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: 'Download',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FeedbackBanner(message: _error!, type: FeedbackType.error),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _fileType == 'pdf' && _pdfController != null
          ? PdfViewPinch(controller: _pdfController!)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _textContent ?? '',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
    );
  }
}
