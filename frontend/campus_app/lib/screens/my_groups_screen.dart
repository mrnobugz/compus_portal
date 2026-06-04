import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/async_state_views.dart';

class MyGroupsScreen extends StatefulWidget {
  final bool embedInShell;

  const MyGroupsScreen({super.key, this.embedInShell = false});

  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> {
  List<dynamic> _groups = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await ApiService.getMyGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.gridColumns(context, max: 2);

    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null) {
      body = ErrorStateView(message: _error!, onRetry: _load);
    } else if (_groups.isEmpty) {
      body = const EmptyStateView(
        message: 'You are not in any study group yet.\nGroups match your department and course.',
        icon: Icons.groups_outlined,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final spacing = 12.0;
            final itemWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: Responsive.pagePadding(context),
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _groups.map((g) {
                  return SizedBox(
                    width: itemWidth.clamp(160, constraints.maxWidth),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.primary,
                                  child: const Icon(Icons.groups, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    g['name']?.toString() ?? 'Group',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${g['course_code'] ?? ''} · ${g['course_name'] ?? ''}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              g['department_name']?.toString() ?? '',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            if (g['lecturer_name'] != null)
                              Text(
                                'Lecturer: ${g['lecturer_name']}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Groups')),
      body: body,
    );
  }
}
