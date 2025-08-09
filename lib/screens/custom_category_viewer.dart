import 'package:flutter/material.dart';
import 'package:hymns_latest/categories/dynamic_category_screen.dart';
import 'package:hymns_latest/services/supabase_service.dart';

class CustomCategoryViewerScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  const CustomCategoryViewerScreen({super.key, required this.categoryId, required this.categoryName});

  @override
  State<CustomCategoryViewerScreen> createState() => _CustomCategoryViewerScreenState();
}

class _CustomCategoryViewerScreenState extends State<CustomCategoryViewerScreen> {
  List<int> _hymnNumbers = const [];
  List<int> _keerthaneNumbers = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await SupabaseService().fetchSongsInCategoryUnified(widget.categoryId);
      final hymns = <int>[];
      final keers = <int>[];
      for (final r in rows) {
        final id = (r['song_id'] as num).toInt();
        final t = (r['song_type'] as String).toLowerCase();
        if (t == 'hymn') hymns.add(id); else if (t == 'keerthane') keers.add(id);
      }
      if (!mounted) return;
      setState(() {
        _hymnNumbers = hymns;
        _keerthaneNumbers = keers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: Text(widget.categoryName)), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(appBar: AppBar(title: Text(widget.categoryName)), body: Center(child: Text('Error: $_error')));
    }
    return DynamicCategoryScreen(
      category: widget.categoryName,
      hymnNumbers: _hymnNumbers.isEmpty ? null : _hymnNumbers,
      keerthaneNumbers: _keerthaneNumbers.isEmpty ? null : _keerthaneNumbers,
    );
  }
}


