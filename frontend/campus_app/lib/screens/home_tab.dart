import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/shell_navigation_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/responsive_action_grid.dart';
import 'attendance_screen.dart';
import 'books_screen.dart';
import 'grades_screen.dart';
import 'help_assistant_screen.dart';
import 'support_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _announcements = [];
  bool _loadingExtras = true;

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    final summary = await ApiService.getDashboardSummary();
    final announcements = await ApiService.getAnnouncements();
    if (mounted) {
      setState(() {
        _summary = summary;
        _announcements = announcements.take(3).toList();
        _loadingExtras = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _loadingExtras = true);
    await context.read<AuthProvider>().refreshUser();
    await _loadExtras();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final padding = Responsive.pagePadding(context);
    final nav = context.read<ShellNavigationProvider>();

    if (user == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => auth.refreshUser(),
            child: const Text('Reload profile'),
          ),
        ),
      );
    }

    final actions = <ActionItem>[
      ActionItem(icon: Icons.menu_book, title: 'Course Notes', onTap: () => nav.goTo(1)),
      ActionItem(icon: Icons.assignment, title: 'Assignments', onTap: () => nav.goTo(2)),
      ActionItem(icon: Icons.groups, title: 'My Groups', onTap: () => nav.goTo(3)),
      ActionItem(
        icon: Icons.library_books,
        title: 'Library',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BooksScreen()),
        ),
      ),
      ActionItem(
        icon: Icons.insights,
        title: 'Performance',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GradesScreen()),
        ),
      ),
      ActionItem(
        icon: Icons.event_available,
        title: 'Attendance',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AttendanceScreen()),
        ),
      ),
      ActionItem(
        icon: Icons.support_agent,
        title: 'Support',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SupportScreen()),
        ),
      ),
      ActionItem(
        icon: Icons.smart_toy_outlined,
        title: 'Assistant',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HelpAssistantScreen()),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: auth.isBusy ? null : _refresh,
          ),
        ],
      ),
      body: Responsive.constrained(
        RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WelcomeCard(user: user),
                if (!_loadingExtras) ...[
                  const SizedBox(height: 16),
                  _StatsRow(summary: _summary),
                ],
                if (_announcements.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Announcements',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ..._announcements.map((a) => _AnnouncementCard(data: a)),
                ],
                const SizedBox(height: 24),
                Text(
                  'Quick access',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ResponsiveActionGrid(items: actions),
              ],
            ),
          ),
        ),
        context,
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _StatsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatChip(
        icon: Icons.assignment,
        label: 'Due soon',
        value: '${summary['upcoming_assignments'] ?? 0}',
      ),
      _StatChip(
        icon: Icons.grade,
        label: 'Avg grade',
        value: summary['average_grade'] != null
            ? '${summary['average_grade']}%'
            : '—',
      ),
      _StatChip(
        icon: Icons.event_available,
        label: 'Attendance',
        value: summary['attendance_rate'] != null
            ? '${summary['attendance_rate']}%'
            : '—',
      ),
    ];

    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: item,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AnnouncementCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final urgent = data['priority'] == 'urgent';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: urgent ? Colors.orange.shade50 : null,
      child: ListTile(
        leading: Icon(
          urgent ? Icons.campaign : Icons.info_outline,
          color: urgent ? Colors.orange : AppTheme.primary,
        ),
        title: Text(
          data['title']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(data['body']?.toString() ?? ''),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _WelcomeCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryLight, AppTheme.accent],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user['username'] ?? 'Student'}!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (user['department'] != null) ...[
              const SizedBox(height: 6),
              Text(
                user['department'].toString(),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            if (user['course'] != null)
              Text(
                user['course'].toString(),
                style: const TextStyle(color: Colors.white70),
              ),
            if (user['student_id'] != null)
              Text(
                'ID: ${user['student_id']}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}
