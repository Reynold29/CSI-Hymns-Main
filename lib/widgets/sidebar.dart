import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hymns_latest/category.dart';
import 'package:hymns_latest/screens/about_developer_screen.dart';
import 'package:hymns_latest/screens/auth_screen.dart';
import 'package:hymns_latest/screens/praise_app.dart';
import 'package:hymns_latest/screens/profile_edit_screen.dart';
import 'package:hymns_latest/screens/settings_screen.dart';
import 'package:hymns_latest/screens/tickets_screen.dart';
import 'package:hymns_latest/services/supabase_service.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Sidebar extends StatefulWidget {
  final AnimationController animationController;

  const Sidebar({super.key, required this.animationController});

  @override
  _SidebarState createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _categoriesExpanded = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Rebuild whenever auth state changes (sign in, sign out, account deletion)
    _authSub = SupabaseService().authStream.listen(
      (_) {
        if (mounted) setState(() {});
      },
      onError: (e) {
        if (SupabaseService.isPostDeleteAuthError(e)) return;
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = SupabaseService().currentUser;
    // Example: Assume the first ListTile (AboutApp) is the selected one for demo. You can wire this to your navigation logic.
    final int selectedIndex = 0;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Drawer(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          backgroundColor: colorScheme.surface,
          elevation: 12,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // App branding / user profile card
                            Card(
                              color: colorScheme.surfaceContainerHigh,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 18),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                        radius: 28,
                                        backgroundColor: colorScheme.primary,
                                        child: FaIcon(FontAwesomeIcons.church,
                                            size: 28,
                                            color: colorScheme.onPrimary)),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text("CSI Hymns and Lyrics",
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'plusJakartaSans',
                                                  color:
                                                      colorScheme.onSurface)),
                                          const SizedBox(height: 2),
                                          Text("Praise The Lord!",
                                              style: TextStyle(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  fontWeight: FontWeight.w400,
                                                  fontFamily:
                                                      'plusJakartaSans')),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Divider(),
                            ),
                            // Auth section
                            if (user == null) ...[
                              _sidebarTile(
                                context,
                                icon: FontAwesomeIcons.rightToBracket,
                                label: "Login / Sign up",
                                selected: false,
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const AuthScreen()),
                                  );
                                  if (mounted && result == true)
                                    setState(() {});
                                },
                                colorScheme: colorScheme,
                              ),
                            ] else ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                        radius: 16,
                                        child: Text(user.email != null &&
                                                user.email!.isNotEmpty
                                            ? user.email![0].toUpperCase()
                                            : '?')),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FutureBuilder<String?>(
                                        future:
                                            SupabaseService().getProfileName(),
                                        builder: (context, snap) {
                                          final name = snap.data;
                                          return GestureDetector(
                                            onTap: () async {
                                              final changed = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          const ProfileEditScreen()));
                                              if (changed == true && mounted)
                                                setState(() {});
                                            },
                                            child: Text(
                                              (name != null &&
                                                      name.trim().isNotEmpty)
                                                  ? name
                                                  : (user.email ?? 'Logged in'),
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.onSurface),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _sidebarTile(
                                context,
                                icon: FontAwesomeIcons.arrowRightFromBracket,
                                label: "Logout",
                                selected: false,
                                onTap: () async {
                                  await SupabaseService().signOut();
                                  if (context.mounted) Navigator.pop(context);
                                  setState(() {});
                                },
                                colorScheme: colorScheme,
                              ),
                            ],
                            const Divider(),
                            // Sidebar items
                            _sidebarTile(
                              context,
                              icon: FontAwesomeIcons.googlePlay,
                              label: "Praise and Worship App",
                              selected: selectedIndex == 0,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const PraiseAppScreen()),
                                );
                              },
                              colorScheme: colorScheme,
                            ),
                            // Categories - Collapsible
                            ExpansionTile(
                              leading: FaIcon(
                                FontAwesomeIcons.bookBible,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              title: Text(
                                "Categories",
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              initiallyExpanded: _categoriesExpanded,
                              onExpansionChanged: (expanded) {
                                setState(() {
                                  _categoriesExpanded = expanded;
                                });
                                HapticFeedbackManager.lightClick();
                              },
                              children: [
                                for (final option
                                    in SidebarOptions.getOptions(context))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16.0),
                                    child: option,
                                  ),
                              ],
                            ),
                            // Tickets Submitted section
                            _sidebarTile(
                              context,
                              icon: FontAwesomeIcons.ticket,
                              label: "Tickets Submitted",
                              selected: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const TicketsScreen()),
                                );
                              },
                              colorScheme: colorScheme,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(),
                  ),
                  // Bottom fixed actions
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: 12, left: 8, right: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _sidebarTile(
                          context,
                          icon: FontAwesomeIcons.gear,
                          label: "Settings",
                          selected: false,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SettingsScreen()),
                            );
                          },
                          colorScheme: colorScheme,
                        ),
                        _sidebarTile(
                          context,
                          icon: FontAwesomeIcons.circleUser,
                          label: "About Developer",
                          selected: false,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const AboutDeveloper()),
                            );
                          },
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// Helper for expressive sidebar tile
  Widget _sidebarTile(BuildContext context,
      {required IconData icon,
      required String label,
      required bool selected,
      required VoidCallback onTap,
      required ColorScheme colorScheme,
      Widget? trailing}) {
    return ListTile(
      leading: SizedBox(
        height: 30,
        width: 30,
        child: FaIcon(icon,
            color:
                selected ? colorScheme.primary : colorScheme.onSurfaceVariant),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? colorScheme.primary : colorScheme.onSurface,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: colorScheme.primary.withOpacity(0.10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: () async {
        await HapticFeedbackManager.lightClick();
        onTap();
      },
      trailing: trailing,
    );
  }
}
