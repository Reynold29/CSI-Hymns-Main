import 'package:flutter/material.dart';
import 'package:hymns_latest/hymns_def.dart';
import 'package:hymns_latest/keerthanes_def.dart';
import 'package:hymns_latest/services/supabase_service.dart';

class SelectSongsForCategoryScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  const SelectSongsForCategoryScreen({super.key, required this.categoryId, required this.categoryName});

  @override
  State<SelectSongsForCategoryScreen> createState() => _SelectSongsForCategoryScreenState();
}

class _SelectSongsForCategoryScreenState extends State<SelectSongsForCategoryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<Hymn> _hymns = [];
  List<Keerthane> _keerthanes = [];
  final Set<int> _selectedHymns = {};
  final Set<int> _selectedKeerthanes = {};
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final hymns = await loadHymns();
    final ks = await loadKeerthane();
    if (!mounted) return;
    setState(() {
      _hymns = hymns;
      _keerthanes = ks;
      _loading = false;
    });
  }

  Future<void> _addSelected() async {
    if (_selectedHymns.isEmpty && _selectedKeerthanes.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    final service = SupabaseService();
    for (final n in _selectedHymns) {
      await service.addSongToCategoryUnified(categoryId: widget.categoryId, songId: n, songType: 'hymn');
    }
    for (final n in _selectedKeerthanes) {
      await service.addSongToCategoryUnified(categoryId: widget.categoryId, songId: n, songType: 'keerthane');
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add to ${widget.categoryName}')
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _addSelected,
            child: Text('Add ${_selectedHymns.length + _selectedKeerthanes.length} selected'),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by number or title',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  tabs: const [Tab(text: 'Hymns'), Tab(text: 'Keerthanes')],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildHymns(),
                      _buildKeerthanes(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHymns() {
    final filtered = _hymns.where((h) {
      if (_query.isEmpty) return true;
      final q = _query;
      return h.number.toString().contains(q) || h.title.toLowerCase().contains(q);
    }).toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final h = filtered[i];
        final sel = _selectedHymns.contains(h.number);
        return CheckboxListTile(
          value: sel,
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _selectedHymns.add(h.number);
              } else {
                _selectedHymns.remove(h.number);
              }
            });
          },
          title: Text('${h.number} · ${h.title}'),
        );
      },
    );
  }

  Widget _buildKeerthanes() {
    final filtered = _keerthanes.where((k) {
      if (_query.isEmpty) return true;
      final q = _query;
      return k.number.toString().contains(q) || k.title.toLowerCase().contains(q);
    }).toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final k = filtered[i];
        final sel = _selectedKeerthanes.contains(k.number);
        return CheckboxListTile(
          value: sel,
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _selectedKeerthanes.add(k.number);
              } else {
                _selectedKeerthanes.remove(k.number);
              }
            });
          },
          title: Text('${k.number} · ${k.title}'),
        );
      },
    );
  }
}


