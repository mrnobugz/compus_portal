import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/paginated_list_controller.dart';
import '../widgets/feedback_banner.dart';
import '../widgets/paginated_list_view.dart';
import 'document_reader_screen.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  late final PaginatedListController<Map<String, dynamic>> _controller;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _controller = PaginatedListController(
      fetchPage: (page) => ApiService.getBooks(page: page),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _download(Map<String, dynamic> book) async {
    final id = book['id'] as int?;
    if (id == null) return;
    setState(() => _busyId = id);
    final title = book['title']?.toString() ?? 'book';
    final result = await ApiService.downloadBook(id, title);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (result['success'] == true) {
      showAppSnackBar(context, message: 'Downloaded $title', success: true);
    } else {
      showAppSnackBar(
        context,
        message: result['error']?.toString() ?? 'Download failed',
        success: false,
      );
    }
  }

  Future<void> _preview(Map<String, dynamic> book) async {
    final id = book['id'] as int?;
    if (id == null) return;

    var fileUrl = book['file_url']?.toString();
    var fileType = book['file_type']?.toString();

    if (fileUrl == null || fileUrl.isEmpty) {
      setState(() => _busyId = id);
      final info = await ApiService.getBookDownloadUrl(id);
      if (!mounted) return;
      setState(() => _busyId = null);
      if (info['success'] != true) {
        showAppSnackBar(
          context,
          message: info['error']?.toString() ?? 'Cannot open book',
          success: false,
        );
        return;
      }
      final data = info['data'] as Map<String, dynamic>;
      fileUrl = data['download_url']?.toString();
      fileType = data['file_type']?.toString();
    } else {
      fileUrl = ApiService.resolveMediaUrl(fileUrl);
    }

    if (fileUrl == null || fileUrl.isEmpty) {
      showAppSnackBar(context, message: 'No file available', success: false);
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentReaderScreen(
          title: book['title']?.toString() ?? 'Book',
          fileUrl: fileUrl!,
          fileType: fileType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Library')),
      body: PaginatedListView(
        controller: _controller,
        emptyMessage: 'No books in the library yet.',
        emptyIcon: Icons.library_books_outlined,
        itemBuilder: (context, book) {
          final id = book['id'] as int?;
          final hasFile = book['file_url'] != null;
          final busy = _busyId == id;
          final coverUrl = ApiService.resolveMediaUrl(
            book['cover_image_url']?.toString(),
          );
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: coverUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        coverUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _bookIcon(),
                      ),
                    )
                  : _bookIcon(),
              title: Text(
                book['title']?.toString() ?? 'Untitled',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(book['author']?.toString() ?? ''),
              trailing: hasFile
                  ? busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, color: AppTheme.primary),
                              tooltip: 'Read in app',
                              onPressed: () => _preview(book),
                            ),
                            IconButton(
                              icon: const Icon(Icons.download, color: AppTheme.primary),
                              tooltip: 'Download',
                              onPressed: () => _download(book),
                            ),
                          ],
                        )
                  : null,
              onTap: hasFile ? () => _preview(book) : null,
            ),
          );
        },
      ),
    );
  }

  Widget _bookIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.book, color: Colors.white),
    );
  }
}
