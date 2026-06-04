import 'package:flutter/material.dart';

import '../services/api_service.dart';

import '../theme/app_theme.dart';

import '../widgets/feedback_banner.dart';

import 'document_reader_screen.dart';



class NoteReaderScreen extends StatefulWidget {

  final int noteId;

  final String title;



  const NoteReaderScreen({

    super.key,

    required this.noteId,

    required this.title,

  });



  @override

  State<NoteReaderScreen> createState() => _NoteReaderScreenState();

}



class _NoteReaderScreenState extends State<NoteReaderScreen> {

  bool _loading = true;

  String? _error;

  String? _fileUrl;

  String? _fileType;



  @override

  void initState() {

    super.initState();

    _load();

  }



  Future<void> _load() async {

    final info = await ApiService.getNoteReadInfo(widget.noteId);

    if (!mounted) return;



    if (info['success'] != true) {

      setState(() {

        _error = info['error']?.toString() ?? 'Could not load note';

        _loading = false;

      });

      return;

    }



    final data = info['data'] as Map<String, dynamic>;

    setState(() {

      _fileUrl = data['file_url'] as String?;

      _fileType = data['file_type'] as String?;

      _loading = false;

    });

  }



  @override

  Widget build(BuildContext context) {

    if (_loading) {

      return Scaffold(

        appBar: AppBar(

          title: Text(widget.title),

          backgroundColor: AppTheme.primary,

          foregroundColor: Colors.white,

        ),

        body: const Center(child: CircularProgressIndicator()),

      );

    }



    if (_error != null || _fileUrl == null) {

      return Scaffold(

        appBar: AppBar(

          title: Text(widget.title),

          backgroundColor: AppTheme.primary,

          foregroundColor: Colors.white,

        ),

        body: Center(

          child: Padding(

            padding: const EdgeInsets.all(24),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                FeedbackBanner(

                  message: _error ?? 'No file attached',

                  type: FeedbackType.error,

                ),

                const SizedBox(height: 16),

                FilledButton.icon(

                  onPressed: () {

                    setState(() => _loading = true);

                    _load();

                  },

                  icon: const Icon(Icons.refresh),

                  label: const Text('Retry'),

                ),

              ],

            ),

          ),

        ),

      );

    }



    return DocumentReaderScreen(

      title: widget.title,

      fileUrl: _fileUrl!,

      fileType: _fileType,

    );

  }

}

