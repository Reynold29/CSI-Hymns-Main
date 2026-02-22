import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hymns_latest/services/jira_service.dart';

/// Model for a Jira ticket
class JiraTicket {
  final String id;
  final String ticketKey;
  final String ticketUrl;
  final String songType;
  final int songNumber;
  final String songTitle;
  final String? description;
  final String? appVersion;
  final String jiraStatus;
  final String? jiraStatusId;
  final DateTime createdAt;
  final DateTime updatedAt;

  JiraTicket({
    required this.id,
    required this.ticketKey,
    required this.ticketUrl,
    required this.songType,
    required this.songNumber,
    required this.songTitle,
    this.description,
    this.appVersion,
    required this.jiraStatus,
    this.jiraStatusId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JiraTicket.fromJson(Map<String, dynamic> json) {
    return JiraTicket(
      id: json['id'] as String,
      ticketKey: json['ticket_key'] as String,
      ticketUrl: json['ticket_url'] as String,
      songType: json['song_type'] as String,
      songNumber: (json['song_number'] as num).toInt(),
      songTitle: json['song_title'] as String,
      description: json['description'] as String?,
      appVersion: json['app_version'] as String?,
      jiraStatus: json['jira_status'] as String? ?? 'Open',
      jiraStatusId: json['jira_status_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Service for managing Jira tickets in Supabase
class TicketsService {
  TicketsService._internal();
  static final TicketsService _instance = TicketsService._internal();
  factory TicketsService() => _instance;

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('TicketsService: Supabase not available: $e');
      return null;
    }
  }

  /// Gets device ID for unregistered users
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null || deviceId.isEmpty) {
      // Generate a UUID for device ID
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${prefs.hashCode}';
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  /// Fetches all tickets for the current user (registered or unregistered)
  Future<List<JiraTicket>> getMyTickets() async {
    try {
      final client = _client;
      if (client == null) return [];

      final user = client.auth.currentUser;
      
      List<Map<String, dynamic>> tickets;
      
      if (user != null) {
        // Registered user - fetch by user_id
        final response = await client
            .from('jira_tickets')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
        
        tickets = List<Map<String, dynamic>>.from(response);
      } else {
        // Unregistered user - fetch by device_id
        final deviceId = await _getDeviceId();
        final response = await client
            .from('jira_tickets')
            .select()
            .eq('device_id', deviceId)
            .order('created_at', ascending: false);
        
        tickets = List<Map<String, dynamic>>.from(response);
      }

      return tickets.map((json) => JiraTicket.fromJson(json)).toList();
    } catch (e) {
      debugPrint('TicketsService: Error fetching tickets: $e');
      return [];
    }
  }

  /// Syncs ticket status from Jira for all user's tickets
  Future<void> syncAllTicketStatuses() async {
    try {
      final jiraService = JiraService();
      
      // First, try to match any pending tickets (from email submissions)
      await jiraService.matchPendingTickets();
      
      // Reload tickets after matching (in case some were updated)
      final updatedTickets = await getMyTickets();
      
      // Then sync statuses for all tickets
      for (final ticket in updatedTickets) {
        // Skip pending tickets that haven't been matched yet
        if (ticket.jiraStatus == 'Email Sent' && ticket.ticketKey.startsWith('PENDING-')) {
          continue;
        }
        
        await jiraService.syncTicketStatus(ticket.ticketKey);
        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('TicketsService: Error syncing ticket statuses: $e');
    }
  }

  /// Syncs a specific ticket's status from Jira
  Future<void> syncTicketStatus(String ticketKey) async {
    final jiraService = JiraService();
    await jiraService.syncTicketStatus(ticketKey);
  }
}
