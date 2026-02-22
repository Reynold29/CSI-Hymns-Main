import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hymns_latest/services/tickets_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final TicketsService _ticketsService = TicketsService();
  List<JiraTicket> _tickets = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    // Auto-sync statuses when screen loads (in background)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncStatuses();
    });
  }

  Future<void> _loadTickets() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final tickets = await _ticketsService.getMyTickets();
      // Sort by created date (newest first)
      tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _tickets = tickets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tickets: $e')),
        );
      }
    }
  }

  Future<void> _syncStatuses() async {
    if (mounted) {
      setState(() {
        _isSyncing = true;
      });
    }

    try {
      debugPrint('TicketsScreen: Starting sync for ${_tickets.length} tickets');
      await _ticketsService.syncAllTicketStatuses();
      // Small delay to ensure Supabase updates are reflected
      await Future.delayed(const Duration(milliseconds: 800));
      await _loadTickets(); // Reload to show updated statuses
      debugPrint('TicketsScreen: Sync completed, tickets reloaded');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket statuses synced successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('TicketsScreen: Error syncing statuses: $e');
      debugPrint('TicketsScreen: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing statuses: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase().trim();
    switch (statusLower) {
      // Completed/Done statuses - Green
      case 'done':
      case 'resolved':
      case 'closed':
        return Colors.green;
      // In Progress statuses - Blue
      case 'work in progress':
      case 'in progress':
      case 'in development':
        return Colors.blue;
      // Email Sent (pending) - Purple/Indigo
      case 'email sent':
        return Colors.indigo;
      // Pending/Waiting statuses - Yellow/Orange
      case 'pending':
        return Colors.amber;
      // Open/To Do statuses - Orange
      case 'open':
      case 'to do':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets Submitted'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isSyncing ? null : () async {
              await HapticFeedbackManager.lightClick();
              await _syncStatuses();
            },
            tooltip: 'Sync Statuses',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FontAwesomeIcons.ticket,
                        size: 64,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tickets submitted yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Submit a ticket from a hymn or keerthane detail screen',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _syncStatuses();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tickets.length,
                    itemBuilder: (context, index) {
                      final ticket = _tickets[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () async {
                            await HapticFeedbackManager.lightClick();
                            final uri = Uri.parse(ticket.ticketUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ticket.ticketKey,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(ticket.jiraStatus)
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getStatusColor(ticket.jiraStatus),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        ticket.jiraStatus,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(ticket.jiraStatus),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      ticket.songType == 'Hymn'
                                          ? FontAwesomeIcons.music
                                          : FontAwesomeIcons.book,
                                      size: 16,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${ticket.songType} ${ticket.songNumber}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                if (ticket.songTitle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    ticket.songTitle,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (ticket.description != null &&
                                    ticket.description!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    ticket.description!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Tap to view in Jira',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.primary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

}
