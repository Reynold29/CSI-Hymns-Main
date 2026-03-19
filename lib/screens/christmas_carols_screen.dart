import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hymns_latest/models/christmas_carol.dart';
import 'package:hymns_latest/services/supabase_service.dart';
import 'package:hymns_latest/services/christmas_carols_service.dart';
import 'package:hymns_latest/screens/carol_detail_screen.dart';
import 'package:hymns_latest/widgets/add_carol_dialog.dart';
import 'package:hymns_latest/widgets/scrolling_text.dart';
import 'package:hymns_latest/theme/christmas_theme.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';
import 'package:hymns_latest/screens/auth_screen.dart';
import 'package:file_picker/file_picker.dart';

/// Screen displaying the list of Churches/Groups with Christmas Carols.
///
/// Features:
/// - List of churches/groups
/// - Each church shows its uploaded carols
/// - Add Church button for authenticated users
/// - Christmas-themed styling
class ChristmasCarolsScreen extends StatefulWidget {
  const ChristmasCarolsScreen({super.key});

  @override
  State<ChristmasCarolsScreen> createState() => _ChristmasCarolsScreenState();
}

class _ChristmasCarolsScreenState extends State<ChristmasCarolsScreen> {
  Map<String, List<ChristmasCarol>> _churchGroups = {};
  String _searchQuery = '';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCarols(checkGitHub: false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCarols({bool checkGitHub = true}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final carolsService = context.read<ChristmasCarolsService>();
      final carols =
          await carolsService.loadAllCarols(checkGitHub: checkGitHub);

      if (!mounted) return;

      // Group carols by church name
      final Map<String, List<ChristmasCarol>> groups = {};
      for (final carol in carols) {
        final churchName = carol.churchName;
        if (!groups.containsKey(churchName)) {
          groups[churchName] = [];
        }
        groups[churchName]!.add(carol);
      }

      setState(() {
        _churchGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text('Error loading carols: $e')),
      );
    }
  }

  List<String> get _filteredChurches {
    if (_searchQuery.isEmpty) {
      return _churchGroups.keys.toList();
    }
    final lowerQuery = _searchQuery.toLowerCase();
    return _churchGroups.keys.where((church) {
      if (church.toLowerCase().contains(lowerQuery)) return true;
      // Also search in carols of this church
      final carols = _churchGroups[church] ?? [];
      return carols.any((c) =>
          c.title.toLowerCase().contains(lowerQuery) ||
          c.scale.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  Future<void> _showAddChurchDialog() async {
    final user = SupabaseService().currentUser;

    if (user == null) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign in Required'),
          content: const Text(
            'You need to be signed in to add content. '
            'Would you like to sign in now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: ChristmasColors.christmasRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );

      if (result == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
        setState(() {});
      }
      return;
    }

    // Show add church dialog
    final churchNameController = TextEditingController();
    final churchName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('🏛️ '),
            Text('Add Church / Group'),
          ],
        ),
        content: TextField(
          controller: churchNameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Church or Group Name',
            hintText: 'e.g., St. Mary\'s Church',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = churchNameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (churchName != null && churchName.isNotEmpty && mounted) {
      // Show options to add song or upload PDF
      await _showAddContentOptions(churchName);
    }
  }

  Future<void> _showAddContentOptions(String churchName) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add to "$churchName"',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose what you want to add:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              // Add Song option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ChristmasColors.christmasGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: ChristmasColors.christmasGreen,
                  ),
                ),
                title: const Text('Add Song with Lyrics'),
                subtitle: const Text('Enter song title, lyrics, and scale'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(context);
                  await _showAddSongDialog(churchName);
                },
              ),
              const SizedBox(height: 8),
              // Upload PDF option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ChristmasColors.christmasRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: ChristmasColors.christmasRed,
                  ),
                ),
                title: const Text('Upload PDF'),
                subtitle: const Text('Upload a PDF file of the song'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(context);
                  await _uploadPdf(churchName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSongDialog(String churchName) async {
    final newCarol = await showDialog<ChristmasCarol>(
      context: context,
      builder: (context) => AddCarolDialog(prefilledChurchName: churchName),
    );

    if (newCarol != null && mounted) {
      await _loadCarols();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 1500),
          content: Text('Added "${newCarol.title}"'),
          backgroundColor: ChristmasColors.christmasGreen,
        ),
      );
    }
  }

  Future<void> _uploadPdf(String churchName) async {
    // Pick PDF file (file_picker handles permissions internally)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text('Could not access the file')),
        );
      }
      return;
    }

    // Get song title from file name or ask user
    final fileName = file.name.replaceAll('.pdf', '');
    final titleController = TextEditingController(text: fileName);

    final songTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Song Title'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Enter song title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(context, title);
              }
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (songTitle == null || songTitle.isEmpty) return;

    // Show loading
    if (mounted) {
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
                  Text('Uploading PDF...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final carolsService = context.read<ChristmasCarolsService>();
      final carol = await carolsService.addCarolWithPdf(
        title: songTitle,
        churchName: churchName,
        pdfPath: file.path!,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        await _loadCarols();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text('Uploaded "${carol.title}"'),
            backgroundColor: ChristmasColors.christmasGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text('Error uploading PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final user = SupabaseService().currentUser;
    final isAuthenticated = user != null;
    final churches = _filteredChurches;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎄 '),
            Text(
              'Christmas Carols',
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh and sync with server',
            onPressed: () async {
              await HapticFeedbackManager.lightClick();
              await _loadCarols(checkGitHub: false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Refreshed from server'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadCarols(checkGitHub: false);
        },
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (query) => setState(() => _searchQuery = query),
                decoration: InputDecoration(
                  hintText: 'Search churches or songs...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _searchFocusNode.unfocus();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            // Churches list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : churches.isEmpty
                      ? _buildEmptyState(colorScheme, textTheme)
                      : _buildChurchesList(churches, colorScheme, textTheme),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await HapticFeedbackManager.lightClick();
          await _showAddChurchDialog();
        },
        icon: Icon(
          isAuthenticated ? Icons.add_business : Icons.lock_outline,
          color: isAuthenticated ? Colors.white : colorScheme.onSurface,
        ),
        label: Text(
          isAuthenticated ? 'Add Church' : 'Login to Add',
          style: TextStyle(
            color: isAuthenticated ? Colors.white : colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isAuthenticated
            ? ChristmasColors.christmasRed
            : colorScheme.surfaceContainerHigh,
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.church_rounded,
            size: 64,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No churches added yet'
                : 'No churches found for "$_searchQuery"',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Add your church to share carols!'
                : 'Try a different search term',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChurchesList(
      List<String> churches, ColorScheme colorScheme, TextTheme textTheme) {
    final carolsService = context.read<ChristmasCarolsService>();

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
      itemCount: churches.length,
      itemBuilder: (context, index) {
        final churchName = churches[index];
        final carols = _churchGroups[churchName] ?? [];
        return _ChurchCard(
          churchName: churchName,
          carolCount: carols.length,
          hasPdfs: carols.any((c) => c.hasPdf),
          isAdmin: carolsService.isAdmin,
          onTap: () async {
            await HapticFeedbackManager.lightClick();
            if (mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChurchCarolsScreen(
                    churchName: churchName,
                    carols: carols,
                  ),
                ),
              );
              // Refresh after returning
              _loadCarols();
            }
          },
          onAddTap: () async {
            await HapticFeedbackManager.lightClick();
            final user = SupabaseService().currentUser;
            if (user == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    duration: const Duration(milliseconds: 1500),
                    content: Text('Please login to add content')),
              );
              return;
            }
            await _showAddContentOptions(churchName);
          },
          onDeleteTap: carolsService.canDeleteChurch(churchName)
              ? () async {
                  await HapticFeedbackManager.mediumClick();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Church?'),
                      content: Text(
                        'Are you sure you want to delete "$churchName" and ALL its carols?\n\n'
                        'This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.red),
                          child: const Text('Delete All'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && mounted) {
                    try {
                      await carolsService.deleteChurch(churchName);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            duration: const Duration(milliseconds: 1500),
                            content: Text(
                                'Deleted "$churchName" and all its carols')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            duration: const Duration(milliseconds: 1500),
                            content: Text('Error: $e')),
                      );
                    }
                  }
                }
              : null,
        );
      },
    );
  }
}

/// Card widget for each church/group
class _ChurchCard extends StatelessWidget {
  final String churchName;
  final int carolCount;
  final bool hasPdfs;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onAddTap;
  final VoidCallback? onDeleteTap;

  const _ChurchCard({
    required this.churchName,
    required this.carolCount,
    required this.hasPdfs,
    this.isAdmin = false,
    required this.onTap,
    required this.onAddTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Church icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ChristmasColors.christmasRed.withOpacity(0.1),
                      ChristmasColors.christmasGreen.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('🏛️', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              // Church info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScrollingText(
                      text: churchName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      scrollDuration: const Duration(seconds: 8),
                      pauseDuration: const Duration(seconds: 1),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.music_note_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$carolCount ${carolCount == 1 ? 'carol' : 'carols'}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (hasPdfs) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 14,
                            color: ChristmasColors.christmasRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'PDFs',
                            style: textTheme.bodySmall?.copyWith(
                              color: ChristmasColors.christmasRed,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Admin delete button
              if (isAdmin && onDeleteTap != null)
                IconButton(
                  onPressed: onDeleteTap,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  tooltip: 'Delete church (Admin)',
                ),
              // Add button
              IconButton(
                onPressed: onAddTap,
                icon: Icon(
                  Icons.add_circle_outline,
                  color: ChristmasColors.christmasGreen,
                ),
                tooltip: 'Add carol',
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen showing carols for a specific church
class ChurchCarolsScreen extends StatefulWidget {
  final String churchName;
  final List<ChristmasCarol> carols;

  const ChurchCarolsScreen({
    super.key,
    required this.churchName,
    required this.carols,
  });

  @override
  State<ChurchCarolsScreen> createState() => _ChurchCarolsScreenState();
}

class _ChurchCarolsScreenState extends State<ChurchCarolsScreen> {
  late List<ChristmasCarol> _carols;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _carols = _sortCarols(List.from(widget.carols));
    _searchController.addListener(_onSearchChanged);
  }

  List<ChristmasCarol> _sortCarols(List<ChristmasCarol> carols) {
    if (_sortOrder == 'newest') {
      // Sort by newest to oldest
      carols.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
    } else {
      // Sort: First by song number (ascending), then by newest to oldest if no song number
      carols.sort((a, b) {
        // If both have song numbers, sort by number (ascending)
        if (a.songNumber != null && b.songNumber != null) {
          // Try to parse as numbers for proper numeric sorting
          final aNum = int.tryParse(a.songNumber!) ?? 0;
          final bNum = int.tryParse(b.songNumber!) ?? 0;
          if (aNum != 0 && bNum != 0) {
            return aNum.compareTo(bNum);
          }
          // If not pure numbers, sort alphabetically
          return a.songNumber!.compareTo(b.songNumber!);
        }
        // If only one has a number, prioritize it
        if (a.songNumber != null && b.songNumber == null) return -1;
        if (a.songNumber == null && b.songNumber != null) return 1;
        // If neither has a number, sort by newest to oldest
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
    }
    return carols;
  }

  String _sortOrder = 'number'; // 'number' or 'newest'

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<ChristmasCarol> get _filteredCarols {
    List<ChristmasCarol> filtered;
    if (_searchQuery.isEmpty) {
      filtered = List.from(_carols);
    } else {
      filtered = _carols.where((carol) {
        final titleMatch = carol.title.toLowerCase().contains(_searchQuery);
        final numberMatch =
            carol.songNumber?.toLowerCase().contains(_searchQuery) ?? false;
        return titleMatch || numberMatch;
      }).toList();
    }

    // Always sort by song number first, then by date
    return _sortCarols(filtered);
  }

  Future<void> _refreshCarols() async {
    final service = context.read<ChristmasCarolsService>();
    await service.loadAllCarols(checkGitHub: false);
    // Update local list with carols for this church
    setState(() {
      final churchCarols = service.carols
          .where((c) => c.churchName == widget.churchName)
          .toList();
      _carols = _sortCarols(churchCarols);
    });
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('By Song Number'),
              subtitle: const Text('Songs with numbers first, then newest'),
              value: 'number',
              groupValue: _sortOrder,
              onChanged: (value) {
                setState(() {
                  _sortOrder = value!;
                  _carols = _sortCarols(_carols);
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Newest First'),
              subtitle: const Text('Most recently added first'),
              value: 'newest',
              groupValue: _sortOrder,
              onChanged: (value) {
                setState(() {
                  _sortOrder = value!;
                  _carols = _sortCarols(_carols);
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddContentOptions() async {
    final user = SupabaseService().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text('Please login to add content')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add to "${widget.churchName}"',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ChristmasColors.christmasGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: ChristmasColors.christmasGreen,
                  ),
                ),
                title: const Text('Add Song with Lyrics'),
                subtitle: const Text('Enter song title, lyrics, and scale'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(context);
                  final newCarol = await showDialog<ChristmasCarol>(
                    context: context,
                    builder: (context) =>
                        AddCarolDialog(prefilledChurchName: widget.churchName),
                  );
                  if (newCarol != null) {
                    await _refreshCarols();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          duration: const Duration(milliseconds: 1500),
                          content: Text('Added "${newCarol.title}"'),
                          backgroundColor: ChristmasColors.christmasGreen,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ChristmasColors.christmasRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: ChristmasColors.christmasRed,
                  ),
                ),
                title: const Text('Upload PDF'),
                subtitle: const Text('Upload a PDF file of the song'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(context);
                  await _uploadPdf();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text('Could not access the file')),
        );
      }
      return;
    }

    final fileName = file.name.replaceAll('.pdf', '');
    final titleController = TextEditingController(text: fileName);

    final songTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Song Title'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Enter song title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(context, title);
              }
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (songTitle == null || songTitle.isEmpty) return;

    if (mounted) {
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
                  Text('Uploading PDF...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final carolsService = context.read<ChristmasCarolsService>();
      final carol = await carolsService.addCarolWithPdf(
        title: songTitle,
        churchName: widget.churchName,
        pdfPath: file.path!,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        await _refreshCarols();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text('Uploaded "${carol.title}"'),
            backgroundColor: ChristmasColors.christmasGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text('Error uploading PDF: $e')),
        );
      }
    }
  }

  Future<void> _deleteChurch() async {
    final service = context.read<ChristmasCarolsService>();

    if (!service.canDeleteChurch(widget.churchName)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            duration: const Duration(milliseconds: 1500),
            content:
                Text('Only admins or church creators can delete churches')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Church?'),
        content: Text(
          'Are you sure you want to delete "${widget.churchName}" and ALL its carols (${_carols.length})?\n\n'
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
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await service.deleteChurch(widget.churchName);
        if (mounted) {
          Navigator.pop(context); // Go back to church list
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                duration: const Duration(milliseconds: 1500),
                content: Text('Deleted "${widget.churchName}"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                duration: const Duration(milliseconds: 1500),
                content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final carolsService = context.watch<ChristmasCarolsService>();
    final user = SupabaseService().currentUser;
    final isAuthenticated = user != null;
    final isAdmin = carolsService.isAdmin;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Text('🏛️', style: TextStyle(fontSize: 24)),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ScrollingText(
                    text: widget.churchName,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    scrollDuration: const Duration(seconds: 8),
                    pauseDuration: const Duration(seconds: 1),
                  ),
                ),
                if (isAdmin)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              '${_carols.length} ${_carols.length == 1 ? 'carol' : 'carols'}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh and sync with server',
            onPressed: () async {
              await HapticFeedbackManager.lightClick();
              await _refreshCarols();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Refreshed from server'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: isAdmin ? 'Admin options' : 'Options',
            onSelected: (value) {
              if (value == 'delete') {
                _deleteChurch();
              }
            },
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[];
              final canDelete =
                  carolsService.canDeleteChurch(widget.churchName);

              if (canDelete) {
                items.add(
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Delete Church',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                // Show a disabled item so menu is visible but shows no admin options
                items.add(
                  const PopupMenuItem(
                    enabled: false,
                    child: Text('Admin/Creator only'),
                  ),
                );
              }

              return items;
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshCarols();
        },
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by song name or number...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            // Carols list
            Expanded(
              child: _filteredCarols.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.music_off_rounded,
                            size: 64,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No carols found'
                                : 'No carols yet',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try a different search term'
                                : 'Add the first carol!',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 80),
                      itemCount: _filteredCarols.length,
                      itemBuilder: (context, index) {
                        final carol = _filteredCarols[index];
                        return _CarolListTile(
                          carol: carol,
                          onTap: () async {
                            await HapticFeedbackManager.lightClick();
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CarolDetailScreen(carol: carol),
                              ),
                            );
                            // Refresh after returning
                            _refreshCarols();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Filter button
          FloatingActionButton(
            heroTag: 'filter',
            onPressed: () async {
              await HapticFeedbackManager.lightClick();
              await _showFilterDialog();
            },
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.filter_list,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          // Add Song button
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () async {
              await HapticFeedbackManager.lightClick();
              await _showAddContentOptions();
            },
            icon: Icon(
              isAuthenticated ? Icons.add : Icons.lock_outline,
              color: isAuthenticated ? Colors.white : colorScheme.onSurface,
            ),
            label: Text(
              isAuthenticated ? 'Add Song' : 'Login to Add',
              style: TextStyle(
                color: isAuthenticated ? Colors.white : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: isAuthenticated
                ? ChristmasColors.christmasGreen
                : colorScheme.surfaceContainerHigh,
          ),
        ],
      ),
    );
  }
}

/// Individual carol list tile widget
class _CarolListTile extends StatelessWidget {
  final ChristmasCarol carol;
  final VoidCallback onTap;

  const _CarolListTile({
    required this.carol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Calculate original scale for songs (not PDFs)
    final originalScale =
        MusicalScales.getOriginalScale(carol.scale, carol.transpose);
    final hasTranspose = carol.transpose != 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: carol.hasPdf
                      ? ChristmasColors.christmasRed.withOpacity(0.1)
                      : ChristmasColors.christmasGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  carol.hasPdf
                      ? Icons.picture_as_pdf
                      : Icons.music_note_rounded,
                  color: carol.hasPdf
                      ? ChristmasColors.christmasRed
                      : ChristmasColors.christmasGreen,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (carol.songNumber != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              carol.songNumber!,
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            carol.title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // For PDFs: just show "PDF" badge
                    if (carol.hasPdf && !carol.hasLyrics) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ChristmasColors.christmasRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.picture_as_pdf,
                                size: 12, color: ChristmasColors.christmasRed),
                            const SizedBox(width: 4),
                            Text(
                              'PDF Document',
                              style: TextStyle(
                                fontSize: 11,
                                color: ChristmasColors.christmasRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // For songs: show scale info
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Original Scale
                          _ScaleChip(
                            label: 'Original: $originalScale',
                            color: ChristmasColors.christmasGreen,
                          ),
                          // Transposed Scale (if different)
                          if (hasTranspose) ...[
                            _ScaleChip(
                              label: 'Now: ${carol.scale}',
                              color: Colors.blue,
                            ),
                            _ScaleChip(
                              label: carol.transpose > 0
                                  ? '+${carol.transpose}'
                                  : '${carol.transpose}',
                              color: Colors.orange,
                              icon: Icons.swap_vert,
                            ),
                          ],
                          // PDF badge if also has PDF
                          if (carol.hasPdf)
                            _ScaleChip(
                              label: 'PDF',
                              color: ChristmasColors.christmasRed,
                              icon: Icons.picture_as_pdf,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small chip for scale/transpose info
class _ScaleChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _ScaleChip({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
