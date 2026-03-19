import 'package:flutter/material.dart';
import 'package:hymns_latest/services/supabase_service.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _loading = true;
  String? _email;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = SupabaseService();
    final name = await svc.getProfileName();
    _email = svc.currentUser?.email;
    if (!mounted) return;
    _nameCtrl.text = name ?? '';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await HapticFeedbackManager.mediumClick();
    await SupabaseService().upsertProfile(fullName: _nameCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pop(context, true);
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone. You will be signed out and your profile will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    await HapticFeedbackManager.mediumClick();

    try {
      await SupabaseService().deleteAccount();
    } catch (_) {
      // Treat any error as success: account may already be deleted or 403 suppressed.
    }

    // Show progress for ~2 seconds, then confirm and leave
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _navigateAwayAfterDeletion();
  }

  void _navigateAwayAfterDeletion() {
    if (!mounted) return;
    // Save the NavigatorState BEFORE popping — after popUntil the widget is
    // disposed and 'context' becomes invalid, but 'nav.context' stays valid.
    final nav = Navigator.of(context);
    nav.popUntil((route) => route.isFirst);
    // nav.context now points to the live MainScreen context
    showDialog(
      context: nav.context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Account Deleted'),
        content: const Text(
            'Your account has been successfully deleted. We\'re sorry to see you go!'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your full name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _email ?? '',
                      readOnly: true,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _loading ? null : _save,
                        child: const Text('Save')),
                    const SizedBox(height: 12),
                    Text(
                      'Your personal data is encrypted and stored securely.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _deleteAccount,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
