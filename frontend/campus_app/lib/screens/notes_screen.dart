import 'package:flutter/material.dart';

import '../services/api_service.dart';

import '../theme/app_theme.dart';

import '../utils/paginated_list_controller.dart';

import '../widgets/feedback_banner.dart';

import '../widgets/paginated_list_view.dart';

import 'document_reader_screen.dart';

import 'note_reader_screen.dart';



class NotesScreen extends StatefulWidget {

  final bool embedInShell;



  const NotesScreen({super.key, this.embedInShell = false});



  @override

  State<NotesScreen> createState() => _NotesScreenState();

}



class _NotesScreenState extends State<NotesScreen> {

  late final PaginatedListController<Map<String, dynamic>> _controller;

  bool _busy = false;



  @override

  void initState() {

    super.initState();

    _controller = PaginatedListController(

      fetchPage: (page) => ApiService.getNotes(page: page),

    );

  }



  @override

  void dispose() {

    _controller.dispose();

    super.dispose();

  }



  Future<void> _downloadNote(Map<String, dynamic> note) async {

    setState(() => _busy = true);

    try {

      final info = await ApiService.getNoteDownloadInfo(note['id'] as int);

      if (info['success'] != true) throw Exception(info['error']);

      final data = info['data'] as Map<String, dynamic>;

      final result = await ApiService.downloadAndOpen(

        data['download_url'] as String,

        data['filename'] as String? ?? 'note.pdf',

      );

      if (!mounted) return;

      if (result['success'] != true) {

        throw Exception(result['error']);

      }

      showAppSnackBar(context, message: 'Downloaded', success: true);

    } catch (e) {

      if (mounted) {

        showAppSnackBar(

          context,

          message: e.toString().replaceFirst('Exception: ', ''),

          success: false,

        );

      }

    } finally {

      if (mounted) setState(() => _busy = false);

    }

  }



  void _openNote(Map<String, dynamic> note) {

    final fileUrl = note['file_url']?.toString();

    if (fileUrl == null || fileUrl.isEmpty) {

      showAppSnackBar(context, message: 'No file attached', success: false);

      return;

    }



    final resolved = ApiService.resolveMediaUrl(fileUrl);

    if (resolved.isNotEmpty) {

      Navigator.push(

        context,

        MaterialPageRoute(

          builder: (_) => DocumentReaderScreen(

            title: note['title']?.toString() ?? 'Note',

            fileUrl: resolved,

            fileType: note['file_type']?.toString(),

          ),

        ),

      );

      return;

    }



    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => NoteReaderScreen(

          noteId: note['id'] as int,

          title: note['title']?.toString() ?? 'Note',

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final list = PaginatedListView(

      controller: _controller,

      emptyMessage: 'No notes for your groups yet.',

      emptyIcon: Icons.menu_book_outlined,

      itemBuilder: (context, note) => Card(

        margin: const EdgeInsets.only(bottom: 12),

        child: ListTile(

          contentPadding: const EdgeInsets.all(16),

          leading: const Icon(Icons.menu_book, color: AppTheme.primary, size: 36),

          title: Text(

            note['title']?.toString() ?? 'Untitled',

            style: const TextStyle(fontWeight: FontWeight.bold),

          ),

          subtitle: Text(

            note['description']?.toString() ?? '',

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

          ),

          trailing: note['file_url'] != null

              ? Row(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    IconButton(

                      icon: const Icon(Icons.visibility),

                      tooltip: 'Read in app',

                      onPressed: _busy ? null : () => _openNote(note),

                    ),

                    IconButton(

                      icon: const Icon(Icons.download),

                      tooltip: 'Download',

                      onPressed: _busy ? null : () => _downloadNote(note),

                    ),

                  ],

                )

              : null,

          onTap: note['file_url'] != null ? () => _openNote(note) : null,

        ),

      ),

    );



    return Scaffold(

      appBar: AppBar(title: const Text('Course Notes')),

      body: list,

    );

  }

}

