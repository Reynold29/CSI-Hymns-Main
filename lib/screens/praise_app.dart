import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PraiseAppScreen extends StatelessWidget {
  const PraiseAppScreen({super.key});

  Future<void> _launchPlayStore() async {
    final Uri url = Uri.parse(
        "https://play.google.com/store/apps/details?id=com.reyzie.worshipcompanion");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  Future<void> _launchAppStore() async {
    final Uri url =
        Uri.parse("https://apps.apple.com/in/app/worship-companion/id6759990066");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text("Worship Companion"),
            centerTitle: true,
            expandedHeight: 280,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.queue_music_rounded,
                          size: 72,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Your All-in-One Lyrics App",
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Worship Companion is your all-in-one praise and worship lyrics app, crafted especially for Christian believers and worship leaders. Whether you're at church, in a prayer meeting, or just worshiping at home, Worship Companion helps you stay spiritually connected with quick access to your favorite songs.",
                    style: textTheme.bodyLarge
                        ?.copyWith(height: 1.5, color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Icon(Icons.stars_rounded, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        "Key Features",
                        style: textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Feature 1
                  _buildFeatureCard(context,
                      icon: Icons.cloud_off_rounded,
                      title: "Offline Lyrics Database",
                      description:
                          "Access a wide collection of Christian praise and worship songs even without internet. Songs are stored securely on your device."),
                  // Feature 2
                  _buildFeatureCard(context,
                      icon: Icons.lock_outline_rounded,
                      title: "Encrypted Local Storage",
                      description:
                          "Your data is never shared. Everything is stored locally and securely with advanced encryption."),
                  // Feature 3
                  _buildFeatureCard(context,
                      icon: Icons.document_scanner_rounded,
                      title: "Camera & Gallery Integration",
                      description:
                          "Scan physical songbooks or import images from your gallery to extract lyrics using AI (powered by Gemini)."),
                  // Feature 4
                  _buildFeatureCard(context,
                      icon: Icons.auto_awesome_rounded,
                      title: "Gemini AI-Powered Scanning",
                      description:
                          "Easily convert text from images or camera scans into editable worship lyrics with on-device AI—fast, private, and powerful."),
                  // Feature 5
                  _buildFeatureCard(context,
                      icon: Icons.person_outline_rounded,
                      title: "User Profile (Stored Locally)",
                      description:
                          "Customize your experience by adding your name and profile picture—stored only on your phone, never shared to cloud."),
                  // Feature 6
                  _buildFeatureCard(context,
                      icon: Icons.sync_rounded,
                      title: "Internet Access for Updates Only",
                      description:
                          "Worship Companion uses the internet only to download song updates—no personal data is ever sent or tracked."),
                  // Feature 7
                  _buildFeatureCard(context,
                      icon: Icons.spa_rounded,
                      title: "Simple & Spirit-Filled Interface",
                      description:
                          "Designed with prayerful attention to usability—lightweight, distraction-free, and built to help you focus on worship."),

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.music_note_rounded,
                            size: 32, color: colorScheme.onSecondaryContainer),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            "Whether you're a worship leader, musician, or a devoted believer, Worship Companion is designed to uplift your faith and simplify your worship experience.",
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 180), // padding for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: _launchPlayStore,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const FaIcon(FontAwesomeIcons.googlePlay, size: 20),
              label: const Text(
                "Download on Google Play",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _launchAppStore,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: BorderSide(color: colorScheme.outline.withAlpha(100)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const FaIcon(FontAwesomeIcons.apple, size: 20),
              label: const Text(
                "Download on App Store",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String description}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
