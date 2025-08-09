import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import '../widgets/search_bar.dart' as custom;
import 'package:hymns_latest/keerthanes_def.dart';
import 'package:hymns_latest/keerthane_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animations/animations.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';

class KeerthaneScreen extends StatefulWidget {
  const KeerthaneScreen({super.key});

  @override
  _KeerthaneScreenState createState() => _KeerthaneScreenState();
}

class _KeerthaneScreenState extends State<KeerthaneScreen> {
  List<Keerthane> keerthane = [];
  List<Keerthane> filteredKeerthane = [];
  String? _orderBy = 'number';
  String? _searchQuery;
  String? _selectedLanguage;
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = true;

  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTopButton = false;

  @override
  void initState() {
    super.initState();
    loadKeerthane().then((data) {
      if (mounted) {
        setState(() {
          keerthane = data;
          _sortAndFilterKeerthanes();
          _isLoading = false;
        });
      }
    });
    _scrollController.addListener(_scrollListener);
    checkAndUpdateLyricsOnOpen();
  }

  Future<void> checkAndUpdateLyricsOnOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateTimestamp = prefs.getInt('lastLyricsUpdateKeerthane') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updateInterval = const Duration(days: 3).inMilliseconds;

    if (now - lastUpdateTimestamp >= updateInterval) {
      try {
        final response = await http.get(Uri.parse('https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/keerthane_data.json'));

        if (response.statusCode == 200) {
          final List<Keerthane> updatedKeerthane = await loadKeerthaneFromNetwork(response.body);
          if (mounted) {
            setState(() {
              keerthane = updatedKeerthane;
              _sortAndFilterKeerthanes();
            });
            await prefs.setInt('lastLyricsUpdateKeerthane', now);
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Keerthane lyrics updated successfully!'),
                ));
            }
          }
        } else {
          throw Exception('Failed to fetch Keerthane data from cloud');
        }
      } catch (e) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Failed to update Keerthane lyrics. Please try again later.'),
            ));
        }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Row(
            children: [
              Icon(Icons.refresh, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Refresh Keerthane?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We\'ll fetch any updated and corrected Keerthane lyrics from the cloud.',
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
    if (mounted) setState(() => _isLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          title: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: _isLoading ? const CircularProgressIndicator(strokeWidth: 2) : const SizedBox(),
              ),
              const SizedBox(width: 8),
              const Text('Updating Keerthane'),
            ],
          ),
          content: SizedBox(
            height: 110,
            width: 110,
            child: Center(
              child: _isLoading
                  ? const SizedBox.shrink()
                  : Lottie.asset('lib/assets/icons/tick-animation.json', width: 80, height: 80),
            ),
          ),
        );
      },
    );

    fetchAndUpdateLyrics().then((_) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Keerthane updated!'),
          content: SizedBox(height: 110, width: 110, child: Lottie.asset('lib/assets/icons/tick-animation.json', width: 80, height: 80)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
          },
        );
      }
    }).catchError((error) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            final colorScheme = Theme.of(context).colorScheme;
            return AlertDialog(
              backgroundColor: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Update failed'),
              content: Text('Failed to update Keerthane lyrics. Please try again later.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      }
    });
  }

  Future<void> fetchAndUpdateLyrics() async {
    try {
      final keerthaneResponse = await http.get(Uri.parse('https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/keerthane_data.json'));

      if (keerthaneResponse.statusCode == 200) {
        final updatedKeerthanas = await loadKeerthaneFromNetwork(keerthaneResponse.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('keerthaneData', jsonEncode(updatedKeerthanas));
        if (mounted) {
          setState(() {
            keerthane = updatedKeerthanas;
            _sortAndFilterKeerthanes();
          });
        }
      } else {
        throw Exception('Failed to fetch Keerthane data from GitHub');
      }
    } catch (e) {
      print('Error updating Keerthane lyrics: $e');
      rethrow;
    }
  }

  void _sortAndFilterKeerthanes() {
    if (!mounted) return;

    List<Keerthane> currentKeerthane = List.from(keerthane);

    // Apply ordering
    if (_orderBy == 'number') {
      currentKeerthane.sort((a, b) => a.number.compareTo(b.number));
    } else if (_orderBy == 'title') {
      currentKeerthane.sort((a, b) => a.title.compareTo(b.title));
    }

    // Apply language filter (if selected)
    if (_selectedLanguage == 'English') {
      currentKeerthane = currentKeerthane.where((k) => k.lyrics.isNotEmpty).toList();
    } else if (_selectedLanguage == 'Kannada') {
      currentKeerthane = currentKeerthane.where((k) => k.kannadaLyrics != null && k.kannadaLyrics!.isNotEmpty).toList();
    }

    // Apply search query
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      final query = _searchQuery!.toLowerCase().trim();
      currentKeerthane = currentKeerthane.where((k) =>
        k.title.toLowerCase().contains(query) ||
        k.number.toString().contains(query)
      ).toList();
    }

    setState(() {
      filteredKeerthane = currentKeerthane;
    });
  }

  // Deprecated popup filter removed in favor of chips

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (mounted) {
      setState(() {
        _showScrollToTopButton = _scrollController.offset >= 400;
      });
    }
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
        toolbarHeight: 140, // match hymns to avoid overflow
        backgroundColor: colorScheme.surface,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    custom.SearchBar(
                      hintText: 'Search Keerthane (Number, Title)',
                      onChanged: (searchQuery) {
                        setState(() {
                          _searchQuery = searchQuery;
                          _sortAndFilterKeerthanes();
                        });
                      },
                      focusNode: _searchFocusNode,
                      onQueryCleared: () {
                        setState(() {
                          _searchQuery = null;
                          _sortAndFilterKeerthanes();
                          Future.delayed(const Duration(milliseconds: 100), () {
                            _searchFocusNode.unfocus();
                          });
                        });
                      },
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      searchIconColor: colorScheme.onSurfaceVariant,
                      clearIconColor: colorScheme.onSurfaceVariant,
                      textStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
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
                              selected: _orderBy == 'number',
                              onSelected: (s) async { await HapticFeedbackManager.lightClick(); setState(() { _orderBy = 'number'; _sortAndFilterKeerthanes(); }); },
                              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              selectedColor: colorScheme.primaryContainer,
                              backgroundColor: colorScheme.surfaceContainerHigh,
                              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            ChoiceChip(
                              label: const Text('Title'),
                              selected: _orderBy == 'title',
                              onSelected: (s) async { await HapticFeedbackManager.lightClick(); setState(() { _orderBy = 'title'; _sortAndFilterKeerthanes(); }); },
                              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              selectedColor: colorScheme.primaryContainer,
                              backgroundColor: colorScheme.surfaceContainerHigh,
                              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                        const Spacer(),
                        ActionChip(
                          label: const Text('Refresh'),
                          avatar: const Icon(Icons.refresh, size: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          shape: const StadiumBorder(),
                          backgroundColor: colorScheme.primary.withOpacity(0.10),
                          onPressed: () async { await HapticFeedbackManager.lightClick(); await checkAndUpdateLyrics(); },
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
                  if (_isLoading && keerthane.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else if (filteredKeerthane.isEmpty && (_searchQuery != null && _searchQuery!.isNotEmpty))
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset('lib/assets/lottie/search-empty.json', width: 200, height: 200),
                          const SizedBox(height: 16),
                          Text('No Keerthane found for "$_searchQuery".', style: textTheme.titleMedium, textAlign: TextAlign.center,),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 8.0),
                      itemCount: filteredKeerthane.length,
                      itemBuilder: (context, index) {
                        final keerthaneItem = filteredKeerthane[index];
                        return _buildKeerthaneListTile(keerthaneItem, colorScheme, textTheme);
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

  Widget _buildKeerthaneListTile(Keerthane keerthaneItem, ColorScheme colorScheme, TextTheme textTheme) {
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
            child: Image.asset(
              'lib/assets/icons/keerthane.png',
            ),
          ),
        ),
        title: Text(
          'Keerthane ${keerthaneItem.number}: ${keerthaneItem.title}',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
        ),
        trailing: Icon(Icons.chevron_right, color: colorScheme.secondary),
        onTap: () {
          HapticFeedbackManager.lightClick();
          Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (context, animation, secondaryAnimation) => KeerthaneDetailScreen(keerthane: keerthaneItem),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SharedAxisTransition(
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  transitionType: SharedAxisTransitionType.horizontal, // Use a suitable transition type like SLIDE
                  child: child,
                );
              },
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      ),
    );
  }
}
