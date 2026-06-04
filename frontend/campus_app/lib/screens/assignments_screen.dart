import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/paginated_list_controller.dart';
import '../widgets/paginated_list_view.dart';

class AssignmentsScreen extends StatefulWidget {
  final bool embedInShell;

  const AssignmentsScreen({super.key, this.embedInShell = false});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  late final PaginatedListController<Map<String, dynamic>> _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaginatedListController(
      fetchPage: (page) => ApiService.getAssignments(page: page),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _download(Map<String, dynamic> assignment) async {
    try {
      final info = await ApiService.getAssignmentDownloadInfo(
        assignment['id'] as int,
      );
      if (info['success'] != true) throw Exception(info['error']);
      final data = info['data'] as Map<String, dynamic>;
      final file = await ApiService.downloadToDevice(
        data['download_url'] as String,
        data['filename'] as String? ?? 'assignment.pdf',
      );
      if (file != null) {
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assignments')),
      body: PaginatedListView(
        controller: _controller,
        emptyMessage: 'No assignments for your groups.',
        emptyIcon: Icons.assignment_outlined,
        itemBuilder: (context, a) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(Icons.assignment, color: AppTheme.primary, size: 36),
            title: Text(
              a['title']?.toString() ?? 'Assignment',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a['due_date'] != null)
                  Text('Due: ${a['due_date']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                if (a['lecturer_name'] != null)
                  Text('Lecturer: ${a['lecturer_name']}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _download(a),
            ),
          ),
        ),
      ),
    );
  }
}
