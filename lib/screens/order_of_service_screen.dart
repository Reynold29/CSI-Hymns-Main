import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';

class OrderOfServiceScreen extends StatefulWidget {
  const OrderOfServiceScreen({super.key});

  @override
  State<OrderOfServiceScreen> createState() => _OrderOfServiceScreenState();
}

class _OrderOfServiceScreenState extends State<OrderOfServiceScreen> {
  bool _showEnglishPrimary = true;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() => _showEnglishPrimary = !_showEnglishPrimary);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ಆರಾಧನಾ ಕ್ರಮ / Aaradhana Krama'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTwoCols = constraints.maxWidth >= 600;
            final crossAxisCount = isTwoCols ? 2 : 1;
            return Column(
              children: [
                Expanded(
                  child: GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: isTwoCols ? 0.9 : 1.6,
                    children: [
                      _OrderCard(
                        leadingIcon: Icons.north_east_rounded,
                        englishTitle: 'Regular Sunday – Order of Service',
                        kannadaTitle: 'ಭಾನುವಾರದ ದೇವರಾರಾಧನೆ',
                        showEnglish: _showEnglishPrimary,
                        gradient: [const Color(0xFFFFC66A), const Color(0xFFFFD48C)],
                        onTap: () async {
                          await HapticFeedbackManager.lightClick();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const _OrderOfServiceReaderRoute(
                                key: ValueKey('regular-sunday-reader'),
                                englishHeader: 'Regular Sunday Order of Service',
                                kannadaHeader: 'ಭಾನುವಾರದ ದೇವರಾರಾಧನೆ',
                              ),
                            ),
                          );
                        },
                      ),
                       _OrderCard(
                        leadingIcon: Icons.south_west_rounded,
                        englishTitle: 'Festival – Order of Service',
                        kannadaTitle: 'ಹಬ್ಬದ ಆರಾಧನೆ',
                        showEnglish: _showEnglishPrimary,
                        gradient: [const Color(0xFFBCEBFF), const Color(0xFFD7F4FF)],
                        onTap: () async {
                          await HapticFeedbackManager.lightClick();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Festival service – coming soon')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                 const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final IconData leadingIcon;
  final String englishTitle;
  final String kannadaTitle;
  final bool showEnglish;
  final VoidCallback onTap;
  final List<Color>? gradient;

  const _OrderCard({
    required this.leadingIcon,
    required this.englishTitle,
    required this.kannadaTitle,
    required this.showEnglish,
    required this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double targetHeight = (constraints.maxWidth * 0.42).clamp(160.0, 240.0);
        return SizedBox(
          height: targetHeight,
          child: InkWell(
            onTap: () async { await HapticFeedbackManager.lightClick(); onTap(); },
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient ?? [scheme.secondaryContainer, scheme.secondaryContainer.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.7)),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                      child: Text(
                        showEnglish ? englishTitle : kannadaTitle,
                        key: ValueKey(showEnglish),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.north_east_rounded, color: scheme.onSurface, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Inline lightweight route wrapper to avoid imports in this file
class _OrderOfServiceReaderRoute extends StatelessWidget {
  final String englishHeader;
  final String kannadaHeader;

  const _OrderOfServiceReaderRoute({
    super.key,
    required this.englishHeader,
    required this.kannadaHeader,
  });

  @override
  Widget build(BuildContext context) {
    return OrderOfServiceReader(
      englishHeader: englishHeader,
      kannadaHeader: kannadaHeader,
    );
  }
}

class OrderOfServiceReader extends StatefulWidget {
  final String englishHeader;
  final String kannadaHeader;

  const OrderOfServiceReader({
    super.key,
    required this.englishHeader,
    required this.kannadaHeader,
  });

  @override
  State<OrderOfServiceReader> createState() => _OrderOfServiceReaderState();
}

class _OrderOfServiceReaderState extends State<OrderOfServiceReader> {
  late PageController _pageController;
  int _controllerEpoch = 0; // forces PageView to rebuild when controller is swapped
  final TextEditingController _jumpController = TextEditingController();
  int _currentPageIndex = 0;
  List<_OrderPage> _pages = const [];
  bool _loading = true;
  String? _error;
  static const int _chipWindowRadius = 6; // ~13 chips around current page
  bool _hasSelectedPage = false;
  Map<int, int> _pageNoToIndex = const {};
  // Expressive button styles
  ButtonStyle _primaryExpressive(BuildContext context) {
    return FilledButton.styleFrom(
      minimumSize: const Size(0, 56),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: const StadiumBorder(),
      textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }

  ButtonStyle _tonalExpressive(BuildContext context) {
    return FilledButton.styleFrom(
      minimumSize: const Size(0, 56),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: const StadiumBorder(),
      textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Resolve the actual asset key from AssetManifest to avoid path mismatches
      final assetKey = await _resolveOrderOfServiceAssetKey();
      final data = await rootBundle.loadString(assetKey);
      final parsed = jsonDecode(data);
      final pages = <_OrderPage>[];
      if (parsed is List) {
        for (final item in parsed) {
          pages.add(_OrderPage.fromJson(item as Map<String, dynamic>));
        }
        pages.sort((a, b) => a.pageNo.compareTo(b.pageNo));
      } else if (parsed is Map<String, dynamic>) {
        // Backwards compatibility: {"183": "content"}
        parsed.forEach((k, v) {
          final no = int.tryParse(k) ?? 0;
          pages.add(_OrderPage(pageNo: no, title: null, content: (v ?? '').toString()));
        });
        pages.sort((a, b) => a.pageNo.compareTo(b.pageNo));
      }
      setState(() {
        _pages = pages;
        // Build quick lookup for exact page number → index
        final map = <int, int>{};
        for (int i = 0; i < pages.length; i++) {
          map[pages[i].pageNo] = i;
        }
        _pageNoToIndex = map;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<String> _resolveOrderOfServiceAssetKey() async {
    const primary = 'lib/assets/order-of-service_data.json';
    const legacy = 'lib/assets/order-of-serice_data.json';
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
      if (manifest.containsKey(primary)) return primary;
      if (manifest.containsKey(legacy)) return legacy;
      // Try to find by suffix just in case
      final match = manifest.keys.firstWhere(
        (k) => k.endsWith('order-of-service_data.json') || k.endsWith('order-of-serice_data.json'),
        orElse: () => '',
      );
      if (match.isNotEmpty) return match;
    } catch (_) {
      // ignore and fallback
    }
    // Fallback to primary; this will throw a clear FlutterError if missing
    return primary;
  }

  int? _indexForPageNo(int pageNo) {
    // Strict exact match only
    return _pageNoToIndex[pageNo];
  }

  void _jumpTo(int pageNo) {
    if (_pages.isEmpty) return;
    final target = pageNo;
    final idx = _indexForPageNo(target);
    if (idx != null && idx >= 0 && idx < _pages.length) {
      // Always replace the controller with an initialPage-aligned one to avoid any
      // attachment timing or off-by-one glitches
      setState(() {
        _pageController.dispose();
        _pageController = PageController(initialPage: idx);
        _controllerEpoch++; // force PageView rebuild with new controller
        _hasSelectedPage = true;
        _currentPageIndex = idx;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Page $target not found')),
      );
    }
    FocusScope.of(context).unfocus();
  }

  List<int> _visiblePageNumbers() {
    if (_pages.isEmpty) return const [];
    final int currentPageNo = _pages[_currentPageIndex].pageNo;
    final int start = (currentPageNo - _chipWindowRadius).clamp(_pages.first.pageNo, _pages.last.pageNo);
    final int end = (currentPageNo + _chipWindowRadius).clamp(_pages.first.pageNo, _pages.last.pageNo);
    return [for (int i = start; i <= end; i++) i];
  }

  Future<void> _openAllPagesSheet() async {
    if (_pages.isEmpty) return;
    final theme = Theme.of(context);
    final pageNos = [for (final p in _pages) p.pageNo];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('All Pages', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final no in pageNos)
                        _PageChip(
                          label: no.toString(),
                          selected: _pages[_currentPageIndex].pageNo == no,
                          onTap: () async {
                            await HapticFeedbackManager.lightClick();
                            Navigator.of(context).pop();
                            _jumpTo(no);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final double bottomReservePadding = (_hasSelectedPage ? 96.0 : 72.0) + MediaQuery.of(context).padding.bottom;
    return WillPopScope(
      onWillPop: () async {
        if (_hasSelectedPage) {
          setState(() => _hasSelectedPage = false);
          return false; // stay on this route, show search view
        }
        return true; // allow normal back
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.kannadaHeader} / ${widget.englishHeader}'),
        ),
        body: Stack(
        children: [
          Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Failed to load: $_error',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_pages.isEmpty)
                        ? const Center(child: Text('No pages found in data'))
                        : (!_hasSelectedPage)
                        ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Heading and helper text
                                    Text(
                                      'Huduvada Aaradhana Krama',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Enter a page number to jump directly to that page',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 520),
                                      child: TextField(
                                        controller: _jumpController,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.go,
                                        decoration: InputDecoration(
                                          hintText: 'Jump to page number (e.g., 1, 98, 100)',
                                          prefixIcon: const Icon(Icons.search),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                        ),
                                        onSubmitted: (value) async {
                                          final target = int.tryParse(value);
                                          if (target != null) {
                                            await HapticFeedbackManager.mediumClick();
                                            _jumpTo(target);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 320),
                                      child: _MorphingCTAButton(
                                        label: 'Open Full Book',
                                        icon: Icons.menu_book_rounded,
                                        onPressed: () async { await HapticFeedbackManager.lightClick(); setState(() => _hasSelectedPage = true); },
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : PageView.builder(
                                key: ValueKey(_controllerEpoch),
                                controller: _pageController,
                                scrollDirection: Axis.vertical,
                                onPageChanged: (i) => setState(() => _currentPageIndex = i),
                                itemCount: _pages.length,
                                itemBuilder: (context, index) {
                                  final page = _pages[index];
                                  final bool hasPrev = index > 0;
                                  final bool hasNext = index < _pages.length - 1;
                                  final int? prevNo = hasPrev ? _pages[index - 1].pageNo : null;
                                  final int? nextNo = hasNext ? _pages[index + 1].pageNo : null;
                                  const double topBadgeReserve = 40.0; // leave space under the fixed top-right page chip
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if ((page.title ?? '').trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 10.0),
                                            child: Text(
                                              page.title!,
                                              style: textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            padding: EdgeInsets.only(
                                              top: topBadgeReserve,
                                              bottom: bottomReservePadding,
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                SelectableText(
                                                  page.content,
                                                  style: textTheme.bodyLarge?.copyWith(height: 1.45),
                                                ),
                                                const SizedBox(height: 16),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: FilledButton.tonalIcon(
                                                        style: _tonalExpressive(context),
                                                         onPressed: hasPrev ? () async { await HapticFeedbackManager.lightClick(); _jumpTo(prevNo!); } : null,
                                                        icon: const Icon(Icons.arrow_back),
                                                        label: Text(hasPrev ? 'Previous Page - ${prevNo!}' : 'Previous Page'),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: FilledButton.icon(
                                                        style: _primaryExpressive(context),
                                                         onPressed: hasNext ? () async { await HapticFeedbackManager.lightClick(); _jumpTo(nextNo!); } : null,
                                                        icon: const Icon(Icons.arrow_forward),
                                                        label: Text(hasNext ? 'Next Page - ${nextNo!}' : 'Next Page'),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
          // Fixed top-right page badge (always above content and title)
          if (_pages.isNotEmpty && _hasSelectedPage)
            Positioned(
              right: 12,
              top: 12 + MediaQuery.of(context).padding.top,
              child: Chip(
                label: Text('Page ${_pages[_currentPageIndex].pageNo}'),
                visualDensity: VisualDensity.compact,
              ),
            ),

          // Bottom: landing mode -> chips; book mode -> nav bar with arrows
          if (_pages.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Material(
                  elevation: 8,
                  color: Theme.of(context).colorScheme.surface,
                  surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: !_hasSelectedPage
                        ? Row(
                            children: [
                               TextButton.icon(
                                 onPressed: () async { await HapticFeedbackManager.lightClick(); await _openAllPagesSheet(); },
                                icon: const Icon(Icons.grid_view_rounded, size: 18),
                                label: const Text('All pages'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final no in _visiblePageNumbers())
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: _PageChip(
                                            label: no.toString(),
                                            selected: false,
                                            onTap: () async { await HapticFeedbackManager.lightClick(); _jumpTo(no); },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              _NavIconButton(
                                icon: Icons.chevron_left,
                                onTap: _currentPageIndex > 0
                                    ? () => _pageController.previousPage(
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.easeOut,
                                        )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                               Expanded(
                                child: OutlinedButton(
                                   onPressed: () async { await HapticFeedbackManager.lightClick(); await _openAllPagesSheet(); },
                                  child: Text('Page ${_pages[_currentPageIndex].pageNo}'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _NavIconButton(
                                icon: Icons.chevron_right,
                                onTap: _currentPageIndex < _pages.length - 1
                                    ? () => _pageController.nextPage(
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.easeOut,
                                        )
                                    : null,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

          // Floating "Go to book" action for landing
          // Inline button shown in landing section; no floating action needed
        ],
      ),
    ),
    );
  }
}

class _OrderPage {
  final int pageNo;
  final String? title;
  final String content;

  _OrderPage({required this.pageNo, required this.title, required this.content});

  factory _OrderPage.fromJson(Map<String, dynamic> json) {
    return _OrderPage(
      pageNo: json['page_no'] is int ? json['page_no'] as int : int.tryParse('${json['page_no']}') ?? 0,
      title: json['title'] as String?,
      content: (json['content'] ?? '').toString(),
    );
  }
}

class _PageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PageChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      side: BorderSide(color: scheme.outlineVariant),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkResponse(
      onTap: enabled ? () async { await HapticFeedbackManager.lightClick(); onTap!(); } : null,
      radius: 24,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? Theme.of(context).colorScheme.surfaceVariant : Theme.of(context).disabledColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: enabled ? Theme.of(context).colorScheme.onSurface : Theme.of(context).disabledColor),
      ),
    );
  }
}

class _MorphingCTAButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _MorphingCTAButton({required this.label, required this.icon, required this.onPressed});

  @override
  State<_MorphingCTAButton> createState() => _MorphingCTAButtonState();
}

class _MorphingCTAButtonState extends State<_MorphingCTAButton> with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _styleIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _styleIndex = (_styleIndex + 1) % 3);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);

    final ButtonStyle style;
    switch (_styleIndex) {
      case 0:
        style = FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: const StadiumBorder(),
          textStyle: textStyle,
        );
        break;
      case 1:
        style = FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: textStyle,
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
        );
        break;
      default:
        style = OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: textStyle,
        );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: switch (_styleIndex) {
        0 => FilledButton.icon(
            key: const ValueKey('style0'),
            style: style,
            onPressed: widget.onPressed,
            icon: Icon(widget.icon),
            label: Text(widget.label),
          ),
        1 => FilledButton.tonalIcon(
            key: const ValueKey('style1'),
            style: style,
            onPressed: widget.onPressed,
            icon: Icon(widget.icon),
            label: Text(widget.label),
          ),
        _ => OutlinedButton.icon(
            key: const ValueKey('style2'),
            style: style,
            onPressed: widget.onPressed,
            icon: Icon(widget.icon, color: scheme.primary),
            label: Text(widget.label, style: TextStyle(color: scheme.primary)),
          ),
      },
    );
  }
}
