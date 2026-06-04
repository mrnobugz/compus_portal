import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LecturerUploadScreen extends StatefulWidget {
  final bool embedInShell;

  const LecturerUploadScreen({super.key, this.embedInShell = false});

  @override
  State<LecturerUploadScreen> createState() => _LecturerUploadScreenState();
}

class _LecturerUploadScreenState extends State<LecturerUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dueDateController = TextEditingController();

  List<dynamic> _groups = [];
  final Set<int> _selectedGroupIds = {};
  File? _file;
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final groups = await ApiService.getLecturerGroups();
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _file = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_file == null) {
      _snack('Please select a file', error: true);
      return;
    }
    if (_selectedGroupIds.isEmpty) {
      _snack('Select at least one group', error: true);
      return;
    }

    setState(() => _uploading = true);
    final result = await ApiService.uploadAssignment(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      file: _file!,
      groupIds: _selectedGroupIds.toList(),
      dueDate: _dueDateController.text.trim().isEmpty
          ? null
          : _dueDateController.text.trim(),
    );
    setState(() => _uploading = false);

    if (result['success'] == true) {
      _snack('Assignment uploaded');
      _titleController.clear();
      _descController.clear();
      _dueDateController.clear();
      setState(() {
        _file = null;
        _selectedGroupIds.clear();
      });
    } else {
      _snack(result['error']?.toString() ?? 'Upload failed', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Assignment'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Post to groups',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_groups.isEmpty)
                      const Text('No groups assigned to you yet.')
                    else
                      ..._groups.map((g) {
                        final id = g['id'] as int;
                        return CheckboxListTile(
                          value: _selectedGroupIds.contains(id),
                          title: Text(g['name']?.toString() ?? 'Group'),
                          subtitle: Text(
                            '${g['course_code'] ?? ''} · ${g['department_name'] ?? ''}',
                          ),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedGroupIds.add(id);
                              } else {
                                _selectedGroupIds.remove(id);
                              }
                            });
                          },
                        );
                      }),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dueDateController,
                      decoration: const InputDecoration(
                        labelText: 'Due date (YYYY-MM-DD)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        _file == null
                            ? 'Choose file (PDF, DOC, PPT, TXT)'
                            : _file!.path.split(Platform.pathSeparator).last,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _uploading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _uploading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Upload Assignment'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
