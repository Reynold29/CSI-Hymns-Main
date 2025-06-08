import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateManager {
  Future<void> checkForUpdates(BuildContext context) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Initiate flexible update flow
        await InAppUpdate.startFlexibleUpdate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update downloaded. Restart the app to apply."),
          action: SnackBarAction(
            label: 'RESTART',
            onPressed: () async {
              await InAppUpdate.completeFlexibleUpdate();
            },
          ),
          ),
        );
      } else {
        // Already up to date or no update available
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're on the latest version!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking for update: $e')),
      );
    }
  }
}
