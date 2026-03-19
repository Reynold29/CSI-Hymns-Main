import 'dart:convert';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hymns_latest/hymns_def.dart';
import '../widgets/search_bar.dart' as custom;
import 'package:hymns_latest/hymn_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animations/animations.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';

class HymnsScreen extends StatefulWidget {
  const HymnsScreen({super.key});

  @override
  _HymnsScreenState createState() => _HymnsScreenState();
}

class _HymnsScreenState extends State<HymnsScreen> {
  List<Hymn> hymns = [];
  List<Hymn> filteredHymns = [];
  Map<String, List<Hymn>> groupedHymns = {};

  /// Global keys for each meter group header in the list view, used to
  /// scroll precisely to the start of a group via [Scrollable.ensureVisible].
  final Map<String, GlobalKey> _meterGroupKeys = {};
  String? _selectedOrder = 'number';
  String? _searchQuery;
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadHymns().then((data) {
      if (!mounted) return;
      setState(() {
        hymns = data;
        _applySortAndFilter();
        _scrollController.addListener(_scrollListener);
      });
    });
    checkAndUpdateLyricsOnOpen();
  }

  Future<void> checkAndUpdateLyricsOnOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateTimestamp = prefs.getInt('lastLyricsUpdate') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updateInterval = const Duration(days: 3).inMilliseconds;

    if (now - lastUpdateTimestamp >= updateInterval) {
      try {
        final response = await http.get(Uri.parse(
            'https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/hymns_data.json'));

        if (response.statusCode == 200) {
          final List<Hymn> updatedHymns =
              await loadHymnsFromNetwork(response.body);

          if (!mounted) return;
          setState(() {
            hymns = updatedHymns;
            _applySortAndFilter();
          });

          await prefs.setInt('lastLyricsUpdate', now);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                duration: const Duration(milliseconds: 1500),
                content: Text('Lyrics updated successfully!'),
              ));
        } else {
          throw Exception('Failed to fetch data from cloud');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text('Failed to update lyrics. Please try again later.'),
            ));
      }
    }
  }

  Future<void> checkAndUpdateLyrics() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Icon(Icons.refresh, color: colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Refresh lyrics?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We\'ll fetch any updated and corrected lyrics from the cloud.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
            ],
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _showUpdateDialog();
    }
  }

  void _showUpdateDialog() {
    setState(() {
      _isLoading = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              title: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: _isLoading
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const SizedBox(),
                  ),
                  const SizedBox(width: 8),
                  const Text('Updating lyrics'),
                ],
              ),
              content: SizedBox(
                height: 110,
                width: 110,
                child: Center(
                  child: _isLoading
                      ? const SizedBox.shrink()
                      : Lottie.asset('lib/assets/icons/tick-animation.json'),
                ),
              ),
            );
          },
        );
      },
    );

    fetchAndUpdateLyrics().then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: colorScheme.surfaceContainerHigh,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Lyrics updated!'),
            content: SizedBox(
                height: 110,
                width: 110,
                child: Lottie.asset('lib/assets/icons/tick-animation.json')),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (BuildContext context) {
          final colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: colorScheme.surfaceContainerHigh,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Update failed'),
            content: Text('Failed to update lyrics. Please try again later.',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> fetchAndUpdateLyrics() async {
    try {
      final hymnsResponse = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/hymns_data.json'));

      if (hymnsResponse.statusCode == 200) {
        final updatedHymns = await loadHymnsFromNetwork(hymnsResponse.body);

        // Store updated data in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('hymnsData', jsonEncode(updatedHymns));

        setState(() {
          hymns = updatedHymns;
          _sortHymns();
        });
      } else {
        throw Exception('Failed to fetch data from GitHub');
      }
    } catch (e) {
      debugPrint('HymnsScreen: Error updating lyrics: $e');
      rethrow;
    }
  }

  /// Sorts hymns and re-applies the current filter. Call inside setState.
  void _applySortAndFilter() {
    _sortHymns();
    _applyFilter();
  }

  /// Mutates sort order. Must be called inside setState.
  void _sortHymns() {
    if (_selectedOrder == 'number') {
      hymns.sort((a, b) => a.number.compareTo(b.number));
      filteredHymns = List.from(hymns);
    } else if (_selectedOrder == 'title') {
      hymns.sort((a, b) => a.title.compareTo(b.title));
      filteredHymns = List.from(hymns);
    } else if (_selectedOrder == 'time_signature') {
      hymns.sort((a, b) => a.signature.compareTo(b.signature));
      _groupHymnsBySignature(); // builds groupedHymns
      filteredHymns = groupedHymns.values.expand((x) => x).toList();
    }
  }

  /// Mutates filteredHymns / groupedHymns based on current query. Must be called inside setState.
  void _applyFilter() {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      if (_selectedOrder == 'time_signature') {
        // Groups already built by _sortHymns — just expose all hymns.
        filteredHymns = groupedHymns.values.expand((x) => x).toList();
      } else {
        filteredHymns = List.from(hymns);
      }
    } else {
      final query = _searchQuery!.toLowerCase().trim();
      if (_selectedOrder == 'time_signature') {
        final Map<String, List<Hymn>> filtered = {};
        for (final entry in groupedHymns.entries) {
          // Exact group-key match prevents "C.M" hitting "D.C.M".
          final keyMatches = entry.key.toLowerCase() == query;
          final matchingHymns = entry.value
              .where((hymn) =>
                  keyMatches ||
                  hymn.title.toLowerCase().contains(query) ||
                  hymn.number.toString().contains(query))
              .toList();
          if (matchingHymns.isNotEmpty) filtered[entry.key] = matchingHymns;
        }
        groupedHymns = filtered;
        filteredHymns = groupedHymns.values.expand((x) => x).toList();
      } else {
        filteredHymns = hymns.where((hymn) {
          return hymn.title.toLowerCase().contains(query) ||
              hymn.number.toString().contains(query) ||
              hymn.signature.toLowerCase().contains(query);
        }).toList();
      }
    }
  }

  /// Returns true if a signature part is a tune reference (not a real meter).
  bool _isTuneReference(String part) {
    if (part.startsWith('(') && part.endsWith(')')) return true;
    final bareRef = RegExp(r'^(Mang\.T\.B\.|M\.T\.)\d', caseSensitive: false);
    return bareRef.hasMatch(part);
  }

  void _groupHymnsBySignature() {
    groupedHymns.clear();
    for (var hymn in hymns) {
      final parts = hymn.signature
          .split(' / ')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final realMeters = parts.where((p) => !_isTuneReference(p)).toList();
      final groupKeys = realMeters.isNotEmpty ? realMeters : [hymn.signature];
      for (final key in groupKeys) {
        groupedHymns.putIfAbsent(key, () => []).add(hymn);
      }
    }
  }

  /// Shows a bottom sheet listing all meter groups; tapping one scrolls to it.
  void _showMeterJumpSheet() {
    // Sort groups by hymn count descending.
    final sortedGroups = groupedHymns.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, sheetController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Row(
                    children: [
                      Icon(Icons.music_note_rounded,
                          color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Jump to Meter',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${sortedGroups.length} groups',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: sheetController,
                    itemCount: sortedGroups.length,
                    itemBuilder: (_, i) {
                      final entry = sortedGroups[i];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${entry.value.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(
                          entry.key.isEmpty ? '(No meter)' : entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: colorScheme.onSurfaceVariant),
                        onTap: () {
                          Navigator.pop(ctx);

                          // Step 1 (after sheet closes): jump to precise
                          // position so ListView builds the target item.
                          Future.delayed(
                            const Duration(milliseconds: 220),
                            () {
                              if (!_scrollController.hasClients) return;

                              // Precise cumulative offset — same height
                              // constants as the real widget tree so the
                              // jumpTo lands exactly on the target group.
                              const double kCardMargin = 16.0; // 8+8
                              const double kCardPadding = 24.0; // 12+12
                              const double kHeader = 28.0; // title+gap
                              const double kTile = 72.0; // card+tile
                              const double kTopPad = 8.0;

                              double preciseOffset = kTopPad;
                              for (final grp in groupedHymns.entries) {
                                if (grp.key == entry.key) break;
                                preciseOffset += kCardMargin +
                                    kCardPadding +
                                    kHeader +
                                    grp.value.length * kTile;
                              }
                              final clampedOffset = preciseOffset.clamp(
                                0.0,
                                _scrollController.position.maxScrollExtent,
                              );
                              _scrollController.jumpTo(clampedOffset);

                              // Step 2: now the item is built — ensureVisible
                              // gives pixel-perfect alignment to the top.
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final key = _meterGroupKeys[entry.key];
                                final ctx2 = key?.currentContext;
                                if (ctx2 != null) {
                                  Scrollable.ensureVisible(
                                    ctx2,
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                    alignment: 0.0,
                                  );
                                }
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Deprecated popup filter removed in favor of chips

  bool _showScrollToTopButton = false;

  void _scrollListener() {
    setState(() {
      _showScrollToTopButton = _scrollController.offset >= 400;
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        toolbarHeight: 140, // Slightly larger to avoid overflow with chips
        backgroundColor: colorScheme.surface,
        flexibleSpace: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    custom.SearchBar(
                      hintText: 'Search Hymns (Number, Title, Meter)',
                      onChanged: (searchQuery) {
                        setState(() {
                          _searchQuery = searchQuery;
                          _applyFilter();
                        });
                      },
                      focusNode: _searchFocusNode,
                      onQueryCleared: () {
                        setState(() {
                          _searchQuery = null;
                          _applySortAndFilter();
                          Future.delayed(const Duration(milliseconds: 100), () {
                            _searchFocusNode.unfocus();
                          });
                        });
                      },
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      searchIconColor: colorScheme.onSurfaceVariant,
                      clearIconColor: colorScheme.onSurfaceVariant,
                      textStyle: textTheme.bodyLarge
                          ?.copyWith(color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 0,
                          children: [
                            ChoiceChip(
                              label: const Text('Number'),
                              selected: _selectedOrder == 'number',
                              onSelected: (s) async {
                                await HapticFeedbackManager.lightClick();
                                setState(() {
                                  _selectedOrder = 'number';
                                  _sortHymns();
                                });
                              },
                              labelStyle: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                              labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              selectedColor: colorScheme.primaryContainer,
                              backgroundColor: colorScheme.surfaceContainerHigh,
                              visualDensity: const VisualDensity(
                                  horizontal: -2, vertical: -2),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            ChoiceChip(
                              label: const Text('Meter'),
                              selected: _selectedOrder == 'time_signature',
                              onSelected: (s) async {
                                await HapticFeedbackManager.lightClick();
                                setState(() {
                                  _selectedOrder = 'time_signature';
                                  _sortHymns();
                                });
                              },
                              labelStyle: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                              labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              selectedColor: colorScheme.primaryContainer,
                              backgroundColor: colorScheme.surfaceContainerHigh,
                              visualDensity: const VisualDensity(
                                  horizontal: -2, vertical: -2),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Jump-to-meter button — only visible in Meter view
                        if (_selectedOrder == 'time_signature') ...[
                          Tooltip(
                            message: 'Jump to meter',
                            child: IconButton(
                              icon: const Icon(
                                  Icons.format_list_bulleted_rounded),
                              onPressed: () async {
                                await HapticFeedbackManager.lightClick();
                                _showMeterJumpSheet();
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: colorScheme.primaryContainer,
                                foregroundColor: colorScheme.onPrimaryContainer,
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (_selectedOrder != 'time_signature')
                          ActionChip(
                            label: const Text('Refresh'),
                            avatar: const Icon(Icons.refresh, size: 16),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 2),
                            labelStyle: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            shape: const StadiumBorder(),
                            backgroundColor:
                                colorScheme.primary.withOpacity(0.10),
                            onPressed: () async {
                              await HapticFeedbackManager.lightClick();
                              await checkAndUpdateLyrics();
                            },
                          ),
                      ],
                    )
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8.0),
                    itemCount: _selectedOrder == 'time_signature'
                        ? groupedHymns.keys.length
                        : filteredHymns.length,
                    itemBuilder: (context, index) {
                      if (_selectedOrder == 'time_signature') {
                        String signature = groupedHymns.keys.elementAt(index);
                        List<Hymn> hymnsInSignature = groupedHymns[signature]!;
                        // hymnsInSignature is already filtered by _filterHymns();
                        // no need to re-filter here.
                        if (hymnsInSignature.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final groupKey = _meterGroupKeys.putIfAbsent(
                          signature,
                          () => GlobalKey(),
                        );

                        return Container(
                          key: groupKey,
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                  color: colorScheme.outlineVariant, width: 1),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(
                                      signature.isEmpty
                                          ? '(No meter)'
                                          : signature,
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  ...hymnsInSignature
                                      .map((hymn) => _buildHymnListTile(hymn)),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        final hymn = filteredHymns[index];
                        return _buildHymnListTile(hymn);
                      }
                    },
                  ),
                  if (_showScrollToTopButton)
                    Positioned(
                      bottom: 16,
                      right: 0,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: _scrollToTop,
                        backgroundColor: colorScheme.tertiaryContainer,
                        foregroundColor: colorScheme.onTertiaryContainer,
                        elevation: 3.0,
                        child: const Icon(Icons.arrow_upward),
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

  Widget _buildHymnListTile(Hymn hymn) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
      child: ListTile(
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0.0),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Image.asset('lib/assets/icons/hymn.png'),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important for Column in ListTile
          children: [
            _buildHighlightedTitle(
                'Hymn ${hymn.number}: ${hymn.title}',
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                colorScheme),
            if (hymn.signature.isNotEmpty) ...[
              const SizedBox(height: 4.0), // Gap between title and subtitle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  hymn.signature,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ]
          ],
        ),
        // subtitle property is removed as it's now part of the title Column
        trailing: Icon(Icons.chevron_right, color: colorScheme.secondary),
        onTap: () {
          HapticFeedbackManager.lightClick();
          Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  HymnDetailScreen(hymn: hymn),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SharedAxisTransition(
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  transitionType: SharedAxisTransitionType
                      .horizontal, // Use a suitable transition type like SLIDE
                  child: child,
                );
              },
            ),
          );
        },
        contentPadding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      ),
    );
  }

  Widget _buildHighlightedTitle(
      String text, TextStyle? baseStyle, ColorScheme colorScheme) {
    final query = _searchQuery?.trim();
    if (query == null || query.isEmpty) {
      return Text(text, style: baseStyle);
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + lowerQuery.length),
        style: baseStyle?.copyWith(
            backgroundColor: colorScheme.primary.withOpacity(0.18)),
      ));
      start = idx + lowerQuery.length;
      if (start >= text.length) break;
    }
    return RichText(text: TextSpan(children: spans));
  }

  void navigateToHymnDetail(BuildContext context, Hymn hymn) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HymnDetailScreen(hymn: hymn)),
    );
  }
}
