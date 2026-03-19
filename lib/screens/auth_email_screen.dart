import 'package:flutter/material.dart';
import 'package:hymns_latest/services/supabase_service.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';

class AuthEmailScreen extends StatefulWidget {
  const AuthEmailScreen({super.key});

  @override
  State<AuthEmailScreen> createState() => _AuthEmailScreenState();
}

class _AuthEmailScreenState extends State<AuthEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  bool _hidePassword = true;

  final SupabaseService _supabase = SupabaseService();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await HapticFeedbackManager.lightClick();
      if (_isLogin) {
        await _supabase.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await _supabase.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        await _supabase.upsertProfile(fullName: _nameController.text.trim());
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('invalid login') ||
          message.contains('invalid_credentials') ||
          message.contains('email not confirmed')) {
        _showErrorDialog('Incorrect email or password');
      } else if (message.contains('password')) {
        _showErrorDialog('Incorrect password');
      } else {
        _showErrorDialog('Authentication error: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign in problem'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _forgotPassword();
            },
            child: const Text('Forgot password'),
          ),
        ],
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text('Enter your email first')));
      return;
    }
    try {
      await _supabase.sendPasswordResetEmail(email);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password reset'),
          content: Text('We sent a reset link to $email'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            )
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text('Reset failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(_isLogin ? 'Login with Email' : 'Sign up with Email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email)),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                if (!_isLogin) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                      'Use your full name. You will use email to log in. Your personal data is encrypted and never shared.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(_hidePassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                    ),
                  ),
                  obscureText: _hidePassword,
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(_isLogin ? 'Login' : 'Create account'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin
                      ? 'No account? Sign up'
                      : 'Have an account? Login'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _forgotPassword,
                    child: Text('Forgot password?',
                        style: TextStyle(color: colorScheme.primary)),
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
