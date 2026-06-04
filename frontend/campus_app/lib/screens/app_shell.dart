import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/shell_navigation_provider.dart';
import '../services/notification_service.dart';
import '../utils/responsive.dart';
import 'home_tab.dart';
import 'notes_screen.dart';
import 'assignments_screen.dart';
import 'my_groups_screen.dart';
import 'profile_screen.dart';
import 'lecturer_upload_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    NotificationService.startPolling();
  }

  @override
  void dispose() {
    NotificationService.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ShellNavigationProvider>(
      builder: (context, auth, nav, _) {
        final isWide = Responsive.of(context) != ScreenSize.compact;

        final tabs = <_TabSpec>[
          _TabSpec(Icons.home_outlined, Icons.home, 'Home', const HomeTab()),
          _TabSpec(
            Icons.menu_book_outlined,
            Icons.menu_book,
            'Notes',
            const NotesScreen(embedInShell: true),
          ),
          _TabSpec(
            Icons.assignment_outlined,
            Icons.assignment,
            'Tasks',
            const AssignmentsScreen(embedInShell: true),
          ),
          _TabSpec(
            Icons.groups_outlined,
            Icons.groups,
            'Groups',
            const MyGroupsScreen(embedInShell: true),
          ),
          if (auth.isLecturer)
            _TabSpec(
              Icons.upload_file_outlined,
              Icons.upload_file,
              'Upload',
              const LecturerUploadScreen(embedInShell: true),
            ),
          _TabSpec(
            Icons.person_outline,
            Icons.person,
            'Profile',
            const ProfileScreen(embedInShell: true),
          ),
        ];

        final index = nav.index.clamp(0, tabs.length - 1);

        final body = IndexedStack(
          index: index,
          children: tabs.map((t) => t.body).toList(),
        );

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: nav.goTo,
                  labelType: NavigationRailLabelType.all,
                  destinations: tabs
                      .map(
                        (t) => NavigationRailDestination(
                          icon: Icon(t.icon),
                          selectedIcon: Icon(t.selectedIcon),
                          label: Text(t.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: nav.goTo,
            destinations: tabs
                .map(
                  (t) => NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: t.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _TabSpec {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget body;

  _TabSpec(this.icon, this.selectedIcon, this.label, this.body);
}
