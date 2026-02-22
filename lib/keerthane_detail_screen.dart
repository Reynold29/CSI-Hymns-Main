import 'dart:async';
import 'audio_error_handling.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:hymns_latest/keerthanes_def.dart';
import 'package:audio_session/audio_session.dart';
import 'package:favorite_button/favorite_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';
import 'package:hymns_latest/services/supabase_service.dart';
import 'package:hymns_latest/services/jira_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:hymns_latest/screens/tickets_screen.dart';

class KeerthaneDetailScreen extends StatefulWidget {
  final Keerthane keerthane;

  const KeerthaneDetailScreen({super.key, required this.keerthane});

  @override
  _KeerthaneDetailScreenState createState() => _KeerthaneDetailScreenState();
}

class _KeerthaneDetailScreenState extends State<KeerthaneDetailScreen> {
  String selectedLanguage = 'Kannada';
  bool _isFavorite = false;
  bool _isLooping = false;
  double _fontSize = 18.0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isMiniPlayerVisible = false;
  double _playbackSpeed = 1.0;
  bool _isAudioLoading = false;

  final Duration _skipDuration = const Duration(seconds: 5);
  final _audioButtonHeroTag = const Symbol('audioButtonHeroTag');
  final _debugButtonHeroTag = const Symbol('debugButtonHeroTag');
  late StreamSubscription<PlayerState> _playerStateSubscription;

  void _incrementFontSize() async {
    await HapticFeedbackManager.lightClick();
    setState(() {
      _fontSize = (_fontSize + 2).clamp(14.0, 44.0);
    });
  }

  void _decrementFontSize() async {
    await HapticFeedbackManager.lightClick();
    setState(() {
      _fontSize = (_fontSize - 2).clamp(14.0, 44.0);
    });
  }

  @override
  void initState() {
    super.initState();
    _checkIsFavorite();
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((playerState) {
      setState(() {
        _isPlaying = playerState.playing;
        if (playerState.processingState == ProcessingState.completed) {
          _onAudioCompleted();
        }
      });
    });
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    _audioPlayer.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      debugPrint('Playback stream error occurred: $e');
    });

    String keerthaneNumber = widget.keerthane.number.toString();
    String audioUrl = 'https://raw.githubusercontent.com/reynold29/midi-files/main/Keerthane/Keerthane_$keerthaneNumber.ogg';

    try {
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));
      setState(() {
        _isAudioLoading = false;
        _isMiniPlayerVisible = true;
      });
    } catch (e) {
      debugPrint('Error loading audio source in _init: $e');
      setState(() {
        _isAudioLoading = false;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AudioErrorDialog(
            itemNumber: widget.keerthane.number,
            itemType: 'Keerthane',
            songTitle: widget.keerthane.title,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _checkIsFavorite() async {
    final favoriteIds = await _retrieveFavorites();
    setState(() {
      _isFavorite = favoriteIds.contains(widget.keerthane.number);
    });
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await _removeFromFavorites(widget.keerthane);
    } else {
      await _saveToFavorites(widget.keerthane);
    }

    await HapticFeedbackManager.mediumClick();
    await _checkIsFavorite();

    final user = SupabaseService().currentUser;
    if (user != null) {
      try {
        if (_isFavorite) {
          await SupabaseService().addFavorite(itemNumber: widget.keerthane.number, itemType: 'keerthane');
        } else {
          await SupabaseService().removeFavorite(itemNumber: widget.keerthane.number, itemType: 'keerthane');
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _playerStateSubscription.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _toggleAudioPlayback() async {
    await HapticFeedbackManager.lightClick();
    setState(() {
      if (_isPlaying) {
        _audioPlayer.pause();
      } else {
        _audioPlayer.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  void _showFeedbackDialog() async {
    await HapticFeedbackManager.lightClick();
    
    final jiraService = JiraService();
    final descriptionController = TextEditingController();
    
    // Dialog with optional text field
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false, // Not dismissible
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Find something wrong with the lyrics?',
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
              child: const Text('Close'),
              onPressed: () {
                // Create ticket in background and close
                Navigator.pop(context, 'close');
                _createTicketInBackground(
                  jiraService,
                  descriptionController.text.trim(),
                );
              },
            ),
            FilledButton(
              child: const Text('Report'),
              onPressed: () {
                Navigator.pop(context, 'report');
              },
            ),
          ],
        );
      },
    );
    
    if (action == 'report' && mounted) {
      // Close dialog immediately and create ticket
      await _createTicketAndShowSnackBar(
        jiraService,
        descriptionController.text.trim(),
      );
    }
  }
  
  Future<void> _createTicketInBackground(
    JiraService jiraService,
    String? description,
  ) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      
      final result = await jiraService.createTicket(
        songType: 'Keerthane',
        songNumber: widget.keerthane.number,
        songTitle: widget.keerthane.title,
        description: description?.isEmpty ?? true ? null : description,
        appVersion: appVersion,
      );
      
      if (result.success && mounted) {
        _showTicketResultDialog(
          isSuccess: true,
          ticketKey: result.ticketKey ?? 'Ticket',
          ticketUrl: result.ticketUrl,
        );
      } else if (!result.success && mounted) {
        _showTicketResultDialog(
          isSuccess: false,
          errorMessage: result.errorMessage ?? 'Failed to create ticket',
        );
      }
    } catch (e) {
      debugPrint('Error creating ticket in background: $e');
    }
  }
  
  Future<void> _createTicketAndShowSnackBar(
    JiraService jiraService,
    String? description,
  ) async {
    // Show loading dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _TicketCreationDialog(status: _TicketStatus.loading),
    );
    
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      
      final result = await jiraService.createTicket(
        songType: 'Keerthane',
        songNumber: widget.keerthane.number,
        songTitle: widget.keerthane.title,
        description: description?.isEmpty ?? true ? null : description,
        appVersion: appVersion,
      );
      
      if (!mounted) return;
      
      // Close loading dialog and show result
      Navigator.pop(context);
      
      if (result.success) {
        _showTicketResultDialog(
          isSuccess: true,
          ticketKey: result.ticketKey ?? 'Ticket',
          ticketUrl: result.ticketUrl,
        );
      } else {
        _showTicketResultDialog(
          isSuccess: false,
          errorMessage: result.errorMessage ?? 'Failed to create ticket',
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showTicketResultDialog(
        isSuccess: false,
        errorMessage: 'An error occurred: $e',
      );
    }
  }
  
  void _showTicketResultDialog({
    required bool isSuccess,
    String? ticketKey,
    String? ticketUrl,
    String? errorMessage,
  }) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TicketCreationDialog(
        status: isSuccess ? _TicketStatus.success : _TicketStatus.failure,
        ticketKey: ticketKey,
        ticketUrl: ticketUrl,
        errorMessage: errorMessage,
        onClose: () => Navigator.pop(context),
        onViewTicket: ticketKey != null
            ? () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TicketsScreen()),
                );
              }
            : null,
      ),
    );
  }
  

  Future<void> _saveToFavorites(Keerthane keerthane) async {
    final prefs = await SharedPreferences.getInstance();
    final storedIds = prefs.getStringList('favoriteKeerthaneIds') ?? [];

    if (!storedIds.contains(keerthane.number.toString())) {
      storedIds.add(keerthane.number.toString());
      await prefs.setStringList('favoriteKeerthaneIds', storedIds);
    }
  }

  Future<void> _removeFromFavorites(Keerthane keerthane) async {
    final prefs = await SharedPreferences.getInstance();
    final storedIds = prefs.getStringList('favoriteKeerthaneIds') ?? [];

    if (storedIds.contains(keerthane.number.toString())) {
      storedIds.remove(keerthane.number.toString());
      await prefs.setStringList('favoriteKeerthaneIds', storedIds);
    }
  }

  Future<List<int>> _retrieveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final storedData = prefs.getStringList('favoriteKeerthaneIds');
    final favoriteIds = storedData?.map((idStr) => int.parse(idStr)).toList() ?? [];
    return favoriteIds;
  }

  void _toggleMiniPlayerVisibility() async {
    await HapticFeedbackManager.lightClick();
    setState(() {
      _isAudioLoading = true;
    });

    if (!_isMiniPlayerVisible) {
      if (_audioPlayer.audioSource == null) {
        try {
          await _init();
        } catch (e) {
          return;
        }
      } else {
        setState(() {
          _isAudioLoading = false;
          _isMiniPlayerVisible = true;
        });
      }
    } else {
      await _audioPlayer.pause();
      setState(() {
        _isMiniPlayerVisible = false;
        _isAudioLoading = false;
      });
    }

    if (_isMiniPlayerVisible && !_isAudioLoading) {
      _playbackSpeed = 1.0;
      try {
        if (_audioPlayer.audioSource != null) {
          await _audioPlayer.setSpeed(_playbackSpeed);
        }
      } catch (e) {
        debugPrint("Error resetting playback speed: $e");
      }
    }
  }

  void _onAudioCompleted() {
    if (_isLooping) {
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.play();
    } else {
      setState(() {
        _isPlaying = false;
      });
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.pause();
    }
  }

  void _toggleLoop() async {
    await HapticFeedbackManager.lightClick();
    setState(() {
      _isLooping = !_isLooping;
    });
  }

  void _setPlaybackSpeed(double speed) async {
    await HapticFeedbackManager.lightClick();
    setState(() {
      _playbackSpeed = speed;
    });
    try {
      if (_audioPlayer.audioSource != null) {
        await _audioPlayer.setSpeed(speed);
      }
    } catch (e) {
      debugPrint("Error setting playback speed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final horizontalPadding = screenWidth < 400 ? 12.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.keerthane.title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title, Favorite, Signature, and Language Row
                        _buildTitleAndLanguageRow(isSmallScreen, colorScheme),
                        const Divider(height: 24),
                        
                        // Controls Row - Dynamic
                        _buildControlsRow(context, isSmallScreen, colorScheme),
                        
                        const SizedBox(height: 20),
                        
                        // Lyrics Content
                        _buildLyricsContent(),
                        
                        // Extra padding for mini player
                        SizedBox(height: _isMiniPlayerVisible ? 100.0 : 24.0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isMiniPlayerVisible)
            _buildMiniAudioPlayer(context),
        ],
      ),
    );
  }

  Widget _buildTitleAndLanguageRow(bool isSmallScreen, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Left side: Keerthane number and favorite icon
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Keerthane ${widget.keerthane.number}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 18 : 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatefulBuilder(
                        builder: (context, setState) {
                          return FavoriteButton(
                            key: ValueKey(_isFavorite),
                            isFavorite: _isFavorite,
                            valueChanged: (isFavorite) {
                              _toggleFavorite();
                              setState(() {});
                            },
                            iconSize: isSmallScreen ? 32 : 38,
                          );
                        },
                      ),
                    ],
                  ),
                  if (widget.keerthane.signature.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.keerthane.signature,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Right side: Language selector
            _buildLanguageSelector(isSmallScreen, colorScheme),
          ],
        ),
      ],
    );
  }
  

  Widget _buildLanguageSelector(bool isSmallScreen, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ChoiceChip(
          label: Text(
            'English',
            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
          ),
          selected: selectedLanguage == 'English',
          onSelected: (bool selected) async {
            await HapticFeedbackManager.lightClick();
            if (selected) {
              setState(() {
                selectedLanguage = 'English';
              });
            }
          },
          visualDensity: isSmallScreen ? VisualDensity.compact : VisualDensity.standard,
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              'ಕನ್ನಡ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
          selected: selectedLanguage == 'Kannada',
          onSelected: (bool selected) async {
            await HapticFeedbackManager.lightClick();
            if (selected) {
              setState(() {
                selectedLanguage = 'Kannada';
              });
            }
          },
          visualDensity: isSmallScreen ? VisualDensity.compact : VisualDensity.standard,
        ),
      ],
    );
  }

  Widget _buildControlsRow(BuildContext context, bool isSmallScreen, ColorScheme colorScheme) {
    final buttonSize = isSmallScreen ? 32.0 : 38.0;
    final iconSize = isSmallScreen ? 16.0 : 20.0;
    
    return Row(
      children: [
        // Font controls
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: buttonSize,
              height: buttonSize,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.zero,
                ),
                onPressed: _decrementFontSize,
                child: Icon(Icons.remove, size: iconSize),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Font',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
            ),
            SizedBox(
              width: buttonSize,
              height: buttonSize,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.zero,
                ),
                onPressed: _incrementFontSize,
                child: Icon(Icons.add, size: iconSize),
              ),
            ),
          ],
        ),
        
        const Spacer(),
        
        // Add to category button
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: Size(isSmallScreen ? 70 : 92, isSmallScreen ? 32 : 36),
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12, vertical: isSmallScreen ? 6 : 10),
            shape: const StadiumBorder(),
            textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: isSmallScreen ? 12 : 14),
          ),
          onPressed: () async {
            await HapticFeedbackManager.lightClick();
            await _showAddToCategoryDialog();
          },
          icon: Icon(Icons.playlist_add, size: isSmallScreen ? 14 : 18),
          label: const Text('Add'),
        ),
        
        const SizedBox(width: 6),
        
        // Audio and Report buttons - Rightmost
        SizedBox(
          width: isSmallScreen ? 38 : 44,
          height: isSmallScreen ? 38 : 44,
          child: FloatingActionButton(
            heroTag: _audioButtonHeroTag,
            onPressed: _toggleMiniPlayerVisibility,
            tooltip: 'Open Audio Player',
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.primary,
            elevation: 2.5,
            child: _isAudioLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                      strokeWidth: 2.0,
                    ),
                  )
                : Icon(
                    _isMiniPlayerVisible ? Icons.volume_up_rounded : Icons.music_note_rounded,
                    size: isSmallScreen ? 18 : 22,
                  ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: isSmallScreen ? 38 : 44,
          height: isSmallScreen ? 38 : 44,
          child: FloatingActionButton(
            heroTag: _debugButtonHeroTag,
            onPressed: _showFeedbackDialog,
            tooltip: 'Report Lyrics Issue',
            backgroundColor: colorScheme.tertiaryContainer,
            foregroundColor: colorScheme.onTertiaryContainer,
            elevation: 2.5,
            child: Icon(Icons.bug_report_rounded, size: isSmallScreen ? 18 : 22),
          ),
        ),
      ],
    );
  }

  Widget _buildLyricsContent() {
    return SizedBox(
      width: double.infinity,
      child: Text(
        selectedLanguage == 'English'
            ? widget.keerthane.lyrics
            : (widget.keerthane.kannadaLyrics ?? 'Kannada Lyrics unavailable'),
        style: TextStyle(
          fontSize: _fontSize,
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _showAddToCategoryDialog() async {
    final service = SupabaseService();
    final categories = await service.fetchCustomCategoriesUnified();
    if (!mounted) return;
    if (categories.isEmpty) {
      final ctrl = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Create a category first'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Category name')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Create')),
          ],
        ),
      );
      if (name == null || name.isEmpty) return;
      final newId = await service.createCustomCategoryUnified(name);
      if (newId == null) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Limit reached'),
            content: const Text('Guests can create up to 5 categories locally. Sign in to create more.'),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        );
        return;
      }
      await service.addSongToCategoryUnified(categoryId: newId, songId: widget.keerthane.number, songType: 'keerthane');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to new category')));
      }
      return;
    }
    int? selectedId;
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSB) => AlertDialog(
          title: const Text('Add song to category'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('No categories yet. Create one below.'),
                  ),
                ...categories.map((c) => RadioListTile<int>(
                      value: (c['id'] as num).toInt(),
                      groupValue: selectedId,
                      title: Text(c['name'] as String),
                      onChanged: (v) => setSB(() => selectedId = v),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final nameCtrl = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('New category'),
                    content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Category name')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, nameCtrl.text.trim()), child: const Text('Create')),
                    ],
                  ),
                );
                if (name != null && name.isNotEmpty) {
                  final id = await service.createCustomCategoryUnified(name);
                  if (id != null) {
                    selectedId = id;
                    Navigator.pop(context, true);
                  }
                }
              },
              child: const Text('New category'),
            ),
            FilledButton(
              onPressed: selectedId == null
                  ? null
                  : () async {
                      await service.addSongToCategoryUnified(categoryId: selectedId!, songId: widget.keerthane.number, songType: 'keerthane');
                      if (mounted) Navigator.pop(context, true);
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (res == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to category')));
    }
  }

  Widget _buildMiniAudioPlayer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.keerthane.title,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 14 : 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant, size: isSmallScreen ? 20 : 24),
                  onPressed: _toggleMiniPlayerVisibility,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            StreamBuilder<Duration>(
              stream: _audioPlayer.positionStream,
              builder: (context, snapshot) {
                Duration? position = snapshot.data;
                Duration? duration = _audioPlayer.duration;
                double sliderValue = position?.inMilliseconds.toDouble() ?? 0.0;
                double sliderMax = duration?.inMilliseconds.toDouble() ?? 100.0;
                sliderValue = sliderValue.clamp(0.0, sliderMax);

                return Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: isSmallScreen ? 5 : 6),
                        overlayShape: RoundSliderOverlayShape(overlayRadius: isSmallScreen ? 10 : 12),
                        activeTrackColor: colorScheme.primary,
                        inactiveTrackColor: colorScheme.surfaceContainerHigh,
                        thumbColor: colorScheme.primary,
                        overlayColor: colorScheme.primary.withOpacity(0.2),
                        trackHeight: isSmallScreen ? 3 : 4,
                      ),
                      child: Slider(
                        value: sliderValue,
                        max: sliderMax,
                        min: 0.0,
                        onChanged: (value) {
                          final newPosition = Duration(milliseconds: value.toInt());
                          _audioPlayer.seek(newPosition);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position ?? Duration.zero),
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: isSmallScreen ? 10 : 12),
                          ),
                          Text(
                            _formatDuration(duration ?? Duration.zero),
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: isSmallScreen ? 10 : 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.replay_5_rounded, color: colorScheme.onSurfaceVariant, size: isSmallScreen ? 22 : 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Duration newPosition = _audioPlayer.position - _skipDuration;
                    if (newPosition < Duration.zero) {
                      newPosition = Duration.zero;
                    }
                    _audioPlayer.seek(newPosition);
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: colorScheme.primary,
                    size: isSmallScreen ? 36 : 42,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _toggleAudioPlayback,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.forward_5_rounded, color: colorScheme.onSurfaceVariant, size: isSmallScreen ? 22 : 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    final currentPosition = _audioPlayer.position;
                    final newPosition = currentPosition + _skipDuration;
                    if (newPosition > (_audioPlayer.duration ?? Duration.zero)) {
                      _audioPlayer.stop();
                    } else {
                      _audioPlayer.seek(newPosition);
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: FaIcon(
                    FontAwesomeIcons.repeat,
                    color: _isLooping ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    size: isSmallScreen ? 16 : 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: _isLooping ? 'Loop On' : 'Loop Off',
                  onPressed: _toggleLoop,
                ),
                const SizedBox(width: 4),
                PopupMenuButton<double>(
                  icon: Icon(Icons.speed_rounded, color: colorScheme.onSurfaceVariant, size: isSmallScreen ? 22 : 28),
                  padding: EdgeInsets.zero,
                  onSelected: _setPlaybackSpeed,
                  color: colorScheme.surfaceContainer,
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<double>>[
                    const PopupMenuItem<double>(value: 0.5, child: Text('0.5x')),
                    const PopupMenuItem<double>(value: 0.75, child: Text('0.75x')),
                    const PopupMenuItem<double>(value: 1.0, child: Text('Normal')),
                    const PopupMenuItem<double>(value: 1.25, child: Text('1.25x')),
                    const PopupMenuItem<double>(value: 1.5, child: Text('1.5x')),
                    const PopupMenuItem<double>(value: 2.0, child: Text('2.0x')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

enum _TicketStatus { loading, success, failure }

class _TicketCreationDialog extends StatelessWidget {
  final _TicketStatus status;
  final String? ticketKey;
  final String? ticketUrl;
  final String? errorMessage;
  final VoidCallback? onClose;
  final VoidCallback? onViewTicket;

  const _TicketCreationDialog({
    required this.status,
    this.ticketKey,
    this.ticketUrl,
    this.errorMessage,
    this.onClose,
    this.onViewTicket,
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
      case _TicketStatus.loading:
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
              'Creating ticket...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        );

      case _TicketStatus.success:
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
              'Ticket Created!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            if (ticketKey != null) ...[
              const SizedBox(height: 8),
              Text(
                ticketKey!,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );

      case _TicketStatus.failure:
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
              'Ticket Not Created',
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
    if (status == _TicketStatus.loading) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (status == _TicketStatus.failure)
          Expanded(
            child: FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.surfaceVariant,
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              child: const Text('Close'),
            ),
          )
        else ...[
          Expanded(
            child: OutlinedButton(
              onPressed: onClose,
              child: const Text('Close'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: onViewTicket,
              child: const Text(
                'Show Ticket Status',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
