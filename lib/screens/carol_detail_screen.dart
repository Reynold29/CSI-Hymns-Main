import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hymns_latest/models/christmas_carol.dart';
import 'package:hymns_latest/theme/christmas_theme.dart';
import 'package:hymns_latest/widgets/pdf_song_viewer.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';
import 'package:hymns_latest/services/christmas_carols_service.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Detail screen for viewing a Christmas Carol.
/// 
/// Displays:
/// - Song metadata (title, church, scale, transpose)
/// - Lyrics text if available
/// - PDF viewer if PDF is attached
/// - Actions for editing, deleting (if authorized), and reporting
class CarolDetailScreen extends StatefulWidget {
  final ChristmasCarol carol;

  const CarolDetailScreen({
    super.key,
    required this.carol,
  });

  @override
  State<CarolDetailScreen> createState() => _CarolDetailScreenState();
}

class _CarolDetailScreenState extends State<CarolDetailScreen> {
  late ChristmasCarol _carol;
  double _fontSize = 16.0;
  bool _showPdf = false;

  static const double _minFontSize = 12.0;
  static const double _maxFontSize = 32.0;
  static const double _fontSizeStep = 2.0;

  @override
  void initState() {
    super.initState();
    _carol = widget.carol;
    // Refresh carol from service after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCarolFromService();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh carol when dependencies change (e.g., when returning to this screen)
    _refreshCarolFromService();
  }

  /// Fetches the latest carol data from the service
  Future<void> _refreshCarolFromService() async {
    if (!mounted) return;
    final carolsService = context.read<ChristmasCarolsService>();
    final updatedCarol = carolsService.getCarolById(_carol.id);
    if (updatedCarol != null && mounted) {
      // Only update if the carol has actually changed to avoid unnecessary rebuilds
      if (updatedCarol.transpose != _carol.transpose || 
          updatedCarol.scale != _carol.scale ||
          updatedCarol.title != _carol.title ||
          updatedCarol.lyrics != _carol.lyrics) {
        setState(() {
          _carol = updatedCarol;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final carolsService = context.watch<ChristmasCarolsService>();
    final canEdit = carolsService.canEditCarol(_carol);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _carol.title,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              _carol.churchName,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          // Font size controls
          if (_carol.hasLyrics && !_showPdf) ...[
            IconButton(
              icon: const Icon(Icons.text_decrease),
              tooltip: 'Decrease font size',
              onPressed: _fontSize > _minFontSize
                  ? () {
                      HapticFeedbackManager.lightClick();
                      setState(() => _fontSize -= _fontSizeStep);
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.text_increase),
              tooltip: 'Increase font size',
              onPressed: _fontSize < _maxFontSize
                  ? () {
                      HapticFeedbackManager.lightClick();
                      setState(() => _fontSize += _fontSizeStep);
                    }
                  : null,
            ),
          ],
          // Toggle between lyrics and PDF
          if (_carol.hasLyrics && _carol.hasPdf)
            IconButton(
              icon: Icon(_showPdf ? Icons.text_snippet : Icons.picture_as_pdf),
              tooltip: _showPdf ? 'Show lyrics' : 'Show PDF',
              onPressed: () {
                HapticFeedbackManager.lightClick();
                setState(() => _showPdf = !_showPdf);
              },
            ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value, context, carolsService),
            itemBuilder: (context) => [
              if (canEdit) ...[
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 12),
                      Text('Edit carol'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete carol', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
              ],
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined),
                    SizedBox(width: 12),
                    Text('Report issue'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Metadata header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (!_carol.hasChords)
                  _MetadataChip(
                    icon: Icons.music_off,
                    label: 'No Chords',
                    color: colorScheme.outline,
                  )
                else ...[
                  _MetadataChip(
                    icon: Icons.piano,
                    label: _carol.scale,
                    color: ChristmasColors.christmasGreen,
                  ),
                  if (_carol.transpose != 0)
                    _MetadataChip(
                      icon: Icons.swap_vert,
                      label: 'Transpose: ${_carol.transpose > 0 ? '+' : ''}${_carol.transpose}',
                      color: colorScheme.tertiary,
                    ),
                ],
                if (_carol.hasPdf)
                  _MetadataChip(
                    icon: Icons.picture_as_pdf,
                    label: 'PDF',
                    color: ChristmasColors.christmasRed,
                  ),
                if (carolsService.isAdmin)
                  _MetadataChip(
                    icon: Icons.admin_panel_settings,
                    label: 'Admin',
                    color: Colors.purple,
                  ),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: _buildContent(colorScheme, textTheme, _carol),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, TextTheme textTheme, ChristmasCarol carol) {
    // Show PDF if selected and available
    if (_showPdf && carol.hasPdf) {
      return PdfSongViewer(pdfPath: carol.pdfPath!);
    }

    // Show lyrics if available
    if (carol.hasLyrics && !_showPdf) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          carol.lyrics!,
          style: textTheme.bodyLarge?.copyWith(
            fontSize: _fontSize,
            height: 1.8,
            color: colorScheme.onSurface,
          ),
        ),
      );
    }

    // Only PDF available
    if (carol.hasPdf) {
      return PdfSongViewer(pdfPath: carol.pdfPath!);
    }

    // No content available
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off_rounded,
            size: 64,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No lyrics or PDF available',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, BuildContext context, ChristmasCarolsService service) async {
    switch (action) {
      case 'edit':
        await _showEditDialog(context, service);
        break;
      case 'delete':
        await _confirmDelete(context, service);
        break;
      case 'report':
        await _showReportDialog(context);
        break;
    }
  }

  Future<void> _showReportDialog(BuildContext context) async {
    await HapticFeedbackManager.lightClick();
    
    final descriptionController = TextEditingController();
    
    // Dialog with optional text field
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Find something wrong with this carol?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue (optional)',
                    border: OutlineInputBorder(),
                    labelText: 'Issue Description (Optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, 'cancel'),
            ),
            FilledButton(
              child: const Text('Send Email'),
              onPressed: () => Navigator.pop(context, 'send'),
            ),
          ],
        );
      },
    );
    
    if (action == 'send' && mounted) {
      await _sendReportEmail(context, descriptionController.text.trim());
    }
  }
  
  Future<void> _sendReportEmail(BuildContext context, String description) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      final emailBody = '''
Carol Information:
- ID: ${_carol.id}
- Title: ${_carol.title}
- Church: ${_carol.churchName}

App Information:
- Version: $appVersion

${description.isNotEmpty ? 'Issue Description:\n$description\n\n' : ''}Submitted via: CSI Hymns App
''';

      final Email email = Email(
        body: emailBody,
        subject: '[Carol] Issue Report: ${_carol.title}',
        recipients: ['support@reyziecrafts.atlassian.net'],
        isHTML: false,
      );

      await FlutterEmailSender.send(email);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue report sent successfully!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending email: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog(BuildContext context, ChristmasCarolsService service) async {
    final titleController = TextEditingController(text: _carol.title);
    final songNumberController = TextEditingController(text: _carol.songNumber ?? '');
    final lyricsController = TextEditingController(text: _carol.lyrics ?? '');
    String selectedScale = _carol.scale;
    int transpose = _carol.transpose;
    bool hasChords = _carol.hasChords;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit),
              SizedBox(width: 12),
              Text('Edit Carol'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: songNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Song Number (optional)',
                    hintText: 'e.g., 1, 25, A1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Has Chords checkbox
                CheckboxListTile(
                  title: const Text('Contains chord notation'),
                  subtitle: const Text('Uncheck if the PDF/lyrics has no chords'),
                  value: hasChords,
                  onChanged: (value) {
                    setDialogState(() => hasChords = value ?? true);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                // Scale selection (only show if has chords)
                if (hasChords)
                  DropdownButtonFormField<String>(
                    value: selectedScale,
                    decoration: const InputDecoration(
                      labelText: 'Scale / Key',
                      border: OutlineInputBorder(),
                    ),
                    items: MusicalScales.allScales.map((scale) {
                      return DropdownMenuItem(value: scale, child: Text(scale));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedScale = value);
                      }
                    },
                  ),
                if (hasChords) const SizedBox(height: 16),
                // Transpose (only show if has chords)
                if (hasChords)
                  Row(
                    children: [
                      const Text('Transpose: '),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: transpose > -12
                            ? () => setDialogState(() => transpose--)
                            : null,
                      ),
                      Text(
                        transpose == 0 ? '0' : (transpose > 0 ? '+$transpose' : '$transpose'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: transpose < 12
                            ? () => setDialogState(() => transpose++)
                            : null,
                      ),
                    ],
                  ),
                if (hasChords) const SizedBox(height: 16),
                TextField(
                  controller: lyricsController,
                  decoration: const InputDecoration(
                    labelText: 'Lyrics (optional)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 8,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      try {
        final updatedCarol = _carol.copyWith(
          title: titleController.text.trim(),
          songNumber: songNumberController.text.trim().isEmpty 
              ? null 
              : songNumberController.text.trim(),
          scale: selectedScale,
          transpose: transpose,
          hasChords: hasChords,
          lyrics: lyricsController.text.trim().isEmpty ? null : lyricsController.text.trim(),
        );
        
        await service.updateCarol(updatedCarol);
        
        setState(() {
          _carol = updatedCarol;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Carol updated successfully'),
              backgroundColor: ChristmasColors.christmasGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating carol: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, ChristmasCarolsService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Carol?'),
        content: Text(
          'Are you sure you want to delete "${_carol.title}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await service.deleteCarol(_carol.id, carol: _carol);
        
        if (mounted) {
          Navigator.pop(context); // Go back to list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Carol deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting carol: $e')),
          );
        }
      }
    }
  }
}

/// Small metadata chip widget
class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetadataChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

