import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:hymns_latest/models/christmas_carol.dart';
import 'package:hymns_latest/services/christmas_carols_service.dart';
import 'package:hymns_latest/theme/christmas_theme.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';

/// Dialog for adding a new Christmas Carol.
///
/// Features:
/// - Church name and song title input
/// - Lyrics text input OR PDF upload (at least one required)
/// - Scale/Key selection
/// - Transpose setting
/// - File validation (PDF only, max 10MB)
class AddCarolDialog extends StatefulWidget {
  final String? prefilledChurchName;

  const AddCarolDialog({super.key, this.prefilledChurchName});

  @override
  State<AddCarolDialog> createState() => _AddCarolDialogState();
}

class _AddCarolDialogState extends State<AddCarolDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _songNumberController = TextEditingController();
  late final TextEditingController _churchController;
  final _lyricsController = TextEditingController();

  String _selectedScale = 'C Major';
  int _transpose = 0;
  bool _hasChords = true;
  File? _selectedPdf;
  String? _pdfFileName;
  bool _isSubmitting = false;

  static const int _maxPdfSizeBytes = 10 * 1024 * 1024; // 10MB

  @override
  void initState() {
    super.initState();
    _churchController =
        TextEditingController(text: widget.prefilledChurchName ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _songNumberController.dispose();
    _churchController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Validate file size
        if (file.size > _maxPdfSizeBytes) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text('PDF file must be less than 10MB'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (file.path != null) {
          setState(() {
            _selectedPdf = File(file.path!);
            _pdfFileName = file.name;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text('Error picking file: $e')),
        );
      }
    }
  }

  void _removePdf() {
    setState(() {
      _selectedPdf = null;
      _pdfFileName = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that at least lyrics or PDF is provided
    final hasLyrics = _lyricsController.text.trim().isNotEmpty;
    final hasPdf = _selectedPdf != null;

    if (!hasLyrics && !hasPdf) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          duration: const Duration(milliseconds: 1500),
          content: Text('Please provide either lyrics or a PDF file'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = true);

    // Store service reference before async operations
    final carolsService = context.read<ChristmasCarolsService>();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await HapticFeedbackManager.lightClick();

      final carol = await carolsService.addCarol(
        title: _titleController.text.trim(),
        songNumber: _songNumberController.text.trim().isEmpty
            ? null
            : _songNumberController.text.trim(),
        churchName: _churchController.text.trim(),
        lyrics: hasLyrics ? _lyricsController.text.trim() : null,
        pdfFile: _selectedPdf,
        transpose: _transpose,
        scale: _selectedScale,
        hasChords: _hasChords,
      );

      if (mounted) {
        navigator.pop(carol);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        scaffoldMessenger.showSnackBar(SnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text('Error adding carol: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ChristmasColors.christmasRed.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ChristmasColors.christmasRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Christmas Carol',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Share a song with the community',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Song number
                      TextFormField(
                        controller: _songNumberController,
                        decoration: InputDecoration(
                          labelText: 'Song Number (optional)',
                          hintText: 'e.g., 1, 25, A1',
                          prefixIcon: const Icon(Icons.numbers),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 16),

                      // Song title
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Song Title *',
                          hintText: 'e.g., Silent Night',
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the song title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Church name
                      TextFormField(
                        controller: _churchController,
                        decoration: InputDecoration(
                          labelText: 'Church Name *',
                          hintText: 'e.g., St. Mary\'s Church',
                          prefixIcon: const Icon(Icons.church),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the church name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Scale selection (only show if has chords)
                      if (_hasChords)
                        DropdownButtonFormField<String>(
                          value: _selectedScale,
                          decoration: InputDecoration(
                            labelText: 'Key / Scale',
                            prefixIcon: const Icon(Icons.piano),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: MusicalScales.allScales.map((scale) {
                            return DropdownMenuItem(
                              value: scale,
                              child: Text(scale),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedScale = value);
                            }
                          },
                        ),
                      if (_hasChords) const SizedBox(height: 16),

                      // Transpose (only show if has chords)
                      if (_hasChords)
                        Row(
                          children: [
                            Expanded(
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Transpose',
                                  prefixIcon: const Icon(Icons.swap_vert),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                          Icons.remove_circle_outline),
                                      onPressed: _transpose > -12
                                          ? () => setState(() => _transpose--)
                                          : null,
                                    ),
                                    Text(
                                      _transpose == 0
                                          ? '0'
                                          : (_transpose > 0
                                              ? '+$_transpose'
                                              : '$_transpose'),
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon:
                                          const Icon(Icons.add_circle_outline),
                                      onPressed: _transpose < 12
                                          ? () => setState(() => _transpose++)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_hasChords) const SizedBox(height: 16),

                      // Has Chords checkbox
                      CheckboxListTile(
                        title: const Text('Contains chord notation'),
                        subtitle: const Text(
                            'Uncheck if the PDF/lyrics has no chords'),
                        value: _hasChords,
                        onChanged: (value) {
                          setState(() => _hasChords = value ?? true);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 16),

                      // Divider with text
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Content (at least one required)',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Lyrics input
                      TextFormField(
                        controller: _lyricsController,
                        decoration: InputDecoration(
                          labelText: 'Lyrics (optional)',
                          hintText: 'Enter the song lyrics here...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),

                      // PDF upload
                      OutlinedButton.icon(
                        onPressed: _pickPdf,
                        icon: Icon(
                          _selectedPdf != null
                              ? Icons.check_circle
                              : Icons.upload_file,
                          color: _selectedPdf != null
                              ? ChristmasColors.christmasGreen
                              : null,
                        ),
                        label: Text(
                          _selectedPdf != null
                              ? _pdfFileName ?? 'PDF Selected'
                              : 'Upload PDF (optional)',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          side: BorderSide(
                            color: _selectedPdf != null
                                ? ChristmasColors.christmasGreen
                                : colorScheme.outline,
                          ),
                        ),
                      ),
                      if (_selectedPdf != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _removePdf,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remove PDF'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.add),
                    label: Text(_isSubmitting ? 'Adding...' : 'Add Carol'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ChristmasColors.christmasRed,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
