import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  List<Map<String, dynamic>> _grades = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final grades = await ApiService.getGrades();
    if (mounted) {
      setState(() {
        _grades = grades;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final avg = _grades.isEmpty
        ? null
        : _grades
                .map((g) => (g['percentage'] as num?)?.toDouble() ?? 0)
                .reduce((a, b) => a + b) /
            _grades.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _grades.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No grades recorded yet.')),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (avg != null)
                          Card(
                            color: AppTheme.primary,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  const Icon(Icons.insights, color: Colors.white, size: 40),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Average score',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      Text(
                                        '${avg.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        ..._grades.map((g) {
                          final pct = (g['percentage'] as num?)?.toDouble() ?? 0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(
                                g['assessment']?.toString() ?? 'Assessment',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${g['course_name'] ?? 'Course'} · ${g['term'] ?? ''}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${g['score']}/${g['max_score']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text('${pct.toStringAsFixed(0)}%'),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
            ),
    );
  }
}
