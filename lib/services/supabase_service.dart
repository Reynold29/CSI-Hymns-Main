import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SupabaseService {
  SupabaseService._internal();
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;

  SupabaseClient get client => Supabase.instance.client;

  Future<void> init({required String url, required String anonKey}) async {
    await Supabase.initialize(url: url, anonKey: anonKey, debug: kDebugMode);
  }

  // Auth
  Stream<AuthState> get authStream => client.auth.onAuthStateChange;
  Session? get currentSession => client.auth.currentSession;
  User? get currentUser => client.auth.currentUser;

  Future<AuthResponse> signUpWithEmail(String email, String password) {
    return client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signInWithEmail(String email, String password) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    // Clear local favorites on logout so next user starts clean
    // Also clear owner marker
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('favoriteHymnIds');
      await prefs.remove('favoriteKeerthaneIds');
      await prefs.remove('favorites_owner_auth_uid');
    } catch (_) {}
    await client.auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email, {String? redirectTo}) async {
    final target = redirectTo ?? 'io.supabase.flutter://callback';
    await client.auth.resetPasswordForEmail(email, redirectTo: target);
  }

  Future<void> signInWithGoogle({String? redirectTo}) async {
    final redirect = redirectTo ?? 'io.supabase.flutter://callback';
    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirect,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  // Favorites table helpers
  // Table schema expected: favorites(id, user_id uuid, item_number int, item_type text ['hymn'|'keerthane'], created_at)
  Future<List<Map<String, dynamic>>> fetchFavorites() async {
    final user = currentUser;
    if (user == null) return [];
    final response = await client
        .from('favorites')
        .select('item_number,item_type')
        .eq('user_id', user.id);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addFavorite({required int itemNumber, required String itemType}) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await client.from('favorites').insert({
        'user_id': user.id,
        'item_number': itemNumber,
        'item_type': itemType,
      });
    } catch (_) {
      // ignore duplicates or transient errors silently for UX
    }
  }

  Future<void> removeFavorite({required int itemNumber, required String itemType}) async {
    final user = currentUser;
    if (user == null) return;
    await client
        .from('favorites')
        .delete()
        .eq('user_id', user.id)
        .eq('item_number', itemNumber)
        .eq('item_type', itemType);
  }

  // ---------- Custom Categories ----------
  static const String _localCatsKey = 'local_custom_categories';
  static const String _localCatSongsKey = 'local_custom_category_songs';
  static const int localCategoryLimit = 5;
  bool _migratedThisSession = false;

  // Local helpers
  Future<List<Map<String, dynamic>>> _readLocalCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localCatsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    return list;
  }

  Future<void> _writeLocalCategories(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localCatsKey, jsonEncode(rows));
  }

  Future<List<Map<String, dynamic>>> _readLocalSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localCatSongsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    return list;
  }

  Future<void> _writeLocalSongs(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localCatSongsKey, jsonEncode(rows));
  }

  Future<void> _migrateLocalIfNeeded() async {
    if (_migratedThisSession) return;
    final user = currentUser;
    if (user == null) return;
    final localCats = await _readLocalCategories();
    final localSongs = await _readLocalSongs();
    if (localCats.isEmpty && localSongs.isEmpty) {
      _migratedThisSession = true;
      return;
    }
    // Create categories remotely and map old local id -> new remote id
    final Map<int, int> idMap = {};
    for (final c in localCats.where((c) => (c['deleted'] ?? 0) == 0)) {
      final inserted = await client
          .from('custom_categories')
          .insert({'user_id': user.id, 'name': c['name']})
          .select('id')
          .single();
      idMap[(c['id'] as num).toInt()] = (inserted['id'] as num).toInt();
    }
    for (final s in localSongs.where((s) => (s['deleted'] ?? 0) == 0)) {
      final localCatId = (s['category_id'] as num).toInt();
      final remoteCatId = idMap[localCatId];
      if (remoteCatId != null) {
        try {
          await client.from('custom_category_songs').insert({
            'category_id': remoteCatId,
            'user_id': user.id,
            'song_id': (s['song_id'] as num).toInt(),
            'song_type': s['song_type'],
          });
        } catch (_) {}
      }
    }
    // Clear local after success
    await _writeLocalCategories([]);
    await _writeLocalSongs([]);
    _migratedThisSession = true;
  }

  // Unified API (works offline for guests, migrates on login)
  Future<List<Map<String, dynamic>>> fetchCustomCategoriesUnified() async {
    final user = currentUser;
    if (user == null) {
      final rows = await _readLocalCategories();
      return rows.where((e) => (e['deleted'] ?? 0) == 0).toList();
    }
    await _migrateLocalIfNeeded();
    return await fetchCustomCategories();
  }

  Future<int?> createCustomCategoryUnified(String name) async {
    final user = currentUser;
    if (user == null) {
      final current = await _readLocalCategories();
      final activeCount = current.where((e) => (e['deleted'] ?? 0) == 0).length;
      if (activeCount >= localCategoryLimit) return null; // limit reached
      // generate negative id
      int nextId = -1;
      if (current.isNotEmpty) {
        final mins = current.map((e) => (e['id'] as num).toInt()).reduce((a, b) => a < b ? a : b);
        nextId = mins - 1;
      }
      final row = {
        'id': nextId,
        'name': name,
        'deleted': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      current.add(row);
      await _writeLocalCategories(current);
      return nextId;
    }
    await _migrateLocalIfNeeded();
    return await createCustomCategory(name);
  }

  Future<void> renameCustomCategoryUnified(int categoryId, String newName) async {
    final user = currentUser;
    if (user == null || categoryId < 0) {
      final rows = await _readLocalCategories();
      for (final r in rows) {
        if ((r['id'] as num).toInt() == categoryId) {
          r['name'] = newName;
          r['updated_at'] = DateTime.now().toIso8601String();
          break;
        }
      }
      await _writeLocalCategories(rows);
      return;
    }
    await renameCustomCategory(categoryId, newName);
  }

  Future<void> softDeleteCustomCategoryUnified(int categoryId) async {
    final user = currentUser;
    if (user == null || categoryId < 0) {
      final rows = await _readLocalCategories();
      for (final r in rows) {
        if ((r['id'] as num).toInt() == categoryId) {
          r['deleted'] = 1;
          r['updated_at'] = DateTime.now().toIso8601String();
          break;
        }
      }
      await _writeLocalCategories(rows);
      return;
    }
    await softDeleteCustomCategory(categoryId);
  }

  Future<List<Map<String, dynamic>>> fetchSongsInCategoryUnified(int categoryId) async {
    final user = currentUser;
    if (user == null || categoryId < 0) {
      final rows = await _readLocalSongs();
      return rows.where((r) => (r['category_id'] as num).toInt() == categoryId && (r['deleted'] ?? 0) == 0).toList();
    }
    return await fetchSongsInCategory(categoryId);
  }

  Future<void> addSongToCategoryUnified({required int categoryId, required int songId, required String songType}) async {
    final user = currentUser;
    if (user == null || categoryId < 0) {
      final rows = await _readLocalSongs();
      rows.add({
        'category_id': categoryId,
        'song_id': songId,
        'song_type': songType,
        'deleted': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await _writeLocalSongs(rows);
      return;
    }
    await addSongToCategory(categoryId: categoryId, songId: songId, songType: songType);
  }

  Future<void> removeSongFromCategoryUnified({required int categoryId, required int songId, required String songType}) async {
    final user = currentUser;
    if (user == null || categoryId < 0) {
      final rows = await _readLocalSongs();
      for (final r in rows) {
        if ((r['category_id'] as num).toInt() == categoryId && (r['song_id'] as num).toInt() == songId && r['song_type'] == songType) {
          r['deleted'] = 1;
          r['updated_at'] = DateTime.now().toIso8601String();
        }
      }
      await _writeLocalSongs(rows);
      return;
    }
    await removeSongFromCategory(categoryId: categoryId, songId: songId, songType: songType);
  }
  Future<List<Map<String, dynamic>>> fetchCustomCategories() async {
    final user = currentUser;
    if (user == null) return [];
    final rows = await client
        .from('custom_categories')
        .select('id,name,created_at,updated_at')
        .eq('user_id', user.id)
        .eq('deleted', 0)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<int?> createCustomCategory(String name) async {
    final user = currentUser;
    if (user == null) return null;
    final rows = await client
        .from('custom_categories')
        .insert({
          'user_id': user.id,
          'name': name,
        })
        .select('id')
        .single();
    return (rows['id'] as num?)?.toInt();
  }

  Future<void> renameCustomCategory(int categoryId, String newName) async {
    final user = currentUser;
    if (user == null) return;
    await client
        .from('custom_categories')
        .update({'name': newName, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', categoryId)
        .eq('user_id', user.id);
  }

  Future<void> softDeleteCustomCategory(int categoryId) async {
    final user = currentUser;
    if (user == null) return;
    // Prefer soft delete; fallback to hard delete if RLS blocks UPDATE
    try {
      await client
          .from('custom_categories')
          .update({'deleted': 1, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', categoryId)
          .eq('user_id', user.id);
    } on PostgrestException catch (_) {
      await client
          .from('custom_categories')
          .delete()
          .eq('id', categoryId)
          .eq('user_id', user.id);
    }
  }

  Future<List<Map<String, dynamic>>> fetchSongsInCategory(int categoryId) async {
    final user = currentUser;
    if (user == null) return [];
    final rows = await client
        .from('custom_category_songs')
        .select('id,song_id,song_type,created_at')
        .eq('user_id', user.id)
        .eq('category_id', categoryId)
        .eq('deleted', 0)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> addSongToCategory({required int categoryId, required int songId, required String songType}) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await client.from('custom_category_songs').insert({
        'category_id': categoryId,
        'user_id': user.id,
        'song_id': songId,
        'song_type': songType,
      });
    } catch (_) {}
  }

  Future<void> removeSongFromCategory({required int categoryId, required int songId, required String songType}) async {
    final user = currentUser;
    if (user == null) return;
    await client
        .from('custom_category_songs')
        .update({'deleted': 1, 'updated_at': DateTime.now().toIso8601String()})
        .eq('user_id', user.id)
        .eq('category_id', categoryId)
        .eq('song_id', songId)
        .eq('song_type', songType);
  }
}


