import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/app_password_field.dart';
import '../widgets/feedback_banner.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentIdController = TextEditingController();

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _courses = [];
  int? _departmentId;
  int? _courseId;
  bool _loadingOptions = true;
  String? _loadError;
  String? _feedback;
  FeedbackType? _feedbackType;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _loadError = null;
    });
    try {
      final departments = await ApiService.getDepartments();
      if (!mounted) return;
      setState(() {
        _departments = departments;
        _loadingOptions = false;
        if (departments.isEmpty) {
          _loadError = 'Could not load departments. Check your connection and try again.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingOptions = false;
          _loadError = 'Failed to load registration options.';
        });
      }
    }
  }

  Future<void> _loadCourses(int departmentId) async {
    setState(() => _courses = []);
    final courses = await ApiService.getCourses(departmentId: departmentId);
    if (!mounted) return;
    setState(() {
      _courses = courses;
      _courseId = courses.isNotEmpty ? courses.first['id'] as int? : null;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_departmentId == null || _courseId == null) {
      setState(() {
        _feedback = 'Please select your department and course.';
        _feedbackType = FeedbackType.error;
      });
      return;
    }

    setState(() {
      _feedback = null;
      _feedbackType = null;
    });

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      studentId: _studentIdController.text.trim(),
      departmentId: _departmentId!,
      courseId: _courseId!,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      await showSuccessDialog(
        context,
        title: 'Account created',
        message:
            'Welcome to Campus Portal! Your account is ready and you are now signed in.',
      );
    } else {
      setState(() {
        _feedback = auth.errorMessage ?? 'Registration failed. Please try again.';
        _feedbackType = FeedbackType.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: Responsive.pagePadding(context),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade500),
                        const SizedBox(height: 12),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _loadOptions, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: Responsive.pagePadding(context),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Join Campus Portal',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fill in your details to register as a student.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        if (_feedback != null && _feedbackType != null) ...[
                          FeedbackBanner(
                            message: _feedback!,
                            type: _feedbackType!,
                            onDismiss: () => setState(() => _feedback = null),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _sectionTitle('Account'),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || !v.contains('@') || !v.contains('.')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        AppPasswordField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'At least 6 characters',
                          validator: (v) =>
                              v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                        ),
                        const SizedBox(height: 12),
                        AppPasswordField(
                          controller: _confirmPasswordController,
                          label: 'Confirm password',
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle('Student details'),
                        TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First name',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last name',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _studentIdController,
                          decoration: const InputDecoration(
                            labelText: 'Student ID',
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Student ID is required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _departmentId,
                          decoration: const InputDecoration(
                            labelText: 'Department',
                            prefixIcon: Icon(Icons.apartment_outlined),
                          ),
                          items: _departments
                              .map(
                                (d) => DropdownMenuItem<int>(
                                  value: d['id'] as int,
                                  child: Text(d['name'] as String),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _departmentId = value;
                              _courseId = null;
                              _courses = [];
                            });
                            if (value != null) _loadCourses(value);
                          },
                          validator: (v) => v == null ? 'Select a department' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _courseId,
                          decoration: InputDecoration(
                            labelText: 'Course',
                            prefixIcon: const Icon(Icons.menu_book_outlined),
                            hintText: _departmentId == null
                                ? 'Select department first'
                                : null,
                          ),
                          items: _courses
                              .map(
                                (c) => DropdownMenuItem<int>(
                                  value: c['id'] as int,
                                  child: Text(c['name'] as String),
                                ),
                              )
                              .toList(),
                          onChanged: _departmentId == null
                              ? null
                              : (value) => setState(() => _courseId = value),
                          validator: (v) => v == null ? 'Select a course' : null,
                        ),
                        const SizedBox(height: 28),
                        FilledButton.icon(
                          onPressed: auth.isBusy ? null : _register,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: auth.isBusy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.person_add),
                          label: Text(
                            auth.isBusy ? 'Creating account…' : 'Create account',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: auth.isBusy ? null : () => Navigator.pop(context),
                          child: const Text('Already have an account? Sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}
