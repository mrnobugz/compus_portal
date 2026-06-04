import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/feedback_banner.dart';
import 'change_password_screen.dart';
import 'server_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  final bool embedInShell;

  const ProfileScreen({super.key, this.embedInShell = false});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Could not load profile'))
          : Responsive.constrained(
              RefreshIndicator(
                onRefresh: auth.refreshUser,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: padding,
                  child: Column(
                    children: [
                      _ProfileHeader(user: user, onPhotoUpdated: auth.refreshUser),
                      const SizedBox(height: 16),
                      _DetailsCard(user: user),
                      const SizedBox(height: 16),
                      _SettingsCard(user: user, onUpdated: auth.refreshUser),
                      if (user['groups'] is List &&
                          (user['groups'] as List).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _GroupsCard(groups: user['groups'] as List),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: auth.isBusy ? null : () => auth.logout(),
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              context,
            ),
    );
  }
}

class _ProfileHeader extends StatefulWidget {
  final Map<String, dynamic> user;
  final Future<void> Function() onPhotoUpdated;

  const _ProfileHeader({required this.user, required this.onPhotoUpdated});

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  bool _uploading = false;

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _uploading = true);
    final upload = await ApiService.uploadProfilePicture(
      File(result.files.single.path!),
    );
    if (mounted) {
      setState(() => _uploading = false);
      if (upload['success'] == true) {
        await widget.onPhotoUpdated();
        if (mounted) {
          showAppSnackBar(context, message: 'Profile photo updated', success: true);
        }
      } else {
        showAppSnackBar(
          context,
          message: upload['error']?.toString() ?? 'Upload failed',
          success: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = ApiService.resolveMediaUrl(
      widget.user['profile_picture_url']?.toString(),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? const Icon(Icons.person, size: 48, color: AppTheme.primary)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton.filled(
                    onPressed: _uploading ? null : _pickPhoto,
                    tooltip: 'Change photo',
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.user['username']?.toString() ?? 'Student',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.user['email'] != null)
              Text(
                widget.user['email'].toString(),
                style: const TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _uploading ? null : _pickPhoto,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Change profile photo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Future<void> Function() onUpdated;

  const _SettingsCard({required this.user, required this.onUpdated});

  Future<void> _editProfile(BuildContext context) async {
    final firstNameController = TextEditingController(text: user['first_name']?.toString() ?? '');
    final lastNameController = TextEditingController(text: user['last_name']?.toString() ?? '');
    final emailController = TextEditingController(text: user['email']?.toString() ?? '');
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null) ...[
                  FeedbackBanner(message: error!, type: FeedbackType.error),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final result = await ApiService.updateProfile(
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  email: emailController.text.trim(),
                );
                if (result['success'] == true) {
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } else {
                  setDialogState(() => error = result['error']?.toString());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();

    if (saved == true && context.mounted) {
      await onUpdated();
      if (context.mounted) {
        showAppSnackBar(context, message: 'Profile updated', success: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AppTheme.primary),
            title: const Text('Edit profile'),
            subtitle: const Text('Update name and email'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editProfile(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_reset, color: AppTheme.primary),
            title: const Text('Change password'),
            subtitle: const Text('Update your account password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.dns, color: AppTheme.primary),
            title: const Text('Server settings'),
            subtitle: const Text('Set backend URL for physical device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _DetailsCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _row('Department', user['department']),
            _row('Course', user['course']),
            _row('Student ID', user['student_id']),
            _row('Name', '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()),
            _row('Role', user['is_lecturer'] == true ? 'Lecturer' : 'Student'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
          Expanded(
            child: Text(
              value?.toString().isNotEmpty == true ? value.toString() : '—',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupsCard extends StatelessWidget {
  final List groups;

  const _GroupsCard({required this.groups});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Study groups',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ...groups.map(
              (g) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.groups, color: AppTheme.primary),
                title: Text(g['name']?.toString() ?? 'Group'),
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
