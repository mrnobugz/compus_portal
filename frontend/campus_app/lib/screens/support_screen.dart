import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/paginated_list_controller.dart';
import '../utils/responsive.dart';
import '../widgets/async_state_views.dart';
import '../widgets/feedback_banner.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final PaginatedListController<Map<String, dynamic>> _listController;
  bool _isSubmitting = false;
  String? _submitFeedback;
  FeedbackType? _submitFeedbackType;
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _issueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listController = PaginatedListController(
      fetchPage: (page) => ApiService.getSupportRequests(page: page),
    );
    _listController.loadInitial();
  }

  @override
  void dispose() {
    _listController.dispose();
    _subjectController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitFeedback = null;
    });

    final result = await ApiService.createSupportRequest(
      _subjectController.text.trim(),
      _issueController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      _subjectController.clear();
      _issueController.clear();
      setState(() {
        _submitFeedback =
            'Your request was submitted. Staff will reply here in the app.';
        _submitFeedbackType = FeedbackType.success;
      });
      await _listController.refresh();
    } else {
      setState(() {
        _submitFeedback = result['error']?.toString() ?? 'Failed to submit request';
        _submitFeedbackType = FeedbackType.error;
      });
    }
  }

  void _onTicketUpdated() {
    if (mounted) _listController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.of(context) == ScreenSize.expanded;
    final padding = Responsive.pagePadding(context);

    final formCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.support_agent, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'New support request',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Describe your issue. Campus staff will send a solution reply you can read here.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              if (_submitFeedback != null && _submitFeedbackType != null) ...[
                const SizedBox(height: 14),
                FeedbackBanner(
                  message: _submitFeedback!,
                  type: _submitFeedbackType!,
                  onDismiss: () => setState(() => _submitFeedback = null),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a subject';
                  }
                  if (value.trim().length < 4) {
                    return 'Subject is too short';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _issueController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Describe your issue',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe your issue';
                  }
                  if (value.trim().length < 10) {
                    return 'Please provide more detail (min 10 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSubmitting ? 'Submitting…' : 'Submit request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final listSection = AnimatedBuilder(
      animation: _listController,
      builder: (context, _) {
        if (_listController.isLoading && _listController.items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_listController.error != null && _listController.items.isEmpty) {
          return ErrorStateView(
            message: _listController.error!,
            onRetry: _listController.refresh,
          );
        }

        final unreadCount = _listController.items
            .where((r) => r['has_unread_response'] == true)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Your requests (${_listController.items.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadCount new ${unreadCount == 1 ? 'reply' : 'replies'}',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  onPressed: _listController.isLoading ? null : _listController.refresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_listController.items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No support requests yet. Submit one above.'),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _listController.items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final request = _listController.items[index];
                  return _SupportRequestCard(
                    data: request,
                    onRead: _onTicketUpdated,
                  );
                },
              ),
            if (_listController.hasMore) ...[
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _listController.isLoadingMore
                      ? null
                      : _listController.loadMore,
                  icon: _listController.isLoadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: Text(
                    _listController.isLoadingMore ? 'Loading…' : 'Load more',
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: Responsive.constrained(
        RefreshIndicator(
          onRefresh: _listController.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: formCard),
                      const SizedBox(width: 20),
                      Expanded(flex: 3, child: listSection),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      formCard,
                      const SizedBox(height: 24),
                      listSection,
                    ],
                  ),
          ),
        ),
        context,
      ),
    );
  }
}

class _SupportRequestCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRead;

  const _SupportRequestCard({required this.data, required this.onRead});

  @override
  State<_SupportRequestCard> createState() => _SupportRequestCardState();
}

class _SupportRequestCardState extends State<_SupportRequestCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.data['has_unread_response'] == true;
  }

  Future<void> _onExpanded(bool expanded) async {
    setState(() => _expanded = expanded);
    if (!expanded) return;

    final id = widget.data['id'] as int?;
    if (id == null) return;
    if (widget.data['has_unread_response'] != true) return;

    await ApiService.markSupportResponseRead(id);
    widget.onRead();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final status = data['status']?.toString() ?? 'pending';
    final created = data['created_at']?.toString().split('T').first ?? '';
    final hasResponse = data['has_staff_response'] == true ||
        (data['staff_response']?.toString().trim().isNotEmpty ?? false);
    final hasUnread = data['has_unread_response'] == true;
    final staffResponse = data['staff_response']?.toString() ?? '';
    final respondedBy = data['responded_by_name']?.toString();
    final respondedAt = data['responded_at']?.toString().split('T').first ?? '';

    return Card(
      elevation: hasUnread ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasUnread
            ? BorderSide(color: Colors.orange.shade400, width: 1.5)
            : BorderSide.none,
      ),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: _onExpanded,
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withValues(alpha: 0.15),
          child: Icon(Icons.support, color: _statusColor(status), size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                data['subject']?.toString() ?? 'Untitled',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (hasUnread)
              Container(
                margin: const EdgeInsets.only(left: 6),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              _StatusChip(status: status),
              if (hasResponse) ...[
                const SizedBox(width: 8),
                Icon(Icons.mark_chat_read, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 2),
                Text(
                  'Staff replied',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                ),
              ],
              if (created.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(created, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your message',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data['issue']?.toString() ?? '',
                  style: TextStyle(color: Colors.grey.shade800, height: 1.4),
                ),
                if (hasResponse) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings,
                                size: 18, color: Colors.green.shade800),
                            const SizedBox(width: 6),
                            Text(
                              'Staff response',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                        if (respondedBy != null || respondedAt.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              ?respondedBy,
                              if (respondedAt.isNotEmpty) respondedAt,
                            ].whereType<String>().join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          staffResponse,
                          style: TextStyle(
                            color: Colors.grey.shade900,
                            height: 1.45,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_top, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Waiting for staff. You will be notified when they reply.',
                            style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'closed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = status.replaceAll('_', ' ');
    Color color;
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'closed':
        color = Colors.green;
        break;
      case 'in_progress':
        color = Colors.orange;
        break;
      default:
        color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label[0].toUpperCase() + label.substring(1),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
