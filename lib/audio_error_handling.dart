import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AudioErrorDialog extends StatelessWidget {
  final int itemNumber;
  final String itemType;
  final String? songTitle;

  const AudioErrorDialog({
    super.key,
    required this.itemNumber,
    required this.itemType,
    this.songTitle,
  });

  Future<void> _showAudioSubmissionDialog(BuildContext context) async {
    String? selectedFilePath;
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Submit Audio File',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please select an audio file to submit. Audio file is required.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.audio,
                          allowMultiple: false,
                        );
                        if (result != null && result.files.single.path != null) {
                          // Use path for file system access, or path for content URIs
                          selectedFilePath = result.files.single.path ?? result.files.single.path;
                          debugPrint('AudioErrorDialog: Selected file path: $selectedFilePath');
                          setDialogState(() {});
                        }
                      },
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        selectedFilePath == null
                            ? 'Select Audio File'
                            : 'File: ${selectedFilePath!.split('/').last}',
                      ),
                    ),
                    if (selectedFilePath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Selected: ${selectedFilePath!.split('/').last}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Additional notes (optional)',
                        border: OutlineInputBorder(),
                        labelText: 'Description (Optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context, null),
                ),
                FilledButton(
                  onPressed: selectedFilePath == null
                      ? null
                      : () => Navigator.pop(context, {
                            'action': 'send',
                            'filePath': selectedFilePath!,
                            'description': descriptionController.text.trim(),
                          }),
                  child: const Text('Send Email'),
                ),
              ],
            );
          },
        );
      },
    );

    debugPrint('AudioErrorDialog: Dialog result: $result');
    
    if (result != null && result['action'] == 'send' && result['filePath'] != null) {
      debugPrint('AudioErrorDialog: Calling _sendAudioEmail with file: ${result['filePath']}');
      await _sendAudioEmail(
        context,
        result['filePath'] as String,
        result['description'] as String,
      );
    } else {
      debugPrint('AudioErrorDialog: Dialog result is null or invalid. Result: $result');
    }
  }

  Future<void> _sendAudioEmail(
    BuildContext context,
    String filePath,
    String description,
  ) async {
    debugPrint('AudioErrorDialog: _sendAudioEmail called with filePath: $filePath');
    
    try {
      debugPrint('AudioErrorDialog: Starting email preparation...');
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      final emailBody = '''
Song Information:
- Type: $itemType
- Number: $itemNumber
${songTitle != null ? '- Title: $songTitle' : ''}

App Information:
- Version: $appVersion

${description.isNotEmpty ? 'Additional Notes:\n$description\n\n' : ''}Submitted via: CSI Hymns App
''';

      final Email email = Email(
        body: emailBody,
        subject: '[$itemType] $itemNumber Audio Submission${songTitle != null ? ' - $songTitle' : ''}',
        recipients: ['support@reyziecrafts.atlassian.net'],
        attachmentPaths: [filePath],
        isHTML: false,
      );

      debugPrint('AudioErrorDialog: Attempting to open email app with attachment: $filePath');
      debugPrint('AudioErrorDialog: Email recipients: ${email.recipients}');
      debugPrint('AudioErrorDialog: Email subject: ${email.subject}');
      
      // Verify file exists (only if it's a file path, not a content URI)
      if (!filePath.startsWith('content://')) {
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('Selected file does not exist: $filePath');
        }
        debugPrint('AudioErrorDialog: File exists, size: ${await file.length()} bytes');
      } else {
        debugPrint('AudioErrorDialog: Using content URI: $filePath');
      }
      
      // Open email app - this will switch to the email app
      await FlutterEmailSender.send(email);
      
      debugPrint('AudioErrorDialog: Email app opened successfully');

      // Save pending ticket to Supabase so it shows in tickets list
      await _savePendingTicketToSupabase(
        itemType: itemType,
        itemNumber: itemNumber,
        songTitle: songTitle,
        description: description,
        appVersion: appVersion,
      );

      // Show success message when user returns to the app
      // Wait a bit for the user to potentially return to the app
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Try to show dialog - if context is not mounted, we'll catch it
      try {
        if (context.mounted) {
          _showEmailResultDialog(context, isSuccess: true);
        } else {
          debugPrint('AudioErrorDialog: Context not mounted, cannot show success dialog');
        }
      } catch (e) {
        debugPrint('AudioErrorDialog: Error showing success dialog: $e');
      }
    } catch (e, stackTrace) {
      debugPrint('AudioErrorDialog: Error opening email app: $e');
      debugPrint('AudioErrorDialog: Stack trace: $stackTrace');
      
      // Wait a bit before showing error dialog
      await Future.delayed(const Duration(milliseconds: 500));
      
      try {
        if (context.mounted) {
          _showEmailResultDialog(
            context,
            isSuccess: false,
            errorMessage: 'Error opening email app: ${e.toString()}',
          );
        } else {
          debugPrint('AudioErrorDialog: Context not mounted, cannot show error dialog');
        }
      } catch (dialogError) {
        debugPrint('AudioErrorDialog: Error showing error dialog: $dialogError');
      }
    }
  }

  void _showEmailResultDialog(
    BuildContext context, {
    required bool isSuccess,
    String? errorMessage,
  }) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EmailSendingDialog(
        status: isSuccess ? _EmailStatus.success : _EmailStatus.failure,
        errorMessage: errorMessage,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  /// Saves a pending ticket to Supabase for audio submissions
  /// This allows the ticket to appear in the tickets list even before Jira creates it
  Future<void> _savePendingTicketToSupabase({
    required String itemType,
    required int itemNumber,
    String? songTitle,
    String? description,
    required String appVersion,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      // Get or create device ID for unregistered users
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString('device_id', deviceId);
      }
      
      // Generate a placeholder ticket key (will be updated when actual ticket is created)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final placeholderKey = 'PENDING-${itemType.toUpperCase()}-$itemNumber-$timestamp';
      
      // Use a placeholder URL (will be updated when actual ticket is created)
      final placeholderUrl = 'https://reyziecrafts.atlassian.net/browse/$placeholderKey';
      
      await supabase.from('jira_tickets').insert({
        'ticket_key': placeholderKey,
        'ticket_url': placeholderUrl,
        'song_type': itemType,
        'song_number': itemNumber,
        'song_title': songTitle ?? '',
        'description': description?.isNotEmpty ?? false ? description : 'Audio file submission',
        'app_version': appVersion,
        'jira_status': 'Email Sent',  // Special status for pending tickets
        'user_id': user?.id,
        'device_id': user == null ? deviceId : null,
      });
      
      debugPrint('AudioErrorDialog: Saved pending ticket $placeholderKey to Supabase');
    } catch (e) {
      debugPrint('AudioErrorDialog: Failed to save pending ticket to Supabase: $e');
      // Don't throw - email was sent, just tracking failed
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Audio Unavailable',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Text(
        'Audio file is not available for this $itemType.\n\nWould you like to provide the audio file, if available?',
        style: const TextStyle(fontSize: 16),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('No'),
          onPressed: () => Navigator.pop(context),
        ),
        FilledButton(
          child: const Text('Yes'),
          onPressed: () async {
            Navigator.pop(context);
            await _showAudioSubmissionDialog(context);
          },
        ),
      ],
    );
  }
}

enum _EmailStatus { loading, success, failure }

class _EmailSendingDialog extends StatelessWidget {
  final _EmailStatus status;
  final String? errorMessage;
  final VoidCallback? onClose;

  const _EmailSendingDialog({
    required this.status,
    this.errorMessage,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          _buildStatusContent(context, colorScheme),
          const SizedBox(height: 24),
          _buildActions(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildStatusContent(BuildContext context, ColorScheme colorScheme) {
    switch (status) {
      case _EmailStatus.loading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sending email...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        );

      case _EmailStatus.success:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Lottie.asset(
                'lib/assets/icons/tick-animation.json',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Email Sent!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A ticket will be created automatically from your email.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

      case _EmailStatus.failure:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.errorContainer,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 50,
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Email Not Sent',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        );
    }
  }

  Widget _buildActions(BuildContext context, ColorScheme colorScheme) {
    if (status == _EmailStatus.loading) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: FilledButton(
            onPressed: onClose,
            style: status == _EmailStatus.failure
                ? FilledButton.styleFrom(
                    backgroundColor: colorScheme.surfaceVariant,
                    foregroundColor: colorScheme.onSurfaceVariant,
                  )
                : null,
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}
