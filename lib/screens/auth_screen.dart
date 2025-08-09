import 'package:flutter/material.dart';
import 'package:hymns_latest/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hymns_latest/screens/auth_email_screen.dart';
import 'package:hymns_latest/screens/profile_edit_screen.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  StreamSubscription<AuthState>? _authSub;

  final SupabaseService _supabase = SupabaseService();

  @override
  void initState() {
    super.initState();
    // Close this screen automatically when auth completes (e.g., Google OAuth deep link returns)
    _authSub = _supabase.authStream.listen((state) async {
      if (!mounted) return;
      if (state.session != null) {
        // On login, refresh favorites owner marker to avoid cross-account merge
        SharedPreferences.getInstance().then((prefs) async {
          await prefs.setString('favorites_owner_auth_uid', state.session!.user.id);
        });
        // If profile name is missing, collect it before closing
        final name = await _supabase.getProfileName();
        if (!mounted) return;
        if (name == null || name.trim().isEmpty) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
        }
        if (mounted) Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Email submit handled in AuthEmailScreen

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await HapticFeedbackManager.lightClick();
      await _supabase.signInWithGoogle();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign-in error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(Icons.favorite, color: colorScheme.primary, size: 32),
                      ),
                      const SizedBox(height: 14),
                      Text('CSI Hymns Book', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to sync your Favorite Hymns across devices and reinstalls.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _signInWithGoogle,
                            icon: const FaIcon(FontAwesomeIcons.google, size: 18),
                            label: const Text('Continue with Google'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : () async {
                                    await HapticFeedbackManager.lightClick();
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const AuthEmailScreen()),
                                    );
                                    if (mounted && result == true) Navigator.pop(context, true);
                                  },
                            icon: const Icon(Icons.email_outlined),
                            label: const Text('Use email instead'),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'By continuing, you agree that your favorites will be stored securely with your account so they persist across reinstall and device changes.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
      ),
    );
  }
}


