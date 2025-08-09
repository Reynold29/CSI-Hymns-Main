import 'dart:async';
import 'audio_error_handling.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hymns_latest/keerthanes_def.dart';
import 'package:audio_session/audio_session.dart';
import 'package:favorite_button/favorite_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';
import 'package:hymns_latest/services/supabase_service.dart';

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
  bool _isAudioLoading = false; // ADDED: Loading state for audio button

  final Duration _skipDuration = const Duration(seconds: 5);
  final _audioButtonHeroTag = const Symbol('audioButtonHeroTag');
  final _debugButtonHeroTag = const Symbol('debugButtonHeroTag');
  late StreamSubscription<PlayerState> _playerStateSubscription;

  void _incrementFontSize() async {
    await HapticFeedbackManager.lightClick();
    setState(() {
      _fontSize = (_fontSize + 2).clamp(16.0, 40.0);
    });
  }

  void _decrementFontSize() async {
    await HapticFeedbackManager.lightClick();
    setState(() {
      _fontSize = (_fontSize - 2).clamp(16.0, 40.0);
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
      print('Playback stream error occurred: $e');
      print('Stack trace: $stackTrace');
    });

    String keerthaneNumber = widget.keerthane.number.toString();
    String audioUrl = 'https://raw.githubusercontent.com/reynold29/midi-files/main/Keerthane/Keerthane_$keerthaneNumber.ogg';

    try {
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));
      setState(() {
        _isAudioLoading = false; // Set loading to false after successful load
        _isMiniPlayerVisible = true; // Open mini player after successful load
      });
    } catch (e) {
      print('Error loading audio source in _init: $e');
      setState(() {
        _isAudioLoading = false; // Set loading to false even on error
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AudioErrorDialog(
            itemNumber: widget.keerthane.number,
            itemType: 'Keerthane',
          ),
        );
      }
      throw e;
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

    // Sync remote if logged in
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Find something wrong in the lyrics? ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('Help me fix it by sending an E-Mail! \n\nSend E-Mail?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Yes'),
              onPressed: () async {
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: 'reyziecrafts@gmail.com',
                  query: 'subject=Keerthane%20Lyrics%20Issue%20-%20Keerthane%20${widget.keerthane.number}&body=Requesting%20lyrics%20check!',
                );
                if (await canLaunchUrl(emailLaunchUri)) {
                  await launchUrl(emailLaunchUri);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Unable to open email app. Do you have Gmail installed?')));
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveToFavorites(Keerthane keerthane) async {
    final prefs = await SharedPreferences.getInstance();
    // If logged in, local list mirrors remote; keep UX snappy then sync
    final storedIds = prefs.getStringList('favoriteKeerthaneIds') ?? [];

    if (!storedIds.contains(keerthane.number.toString())) {
      storedIds.add(keerthane.number.toString());
      await prefs.setStringList('favoriteKeerthaneIds', storedIds);
    }
  }

  Future<void> _removeFromFavorites(Keerthane keerthane) async {
    final prefs = await SharedPreferences.getInstance();
    // If logged in, local list mirrors remote; keep UX snappy then sync
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
      _isAudioLoading = true; // Start loading, show indicator
    });

    if (!_isMiniPlayerVisible) {
      if (_audioPlayer.audioSource == null) {
        try {
          await _init();
        } catch (e) {
          // Error dialog is already shown in _init, _isAudioLoading is set to false there.
          return;
        }
      } else {
        setState(() {
          _isAudioLoading = false; // If audio source is already loaded, just show mini player
          _isMiniPlayerVisible = true;
        });
      }
    } else {
      await _audioPlayer.pause();
      setState(() {
        _isMiniPlayerVisible = false;
        _isAudioLoading = false; // Stop loading if closing mini player
      });
    }

    if (_isMiniPlayerVisible && !_isAudioLoading) { // Only reset speed if mini player is becoming visible and not loading
      _playbackSpeed = 1.0;
      try {
        if (_audioPlayer.audioSource != null) {
          await _audioPlayer.setSpeed(_playbackSpeed);
        }
      } catch (e) {
        print("Error resetting playback speed: $e");
      }
    }
  }


  void _onAudioCompleted() {
    print("Audio playback completed!");

    if (_isLooping) {
      print("Loop mode is ON - restarting audio.");
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.play();
    } else {
      print("Loop mode is OFF - pausing audio.");
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
    print("Loop mode toggled: _isLooping = $_isLooping");
  }

  void _setPlaybackSpeed(double speed) async {
    await HapticFeedbackManager.lightClick();
    print("setPlaybackSpeed called with speed: $speed (Simplified Navigation)");
    setState(() {
      _playbackSpeed = speed;
    });
    try {
      print("Before _audioPlayer.setSpeed(speed), audioSource: ${_audioPlayer.audioSource}");
      if (_audioPlayer.audioSource != null) {
        await _audioPlayer.setSpeed(speed);
      } else {
        print("Audio source is still null when trying to change speed (inside IF).");
      }
    } catch (e) {
      print("Error setting playback speed: $e");
    } finally {
      print("setPlaybackSpeed finally block - Navigation MINIMAL - NO Navigator.pop()");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.keerthane.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Keerthane ${widget.keerthane.number}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 15),
                      StatefulBuilder(
                        builder: (context, setState) {
                          return FavoriteButton(
                            key: ValueKey(_isFavorite),
                            isFavorite: _isFavorite,
                            valueChanged: (isFavorite) {
                              _toggleFavorite();
                              setState(() {});
                            },
                            iconSize: 38,
                          );
                        },
                      ),
                      const Spacer(),
                      ChoiceChip(
                        label: const Text('English'),
                        selected: selectedLanguage == 'English',
                        onSelected: (bool selected) async {
                          await HapticFeedbackManager.lightClick();
                          if (selected) {
                            setState(() {
                              selectedLanguage = 'English';
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            'ಕನ್ನಡ',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
                      ),
                    ],
                  ),
                  if (widget.keerthane.signature.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.keerthane.signature,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: const Size(34, 34),
                        ).copyWith(
                          overlayColor: MaterialStateProperty.resolveWith<Color?>(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.pressed))
                                return Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.12);
                              if (states.contains(MaterialState.hovered))
                                return Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.04);
                              return null;
                            },
                          ),
                        ),
                        onPressed: _decrementFontSize,
                        child: const Icon(Icons.remove, size: 20),
                      ),
                      const SizedBox(width: 3),
                      const Text('Font', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 3),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: const Size(34, 34),
                        ).copyWith(
                          overlayColor: MaterialStateProperty.resolveWith<Color?>(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.pressed))
                                return Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.12);
                              if (states.contains(MaterialState.hovered))
                                return Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.04);
                              return null;
                            },
                          ),
                        ),
                        onPressed: _incrementFontSize,
                        child: const Icon(Icons.add, size: 20),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(92, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: _showAddToCategoryDialog,
                        icon: const Icon(Icons.playlist_add, size: 18),
                        label: const Text('Add'),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 44.0,
                            height: 44.0,
                            child: FloatingActionButton(
                              heroTag: _audioButtonHeroTag,
                              onPressed: _toggleMiniPlayerVisibility,
                              tooltip: 'Open Audio Player',
                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              elevation: 2.5,
                              hoverColor: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.08),
                              splashColor: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.16),
                              child: _isAudioLoading
                                ? SizedBox(
                                    width: 16.0,
                                    height: 16.0,
                                    child: CircularProgressIndicator(
                                      color: Theme.of(context).colorScheme.primary,
                                      strokeWidth: 2.0,
                                    ),
                                  )
                                : Icon(_isMiniPlayerVisible ? Icons.volume_up_rounded : Icons.music_note_rounded, size: 22),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          SizedBox(
                            width: 44.0,
                            height: 44.0,
                            child: FloatingActionButton(
                              heroTag: _debugButtonHeroTag,
                              onPressed: _showFeedbackDialog,
                              tooltip: 'Report Lyrics Issue',
                              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                              elevation: 2.5,
                              hoverColor: Theme.of(context).colorScheme.onTertiaryContainer.withOpacity(0.08),
                              splashColor: Theme.of(context).colorScheme.onTertiaryContainer.withOpacity(0.16),
                              child: const Icon(Icons.bug_report_rounded, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: SingleChildScrollView(
                      child: Text(
                        selectedLanguage == 'English'
                            ? widget.keerthane.lyrics
                            : (widget.keerthane.kannadaLyrics ?? 'Kannada Lyrics unavailable'),
                        style: TextStyle(fontSize: _fontSize),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  SizedBox(height: _isMiniPlayerVisible ? 80.0 : 0),
                ],
              ),
            ),
          ),
          if (_isMiniPlayerVisible)
            _buildMiniAudioPlayer(context),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.keerthane.title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _toggleMiniPlayerVisibility,
              ),
            ],
          ),
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
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor: colorScheme.surfaceVariant,
                      thumbColor: colorScheme.primary,
                      overlayColor: colorScheme.primary.withOpacity(0.2),
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
                        Text(_formatDuration(position ?? Duration.zero), style: TextStyle(color: colorScheme.onSurfaceVariant)),
                        Text(_formatDuration(duration ?? Duration.zero), style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
                icon: Icon(Icons.replay_5_rounded, color: colorScheme.onSurfaceVariant, size: 28),
                onPressed: () {
                  Duration newPosition = _audioPlayer.position - _skipDuration;
                  if (newPosition < Duration.zero) {
                    newPosition = Duration.zero;
                  }
                  _audioPlayer.seek(newPosition);
                },
              ),
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: colorScheme.primary, size: 42),
                onPressed: _toggleAudioPlayback,
              ),
              IconButton(
                icon: Icon(Icons.forward_5_rounded, color: colorScheme.onSurfaceVariant, size: 28),
                onPressed: () async {
                  final currentPosition = _audioPlayer.position;
                  final newPosition = currentPosition + _skipDuration;
                  if (newPosition > (_audioPlayer.duration)!) {
                    _audioPlayer.stop();
                  } else {
                    _audioPlayer.seek(newPosition);
                  }
                },
              ),
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setStateSB) {
                  bool isPressed = false;

                  return IconButton(
                    icon: AnimatedScale(
                      scale: isPressed ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: FaIcon(
                        FontAwesomeIcons.repeat,
                        color: _isLooping
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                    tooltip: _isLooping ? 'Loop On' : 'Loop Off',
                    onPressed: () {
                      _toggleLoop();
                      setStateSB(() => isPressed = true);
                      Future.delayed(const Duration(milliseconds: 150), () => setStateSB(() => isPressed = false));
                    },
                  );
                },
              ),
              PopupMenuButton<double>(
                icon: Icon(Icons.speed_rounded, color: colorScheme.onSurfaceVariant, size: 28),
                onSelected: _setPlaybackSpeed,
                color: colorScheme.surfaceContainer,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<double>>[
                  const PopupMenuItem<double>(
                    value: 0.5,
                    child: Text('0.5x'),
                  ),
                  const PopupMenuItem<double>(
                    value: 0.75,
                    child: Text('0.75x'),
                  ),
                  const PopupMenuItem<double>(
                    value: 1.0,
                    child: Text('Normal'),
                  ),
                  const PopupMenuItem<double>(
                    value: 1.25,
                    child: Text('1.25x'),
                  ),
                  const PopupMenuItem<double>(
                    value: 1.5,
                    child: Text('1.5x'),
                  ),
                  const PopupMenuItem<double>(
                    value: 2.0,
                    child: Text('2.0x'),
                  ),
                ],
              ),
            ],
          ),
        ],
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