import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Result class for Jira ticket creation
class JiraTicketResult {
  final bool success;
  final String? ticketKey;
  final String? ticketUrl;
  final String? errorMessage;

  JiraTicketResult({
    required this.success,
    this.ticketKey,
    this.ticketUrl,
    this.errorMessage,
  });
}

/// Service for creating Jira tickets for lyric issues
///
/// This service allows users to report lyric issues directly from the app,
/// which creates tickets in Jira for tracking and resolution.
class JiraService {
  JiraService._internal();
  static final JiraService _instance = JiraService._internal();
  factory JiraService() => _instance;

  /// Checks if Jira is configured
  bool get isConfigured {
    final url = dotenv.env['JIRA_URL'];
    final email = dotenv.env['JIRA_EMAIL'];
    final apiToken = dotenv.env['JIRA_API_TOKEN'];
    final projectKey = dotenv.env['JIRA_PROJECT_KEY'];

    return url != null &&
        url.isNotEmpty &&
        email != null &&
        email.isNotEmpty &&
        apiToken != null &&
        apiToken.isNotEmpty &&
        projectKey != null &&
        projectKey.isNotEmpty;
  }

  /// Creates a Jira ticket for a lyric issue
  ///
  /// Parameters:
  /// - [songType]: Type of song ('Hymn' or 'Keerthane')
  /// - [songNumber]: Song number
  /// - [songTitle]: Song title
  /// - [description]: Optional user-provided description
  /// - [appVersion]: App version string
  ///
  /// Returns [JiraTicketResult] with success status and ticket information
  Future<JiraTicketResult> createTicket({
    required String songType,
    required int songNumber,
    required String songTitle,
    String? description,
    required String appVersion,
  }) async {
    if (!isConfigured) {
      debugPrint('JiraService: Jira not configured, skipping ticket creation');
      return JiraTicketResult(
        success: false,
        errorMessage: 'Jira is not configured',
      );
    }

    try {
      // Ensure dotenv is loaded
      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        debugPrint('JiraService: Warning - .env already loaded or error: $e');
      }

      final url = dotenv.env['JIRA_URL'];
      final email = dotenv.env['JIRA_EMAIL'];
      final apiToken = dotenv.env['JIRA_API_TOKEN'];
      final projectKey = dotenv.env['JIRA_PROJECT_KEY'];
      // Use 'Task' as default, and also if explicitly set to '10049' (Service Request ID)
      final rawIssueType = dotenv.env['JIRA_ISSUE_TYPE'] ?? 'Task';
      final issueTypeConfig = (rawIssueType == '10049') ? 'Task' : rawIssueType;

      // Validate all required fields
      if (url == null || url.isEmpty) {
        return JiraTicketResult(
          success: false,
          errorMessage: 'JIRA_URL is not configured in .env file',
        );
      }
      if (email == null || email.isEmpty) {
        return JiraTicketResult(
          success: false,
          errorMessage: 'JIRA_EMAIL is not configured in .env file',
        );
      }
      if (apiToken == null || apiToken.isEmpty) {
        return JiraTicketResult(
          success: false,
          errorMessage: 'JIRA_API_TOKEN is not configured in .env file',
        );
      }
      if (projectKey == null || projectKey.isEmpty) {
        return JiraTicketResult(
          success: false,
          errorMessage: 'JIRA_PROJECT_KEY is not configured in .env file',
        );
      }

      // Prepare authentication
      final credentials = base64Encode(utf8.encode('$email:$apiToken'));
      final headers = {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // Build API URL
      final apiUrl = url.endsWith('/')
          ? '${url}rest/api/3/issue'
          : '$url/rest/api/3/issue';

      // Debug: Log the request details (without sensitive data)
      debugPrint('JiraService: Creating ticket with:');
      debugPrint('  URL: $apiUrl');
      debugPrint('  Project: $projectKey');
      debugPrint('  Issue Type: $issueTypeConfig');
      debugPrint('  Email: $email');
      debugPrint('  Token length: ${apiToken.length}');
      debugPrint(
          '  Token starts with: ${apiToken.substring(0, apiToken.length > 10 ? 10 : apiToken.length)}...');

      // Build ticket data
      final summary = '$songType $songNumber Lyrics Issue';
      final ticketDescription = _buildTicketDescription(
        songType: songType,
        songNumber: songNumber,
        songTitle: songTitle,
        description: description,
        appVersion: appVersion,
      );

      // Determine issue type format (ID or name)
      // If it's numeric, use as ID; otherwise use as name
      final isNumeric = RegExp(r'^\d+$').hasMatch(issueTypeConfig);
      final issueTypeField =
          isNumeric ? {'id': issueTypeConfig} : {'name': issueTypeConfig};

      // Prepare request body (matching Postman format exactly)
      final body = {
        'fields': {
          'project': {
            'key': projectKey,
          },
          'summary': summary,
          'issuetype': issueTypeField,
          'description': {
            'type': 'doc',
            'version': 1,
            'content': [
              {
                'type': 'paragraph',
                'content': [
                  {
                    'type': 'text',
                    'text': ticketDescription,
                  },
                ],
              },
            ],
          },
          'labels': ['lyrics-issue', 'app-reported'],
        },
      };

      // Debug: Log the request body (for comparison with Postman)
      final requestBody = jsonEncode(body);
      debugPrint('JiraService: Request body: $requestBody');

      // Make API request

      var response = await http
          .post(
        Uri.parse(apiUrl),
        headers: headers,
        body: requestBody,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Jira API request timed out');
        },
      );

      debugPrint('JiraService: Response status: ${response.statusCode}');
      debugPrint('JiraService: Response body: ${response.body}');

      // If we get a permission error, try with "Task" as fallback (Task works on all Jira plans)
      if (response.statusCode == 401 || response.statusCode == 403) {
        final errorBody = response.body;
        if (errorBody.contains('permission') && issueTypeConfig != 'Task') {
          debugPrint(
              'JiraService: Permission error with issue type "$issueTypeConfig", trying Task as fallback');

          // Try with "Task" issue type instead
          final fallbackBody = Map<String, dynamic>.from(body);
          fallbackBody['fields']['issuetype'] = {'name': 'Task'};

          response = await http
              .post(
            Uri.parse(apiUrl),
            headers: headers,
            body: jsonEncode(fallbackBody),
          )
              .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Jira API request timed out');
            },
          );
        }
      }

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final ticketKey = responseData['key'] as String;
        final ticketUrl = '$url/browse/$ticketKey';

        debugPrint('JiraService: Successfully created ticket $ticketKey');

        // Save ticket to Supabase
        await _saveTicketToSupabase(
          ticketKey: ticketKey,
          ticketUrl: ticketUrl,
          songType: songType,
          songNumber: songNumber,
          songTitle: songTitle,
          description: description,
          appVersion: appVersion,
        );

        return JiraTicketResult(
          success: true,
          ticketKey: ticketKey,
          ticketUrl: ticketUrl,
        );
      } else {
        final errorBody = response.body;
        debugPrint(
            'JiraService: Failed to create ticket - ${response.statusCode}: $errorBody');

        String errorMessage = 'Failed to create ticket';

        // Try to parse error message from response
        try {
          final errorData = jsonDecode(errorBody) as Map<String, dynamic>?;
          final errorMessages = errorData?['errorMessages'] as List<dynamic>?;
          if (errorMessages != null && errorMessages.isNotEmpty) {
            errorMessage = errorMessages.first as String;
          }
        } catch (_) {
          // Use default error messages if parsing fails
        }

        if (response.statusCode == 401) {
          // Check if it's a permission error
          if (errorBody.contains('permission') ||
              errorBody.contains('Permission')) {
            errorMessage =
                'Permission denied. The API token user does not have permission to create issues in this project. Please check Jira project permissions.';
          } else {
            errorMessage =
                'Authentication failed. Please check your Jira credentials.';
          }
        } else if (response.statusCode == 403) {
          errorMessage =
              'Permission denied. Please check your Jira permissions.';
        } else if (response.statusCode == 404) {
          errorMessage =
              'Jira project or endpoint not found. Please verify the project key in your configuration.';
        } else if (response.statusCode == 429) {
          errorMessage = 'Rate limit exceeded. Please try again later.';
        }

        return JiraTicketResult(
          success: false,
          errorMessage: errorMessage,
        );
      }
    } on TimeoutException catch (e) {
      debugPrint('JiraService: Timeout error: $e');
      return JiraTicketResult(
        success: false,
        errorMessage:
            'Request timed out. Please check your internet connection.',
      );
    } catch (e, stackTrace) {
      debugPrint('JiraService: Error creating ticket: $e');
      debugPrint('JiraService: Stack trace: $stackTrace');

      // Check for network-related errors
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('socket') ||
          errorString.contains('network') ||
          errorString.contains('connection') ||
          errorString.contains('failed host lookup')) {
        return JiraTicketResult(
          success: false,
          errorMessage: 'Network error. Please check your internet connection.',
        );
      }

      return JiraTicketResult(
        success: false,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  /// Builds the ticket description with all metadata
  String _buildTicketDescription({
    required String songType,
    required int songNumber,
    required String songTitle,
    String? description,
    required String appVersion,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('*Song Information:*');
    buffer.writeln('* Type: $songType');
    buffer.writeln('* Number: $songNumber');
    buffer.writeln('* Title: $songTitle');
    buffer.writeln('');
    buffer.writeln('*App Information:*');
    buffer.writeln('* Version: $appVersion');
    buffer.writeln('');
    buffer.writeln('*Issue Description:*');
    if (description != null && description.trim().isNotEmpty) {
      buffer.writeln(description.trim());
    } else {
      buffer.writeln('No description provided');
    }
    buffer.writeln('');
    buffer.writeln('*Reported via:* CSI Hymns App');

    return buffer.toString();
  }

  /// Saves ticket to Supabase for tracking
  Future<void> _saveTicketToSupabase({
    required String ticketKey,
    required String ticketUrl,
    required String songType,
    required int songNumber,
    required String songTitle,
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

      await supabase.from('jira_tickets').insert({
        'ticket_key': ticketKey,
        'ticket_url': ticketUrl,
        'song_type': songType,
        'song_number': songNumber,
        'song_title': songTitle,
        'description': description,
        'app_version': appVersion,
        'jira_status': 'Open', // Default status (matches Jira)
        'user_id': user?.id,
        'device_id': user == null ? deviceId : null,
      });

      debugPrint('JiraService: Saved ticket $ticketKey to Supabase');
    } catch (e) {
      debugPrint('JiraService: Failed to save ticket to Supabase: $e');
      // Don't throw - ticket was created in Jira, just tracking failed
    }
  }

  /// Fetches ticket status from Jira and updates Supabase
  Future<void> syncTicketStatus(String ticketKey) async {
    if (!isConfigured) {
      debugPrint('JiraService: Not configured, skipping sync for $ticketKey');
      return;
    }

    try {
      // Ensure dotenv is loaded
      await dotenv.load(fileName: '.env');

      final url = dotenv.env['JIRA_URL'];
      final email = dotenv.env['JIRA_EMAIL'];
      final apiToken = dotenv.env['JIRA_API_TOKEN'];

      if (url == null || email == null || apiToken == null) {
        debugPrint(
            'JiraService: Missing Jira credentials, cannot sync $ticketKey');
        return;
      }

      final credentials = base64Encode(utf8.encode('$email:$apiToken'));
      final headers = {
        'Authorization': 'Basic $credentials',
        'Accept': 'application/json',
      };

      final apiUrl = url.endsWith('/')
          ? '${url}rest/api/3/issue/$ticketKey'
          : '$url/rest/api/3/issue/$ticketKey';

      debugPrint('JiraService: Syncing status for $ticketKey from $apiUrl');

      final response = await http
          .get(
            Uri.parse(apiUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
          'JiraService: Response status for $ticketKey: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['fields']?['status'] as Map<String, dynamic>?;
        final statusName = status?['name'] as String?;
        final statusId = status?['id'] as String?;

        debugPrint(
            'JiraService: Status from Jira for $ticketKey: $statusName (ID: $statusId)');

        if (statusName != null) {
          // Update Supabase
          try {
            final supabase = Supabase.instance.client;

            // First check if ticket exists
            final existing = await supabase
                .from('jira_tickets')
                .select('ticket_key, jira_status')
                .eq('ticket_key', ticketKey)
                .maybeSingle();

            if (existing == null) {
              debugPrint(
                  'JiraService: Ticket $ticketKey not found in Supabase, skipping update');
              return;
            }

            debugPrint(
                'JiraService: Current status in Supabase for $ticketKey: ${existing['jira_status']}');

            // Update the ticket status
            // Note: We don't use .select() here because RLS might prevent returning the row
            // Instead, we'll verify the update by checking the row count
            await supabase.from('jira_tickets').update({
              'jira_status': statusName,
              'jira_status_id': statusId,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('ticket_key', ticketKey);

            // Verify the update by fetching the updated row
            final verifyResult = await supabase
                .from('jira_tickets')
                .select('ticket_key, jira_status, jira_status_id')
                .eq('ticket_key', ticketKey)
                .maybeSingle();

            if (verifyResult != null &&
                verifyResult['jira_status'] == statusName) {
              debugPrint(
                  'JiraService: Successfully updated status for $ticketKey from ${existing['jira_status']} to $statusName');
              debugPrint(
                  'JiraService: Verified update - current status: ${verifyResult['jira_status']}');
            } else {
              debugPrint(
                  'JiraService: Update may have failed - verification shows: $verifyResult');
            }
          } catch (e, stackTrace) {
            debugPrint(
                'JiraService: Error updating Supabase with status for $ticketKey: $e');
            debugPrint('JiraService: Stack trace: $stackTrace');
          }
        } else {
          debugPrint(
              'JiraService: Status name is null for ticket $ticketKey. Full status object: $status');
        }
      } else {
        debugPrint(
            'JiraService: Failed to fetch ticket status for $ticketKey - ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint(
          'JiraService: Failed to sync ticket status for $ticketKey: $e');
      debugPrint('JiraService: Stack trace: $stackTrace');
    }
  }

  /// Fetches available issue types for the project (for debugging)
  /// This can help verify if the issue type ID is valid
  Future<List<Map<String, dynamic>>> getProjectIssueTypes() async {
    if (!isConfigured) return [];

    try {
      final url = dotenv.env['JIRA_URL']!;
      final email = dotenv.env['JIRA_EMAIL']!;
      final apiToken = dotenv.env['JIRA_API_TOKEN']!;
      final projectKey = dotenv.env['JIRA_PROJECT_KEY']!;

      final credentials = base64Encode(utf8.encode('$email:$apiToken'));
      final headers = {
        'Authorization': 'Basic $credentials',
        'Accept': 'application/json',
      };

      // Get project metadata which includes available issue types
      final apiUrl = url.endsWith('/')
          ? '${url}rest/api/3/project/$projectKey'
          : '$url/rest/api/3/project/$projectKey';

      final response = await http
          .get(
            Uri.parse(apiUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final issueTypes = data['issueTypes'] as List<dynamic>?;
        if (issueTypes != null) {
          return issueTypes
              .map((it) => {
                    'id': it['id']?.toString(),
                    'name': it['name']?.toString(),
                    'description': it['description']?.toString(),
                  })
              .toList();
        }
      }

      debugPrint(
          'JiraService: Failed to fetch issue types - ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('JiraService: Error fetching issue types: $e');
      return [];
    }
  }

  /// Searches Jira for tickets matching the given criteria
  /// Returns list of ticket keys that match
  Future<List<Map<String, dynamic>>> searchTickets({
    required String songType,
    required int songNumber,
    String? songTitle,
    required DateTime
        createdAfter, // Only search for tickets created after this time
  }) async {
    if (!isConfigured) {
      debugPrint('JiraService: Not configured, skipping ticket search');
      return [];
    }

    try {
      await dotenv.load(fileName: '.env');

      final url = dotenv.env['JIRA_URL'];
      final email = dotenv.env['JIRA_EMAIL'];
      final apiToken = dotenv.env['JIRA_API_TOKEN'];
      final projectKey = dotenv.env['JIRA_PROJECT_KEY'];

      if (url == null ||
          email == null ||
          apiToken == null ||
          projectKey == null) {
        return [];
      }

      final credentials = base64Encode(utf8.encode('$email:$apiToken'));
      final headers = {
        'Authorization': 'Basic $credentials',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      // Build JQL query to search for tickets
      // Search for tickets created after the email was sent
      // Match by summary containing song type and number
      final createdAfterStr =
          createdAfter.toIso8601String().split('.')[0]; // Remove milliseconds
      final jql =
          'project = $projectKey AND created >= "$createdAfterStr" AND ('
          'summary ~ "$songType $songNumber" OR '
          'summary ~ "[$songType] $songNumber" OR '
          'description ~ "$songType $songNumber"'
          ') ORDER BY created DESC';

      final searchUrl = url.endsWith('/')
          ? '${url}rest/api/3/search'
          : '$url/rest/api/3/search';

      debugPrint('JiraService: Searching tickets with JQL: $jql');

      final response = await http
          .post(
            Uri.parse(
                '$searchUrl?jql=${Uri.encodeComponent(jql)}&maxResults=10'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final issues = data['issues'] as List<dynamic>?;

        if (issues != null && issues.isNotEmpty) {
          debugPrint('JiraService: Found ${issues.length} matching tickets');
          return issues.map((issue) {
            final fields = issue['fields'] as Map<String, dynamic>;
            return {
              'key': issue['key'] as String,
              'summary': fields['summary'] as String? ?? '',
              'description': _extractTextFromDescription(fields['description']),
              'created': fields['created'] as String?,
            };
          }).toList();
        }
      } else {
        debugPrint(
            'JiraService: Search failed - ${response.statusCode}: ${response.body}');
      }

      return [];
    } catch (e, stackTrace) {
      debugPrint('JiraService: Error searching tickets: $e');
      debugPrint('JiraService: Stack trace: $stackTrace');
      return [];
    }
  }

  /// Extracts plain text from Jira's description format (doc format)
  String _extractTextFromDescription(dynamic description) {
    if (description == null) return '';
    if (description is String) return description;

    try {
      if (description is Map<String, dynamic>) {
        final content = description['content'] as List<dynamic>?;
        if (content != null) {
          final buffer = StringBuffer();
          for (final item in content) {
            if (item is Map<String, dynamic>) {
              final text = item['text'] as String?;
              if (text != null) {
                buffer.writeln(text);
              }
              // Recursively extract from nested content
              final nestedContent = item['content'] as List<dynamic>?;
              if (nestedContent != null) {
                for (final nested in nestedContent) {
                  if (nested is Map<String, dynamic>) {
                    final nestedText = nested['text'] as String?;
                    if (nestedText != null) {
                      buffer.writeln(nestedText);
                    }
                  }
                }
              }
            }
          }
          return buffer.toString();
        }
      }
    } catch (e) {
      debugPrint('JiraService: Error extracting description text: $e');
    }

    return description.toString();
  }

  /// Matches and updates pending tickets with actual Jira tickets
  /// This should be called during sync to match email-submitted tickets
  Future<void> matchPendingTickets() async {
    if (!isConfigured) {
      debugPrint(
          'JiraService: Not configured, skipping pending ticket matching');
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // Get all pending tickets (status = "Email Sent")
      final pendingTickets = await supabase
          .from('jira_tickets')
          .select()
          .eq('jira_status', 'Email Sent')
          .order('created_at', ascending: false);

      if (pendingTickets.isEmpty) {
        debugPrint('JiraService: No pending tickets to match');
        return;
      }

      debugPrint(
          'JiraService: Found ${pendingTickets.length} pending tickets to match');

      for (final pending in pendingTickets) {
        try {
          final songType = pending['song_type'] as String;
          final songNumber = pending['song_number'] as int;
          final songTitle = pending['song_title'] as String?;
          final createdAt = DateTime.parse(pending['created_at'] as String);

          // Search for tickets created within 48 hours of the email
          final searchAfter = createdAt.subtract(const Duration(
              hours: 1)); // Start 1 hour before to account for delays

          final matches = await searchTickets(
            songType: songType,
            songNumber: songNumber,
            songTitle: songTitle,
            createdAfter: searchAfter,
          );

          if (matches.isNotEmpty) {
            // Use the first match (most recent)
            final match = matches.first;
            final actualTicketKey = match['key'] as String;
            final pendingKey = pending['ticket_key'] as String;

            debugPrint(
                'JiraService: Found potential match: $actualTicketKey for pending $pendingKey');

            // Check if this ticket key already exists (avoid duplicates)
            final existing = await supabase
                .from('jira_tickets')
                .select('ticket_key')
                .eq('ticket_key', actualTicketKey)
                .maybeSingle();

            if (existing != null) {
              debugPrint(
                  'JiraService: Ticket $actualTicketKey already exists, deleting pending ticket $pendingKey');
              // Delete the pending ticket since we already have the real one
              await supabase
                  .from('jira_tickets')
                  .delete()
                  .eq('ticket_key', pendingKey);
            } else {
              // Update the pending ticket with the actual ticket key
              final url = dotenv.env['JIRA_URL'] ??
                  'https://reyziecrafts.atlassian.net';
              final ticketUrl = url.endsWith('/')
                  ? '${url}browse/$actualTicketKey'
                  : '$url/browse/$actualTicketKey';

              await supabase.from('jira_tickets').update({
                'ticket_key': actualTicketKey,
                'ticket_url': ticketUrl,
                'jira_status': 'Open', // Reset to Open, will be synced properly
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('ticket_key', pendingKey);

              debugPrint(
                  'JiraService: Matched pending ticket $pendingKey with actual ticket $actualTicketKey');

              // Now sync the status properly
              await syncTicketStatus(actualTicketKey);
            }
          } else {
            debugPrint(
                'JiraService: No match found for pending ticket ${pending['ticket_key']}');
          }

          // Small delay to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e, stackTrace) {
          debugPrint(
              'JiraService: Error matching pending ticket ${pending['ticket_key']}: $e');
          debugPrint('JiraService: Stack trace: $stackTrace');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('JiraService: Error in matchPendingTickets: $e');
      debugPrint('JiraService: Stack trace: $stackTrace');
    }
  }
}

/// Exception class for timeout errors
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
