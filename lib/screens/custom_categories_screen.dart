import 'package:flutter/material.dart';
import 'package:hymns_latest/services/supabase_service.dart';
import 'package:hymns_latest/screens/select_songs_for_category.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';
import 'package:hymns_latest/screens/auth_screen.dart';

class CustomCategoriesScreen extends StatefulWidget {
  const CustomCategoriesScreen({super.key});

  @override
  State<CustomCategoriesScreen> createState() => _CustomCategoriesScreenState();
}

class _CustomCategoriesScreenState extends State<CustomCategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  String? _error;
  int _guestRemaining = SupabaseService.localCategoryLimit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await SupabaseService().fetchCustomCategoriesUnified();
      if (!mounted) return;
      setState(() {
        _categories = rows;
        _loading = false;
        if (SupabaseService().currentUser == null) {
          final active = rows.where((e) => (e['deleted'] ?? 0) == 0).length;
          _guestRemaining = (SupabaseService.localCategoryLimit - active)
              .clamp(0, SupabaseService.localCategoryLimit);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createCategory() async {
    await HapticFeedbackManager.lightClick();
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Custom Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final id = await SupabaseService().createCustomCategoryUnified(name);
    if (id == null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Limit reached'),
          content: const Text(
              'Create an account and log in to create unlimited custom categories. Guests can create up to 5 locally.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('OK'))
          ],
        ),
      );
      return;
    }
    await HapticFeedbackManager.success();
    await _load();
    // After creation, if guest has hit 0 remaining, nudge to sign in
    if (mounted &&
        SupabaseService().currentUser == null &&
        _guestRemaining == 0) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('All guest slots used'),
          content: const Text(
              'You\'ve created 5 local categories. Sign in to sync them and create unlimited categories.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Later')),
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()));
              },
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
    }
  }

  void _openCategory(Map<String, dynamic> cat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryDetailScreen(
            categoryId: (cat['id'] as num).toInt(),
            categoryName: cat['name'] as String),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCategory,
        icon: const Icon(Icons.add),
        label: const Text('New Category'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No custom categories yet'),
                          const SizedBox(height: 8),
                          FilledButton(
                              onPressed: () async {
                                await HapticFeedbackManager.lightClick();
                                await _createCategory();
                              },
                              child: const Text('Create one')),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Header: guest quota + persistent create row
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (SupabaseService().currentUser == null)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                  child: Row(
                                    children: [
                                      Chip(
                                          label: Text(
                                              'Guest slots left: $_guestRemaining/${SupabaseService.localCategoryLimit}')),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const AuthScreen())),
                                        icon: const Icon(Icons.login),
                                        label: const Text('Sign in'),
                                      )
                                    ],
                                  ),
                                ),
                              ListTile(
                                leading: const Icon(Icons.add),
                                title: const Text('Create new category'),
                                onTap: () async {
                                  await HapticFeedbackManager.lightClick();
                                  await _createCategory();
                                },
                              ),
                            ],
                          );
                        }
                        final cat = _categories[index - 1];
                        return ListTile(
                          leading: const Icon(Icons.folder_copy_outlined),
                          title: Text(cat['name'] as String),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'rename') {
                                final ctrl = TextEditingController(
                                    text: cat['name'] as String);
                                final newName = await showDialog<String>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Rename category'),
                                    content: TextField(controller: ctrl),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancel')),
                                      FilledButton(
                                          onPressed: () => Navigator.pop(
                                              context, ctrl.text.trim()),
                                          child: const Text('Save')),
                                    ],
                                  ),
                                );
                                if (newName != null && newName.isNotEmpty) {
                                  await SupabaseService()
                                      .renameCustomCategoryUnified(
                                          (cat['id'] as num).toInt(), newName);
                                  await _load();
                                }
                              } else if (value == 'delete') {
                                try {
                                  await SupabaseService()
                                      .softDeleteCustomCategoryUnified(
                                          (cat['id'] as num).toInt());
                                  if (!mounted) return;
                                  setState(() {
                                    _categories.removeAt(index - 1);
                                  });
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        duration:
                                            const Duration(milliseconds: 1500),
                                        content: Text('Failed to delete: $e')),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                  value: 'rename', child: Text('Rename')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                          onTap: () => _openCategory(cat),
                        );
                      },
                    ),
    );
  }
}

class CategoryDetailScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  const CategoryDetailScreen(
      {super.key, required this.categoryId, required this.categoryName});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  List<Map<String, dynamic>> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows =
        await SupabaseService().fetchSongsInCategoryUnified(widget.categoryId);
    if (!mounted) return;
    setState(() {
      _songs = rows;
      _loading = false;
    });
  }

  // (Manual single add removed; using bulk flow only)

  Future<void> _remove(int idx) async {
    final row = _songs[idx];
    await SupabaseService().removeSongFromCategoryUnified(
      categoryId: widget.categoryId,
      songId: (row['song_id'] as num).toInt(),
      songType: row['song_type'] as String,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SelectSongsForCategoryScreen(
                categoryId: widget.categoryId,
                categoryName: widget.categoryName,
              ),
            ),
          );
          if (ok == true) await _load();
        },
        icon: const Icon(Icons.library_add_check_outlined),
        label: const Text('Add Songs'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? const Center(child: Text('No songs yet'))
              : ListView.builder(
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final row = _songs[index];
                    final title = '${row['song_type']} #${row['song_id']}';
                    return ListTile(
                      title: Text(title),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(index),
                      ),
                    );
                  },
                ),
    );
  }
}
