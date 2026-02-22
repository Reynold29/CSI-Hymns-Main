import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateManager {
  Future<void> checkForUpdates(BuildContext context) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Initiate flexible update flow
        try {
          await InAppUpdate.startFlexibleUpdate();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Update downloaded. Restart the app to apply."),
                action: SnackBarAction(
                  label: 'RESTART',
                  onPressed: () async {
                    await InAppUpdate.completeFlexibleUpdate();
                  },
                ),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Update check completed. Please update from Play Store.")),
            );
          }
        }
      } else {
        // Already up to date or no update available
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You're on the latest version!")),
          );
        }
      }
    } catch (e) {
      // Silently handle errors - in-app updates only work for Play Store installs
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Update check unavailable. Please check Play Store for updates.")),
        );
      }
    }
  }
}
