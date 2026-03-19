import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hymns_latest/theme_state.dart';
import 'package:hymns_latest/widgets/update_check.dart';
import 'package:hymns_latest/screens/changelog_screen.dart';
import 'package:hymns_latest/screens/about_app.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';
import 'package:hymns_latest/services/christmas_mode_service.dart';
import 'package:hymns_latest/services/christmas_carols_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isCheckingForUpdate = false; // Added loading state for update check

  @override
  Widget build(BuildContext context) {
    final themeState = Provider.of<ThemeState>(context);
    // Determine the current visual theme status for the toggle
    bool currentVisualIsDark;
    if (themeState.themeMode == ThemeMode.system) {
      currentVisualIsDark =
          MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    } else {
      currentVisualIsDark = themeState.themeMode == ThemeMode.dark;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 18.0),
          children: <Widget>[
            _buildSectionHeader(
                context, 'Appearance', FontAwesomeIcons.palette),
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      value: currentVisualIsDark,
                      onChanged: (bool value) {
                        HapticFeedbackManager.lightClick();
                        themeState.setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light);
                      },
                      secondary: Icon(currentVisualIsDark
                          ? FontAwesomeIcons.solidMoon
                          : FontAwesomeIcons.moon),
                      activeColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    if (currentVisualIsDark)
                      SwitchListTile(
                        title: const Text('AMOLED Black Mode'),
                        subtitle: const Text(
                            'Uses true black for dark theme backgrounds'),
                        value: themeState.blackThemeEnabled,
                        onChanged: (bool value) {
                          HapticFeedbackManager.lightClick();
                          themeState.setBlackThemeEnabled(value);
                        },
                        secondary: const Icon(FontAwesomeIcons.paintRoller),
                        activeColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ListTile(
                      title: const Text('Theme Color'),
                      subtitle:
                          const Text('Tap to change the app\'s primary color'),
                      trailing: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: themeState.seedColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                            width: 2,
                          ),
                        ),
                      ),
                      onTap: () {
                        HapticFeedbackManager.lightClick();
                        _showColorPickerDialog(context, themeState);
                      },
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ],
                ),
              ),
            ),
            _buildSectionHeader(
                context, 'Special Features', FontAwesomeIcons.star),
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Consumer<ChristmasModeService>(
                  builder: (context, christmasService, _) {
                    return SwitchListTile(
                      title: const Row(
                        children: [
                          Text('🎄 '),
                          Text('Christmas Mode'),
                        ],
                      ),
                      subtitle: const Text(
                        'Enable festive theme and Christmas carols section',
                      ),
                      value: christmasService.isChristmasTime,
                      onChanged: (bool value) async {
                        await HapticFeedbackManager.lightClick();
                        await christmasService.setChristmasMode(value);
                      },
                      secondary: Icon(
                        FontAwesomeIcons.snowflake,
                        color: christmasService.isChristmasTime
                            ? const Color(0xFFB22222)
                            : null,
                      ),
                      activeColor: const Color(0xFFB22222),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    );
                  },
                ),
              ),
            ),
            _buildSectionHeader(
                context, 'App Information', FontAwesomeIcons.circleInfo),
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(FontAwesomeIcons.cloudArrowDown),
                      title: const Text('Check for Updates'),
                      enabled: !_isCheckingForUpdate,
                      onTap: _isCheckingForUpdate
                          ? null
                          : () async {
                              HapticFeedbackManager.lightClick();
                              setState(() {
                                _isCheckingForUpdate = true;
                              });
                              try {
                                final updateManager = UpdateManager();
                                await updateManager.checkForUpdates(context);
                              } finally {
                                setState(() {
                                  _isCheckingForUpdate = false;
                                });
                              }
                            },
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    ListTile(
                      leading: const Icon(FontAwesomeIcons.scroll),
                      title: const Text('What\'s New? (Changelog)'),
                      onTap: () {
                        HapticFeedbackManager.lightClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ChangelogScreen()),
                        );
                      },
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    ListTile(
                      leading: const Icon(FontAwesomeIcons.book),
                      title: const Text('About App'),
                      onTap: () {
                        HapticFeedbackManager.lightClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AboutApp()),
                        );
                      },
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showColorPickerDialog(
      BuildContext context, ThemeState themeState) async {
    Color newColor = themeState.seedColor;

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Choose Theme Color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              color: newColor,
              onColorChanged: (Color color) {
                newColor = color;
              },
              pickersEnabled: const <ColorPickerType, bool>{
                ColorPickerType.both: false,
                ColorPickerType.primary: true,
                ColorPickerType.accent: true,
                ColorPickerType.bw: false,
                ColorPickerType.custom: false,
                ColorPickerType.wheel: true,
              },
              enableShadesSelection: true,
              width: 40,
              height: 40,
              borderRadius: 20,
              spacing: 5,
              runSpacing: 5,
              wheelDiameter: 165,
              showMaterialName: true,
              showColorName: true,
              showColorCode: true,
              copyPasteBehavior: const ColorPickerCopyPasteBehavior(
                longPressMenu: true,
              ),
              actionButtons: const ColorPickerActionButtons(
                okButton: true,
                closeButton: true,
                dialogActionButtons: false, // Using AlertDialog actions
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Optionally revert color if needed, though current setup updates live
                // themeState.setSeedColor(colorBeforeDialog);
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                themeState.setSeedColor(newColor);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRemoteJsonDialog(
      BuildContext context, ChristmasCarolsService service) async {
    final currentUrl = await service.getRemoteJsonUrl();
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString('remote_carols_json_url');
    final isUsingDefault = customUrl == null || customUrl.isEmpty;

    final urlController = TextEditingController(
        text:
            isUsingDefault ? service.defaultRemoteJsonUrl : (currentUrl ?? ''));

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remote JSON URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUsingDefault
                  ? 'Currently using the default remote JSON URL. You can change it below.\n\n'
                      'The app will fetch and cache this file (refreshes every 24 hours).\n\n'
                      'Example: https://raw.githubusercontent.com/user/repo/carols.json'
                  : 'Enter a URL to a JSON file containing Christmas carols.\n\n'
                      'The app will fetch and cache this file (refreshes every 24 hours).\n\n'
                      'Example: https://raw.githubusercontent.com/user/repo/carols.json',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'JSON URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (!isUsingDefault)
            TextButton(
              onPressed: () async {
                await service.setRemoteJsonUrl(null);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        duration: const Duration(milliseconds: 1500),
                        content: Text('Reverted to default remote JSON URL')),
                  );
                  // Refresh carols
                  await service.loadAllCarols();
                }
              },
              child: const Text('Use Default',
                  style: TextStyle(color: Colors.blue)),
            ),
          FilledButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) {
                await service.setRemoteJsonUrl(null);
              } else {
                // Validate URL
                try {
                  final uri = Uri.parse(url);
                  if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            duration: const Duration(milliseconds: 1500),
                            content:
                                Text('Please enter a valid HTTP/HTTPS URL')),
                      );
                    }
                    return;
                  }
                  await service.setRemoteJsonUrl(url);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          duration: const Duration(milliseconds: 1500),
                          content: Text('Invalid URL: $e')),
                    );
                  }
                  return;
                }
              }

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    duration: const Duration(milliseconds: 1500),
                    content: Text(url.isEmpty
                        ? 'Remote JSON URL removed'
                        : 'Remote JSON URL set. Refreshing...'),
                  ),
                );
                // Refresh carols
                await service.loadAllCarols();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _importJsonFile(
      BuildContext context, ChristmasCarolsService service) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                duration: const Duration(milliseconds: 1500),
                content: Text('Could not access the file')),
          );
        }
        return;
      }

      // Show loading
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Importing JSON...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      try {
        final imported = await service.importFromJsonFile(file.path!);

        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              duration: const Duration(milliseconds: 1500),
              content:
                  Text('Imported ${imported.length} carol(s) successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                duration: const Duration(milliseconds: 1500),
                content: Text('Import failed: $e')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _exportJsonFile(
      BuildContext context, ChristmasCarolsService service) async {
    try {
      // Show loading
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Exporting JSON...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      try {
        final filePath = await service.exportToJsonFile();

        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Exported to: $filePath'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                duration: const Duration(milliseconds: 1500),
                content: Text('Export failed: $e')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text('Error: $e')),
        );
      }
    }
  }
}
