import 'package:flutter/material.dart';
import 'package:hymns_latest/category.dart';
import 'package:hymns_latest/screens/about_app.dart';
import 'package:hymns_latest/screens/praise_app.dart';
import 'package:hymns_latest/screens/settings_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hymns_latest/screens/about_developer_screen.dart';
import 'dart:ui';

class Sidebar extends StatefulWidget {
  final AnimationController animationController;

  const Sidebar({super.key, required this.animationController});

  @override
  _SidebarState createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _showOptions = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
          backgroundColor: colorScheme.surface.withOpacity(0.85),
          elevation: 12,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App branding / user profile card
                      Card(
                        color: colorScheme.primaryContainer,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: colorScheme.primary,
                                child: FaIcon(
                                  FontAwesomeIcons.church,
                                  size: 28,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "CSI Hymns and Lyrics",
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'plusJakartaSans', color: colorScheme.onPrimaryContainer),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Praise The Lord!",
                                      style: TextStyle(
                                        color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                                        fontWeight: FontWeight.w400,
                                        fontFamily: 'plusJakartaSans',
                                      ),
                                    ),
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
                      // Sidebar items
                      _sidebarTile(
                        context,
                        icon: FontAwesomeIcons.googlePlay,
                        label: "Praise and Worship App",
                        selected: selectedIndex == 0,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PraiseAppScreen()),
                          );
                        },
                        colorScheme: colorScheme,
                      ),
                      _sidebarTile(
                        context,
                        icon: FontAwesomeIcons.bookBible,
                        label: "Categories",
                        selected: selectedIndex == 1,
                        onTap: () {
                          setState(() {
                            _showOptions = !_showOptions;
                          });
                        },
                        colorScheme: colorScheme,
                        trailing: Icon(
                          _showOptions ? Icons.expand_less : Icons.expand_more,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (_showOptions) ...SidebarOptions.getOptions(context).map((option) =>
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: option,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      _sidebarTile(
                        context,
                        icon: FontAwesomeIcons.gear,
                        label: "Settings",
                        selected: selectedIndex == 2,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        },
                        colorScheme: colorScheme,
                      ),
                      _sidebarTile(
                        context,
                        icon: FontAwesomeIcons.circleUser,
                        label: "About Developer",
                        selected: selectedIndex == 3,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AboutDeveloper()),
                          );
                        },
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

// Helper for expressive sidebar tile
Widget _sidebarTile(BuildContext context, {required IconData icon, required String label, required bool selected, required VoidCallback onTap, required ColorScheme colorScheme, Widget? trailing}) {
  return ListTile(
    leading: SizedBox(
      height: 30,
      width: 30,
      child: FaIcon(icon, color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant),
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
    onTap: onTap,
    trailing: trailing,
  );
}}