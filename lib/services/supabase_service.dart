import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hymns_latest/services/categories_db.dart';
import 'dart:convert';

class SupabaseService {
  SupabaseService._internal();
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;

  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('SupabaseService: Client not available: $e');
      return null;
    }
  }
  
  /// Helper to get client or throw if not initialized
  SupabaseClient get _requireClient {
    final c = client;
    if (c == null) {
      throw Exception('Supabase not initialized');
    }
    return c;
  }

  Future<void> init({required String url, required String anonKey}) async {
    try {
      if (url.isEmpty || anonKey.isEmpty) {
        debugPrint('SupabaseService: URL or anonKey is empty, skipping initialization');
        return;
      }
      await Supabase.initialize(url: url, anonKey: anonKey, debug: kDebugMode);
      debugPrint('SupabaseService: Initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('SupabaseService: Error during initialization: $e');
      debugPrint('SupabaseService: Stack trace: $stackTrace');
      // Don't rethrow - allow app to continue without Supabase
    }
  }

  // Auth
  Stream<AuthState> get authStream {
    final c = client;
    if (c == null) {
      return const Stream<AuthState>.empty();
    }
    return c.auth.onAuthStateChange;
  }
  
  Session? get currentSession {
    final c = client;
    return c?.auth.currentSession;
  }
  
  User? get currentUser {
    final c = client;
    return c?.auth.currentUser;
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) {
    final c = client;
    if (c == null) {
      throw Exception('Supabase not initialized');
    }
    return c.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signInWithEmail(String email, String password) {
    final c = client;
    if (c == null) {
      throw Exception('Supabase not initialized');
    }
    return c.auth.signInWithPassword(email: email, password: password);
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
    final c = client;
    if (c != null) {
      await c.auth.signOut();
    }
  }

  // Profile helpers (public.users table with columns: user_id serial, auth_uid uuid unique, full_name text, ...)
  Future<void> upsertProfile({required String fullName}) async {
    final c = _requireClient;
    final user = currentUser;
    if (user == null) return;
    await c.from('users').upsert({
      'auth_uid': user.id,
      'full_name': fullName,
    }, onConflict: 'auth_uid');
  }

  Future<String?> getProfileName() async {
    final c = _requireClient;
    final user = currentUser;
    if (user == null) return null;
    final rows = await c.from('users').select('full_name').eq('auth_uid', user.id).maybeSingle();
    if (rows == null) return null;
    return rows['full_name'] as String?;
  }

  Future<void> sendPasswordResetEmail(String email, {String? redirectTo}) async {
    final c = _requireClient;
    final target = redirectTo ?? 'io.supabase.flutter://callback';
    await c.auth.resetPasswordForEmail(email, redirectTo: target);
  }

  Future<void> signInWithGoogle({String? redirectTo}) async {
    final c = _requireClient;
    final redirect = redirectTo ?? 'io.supabase.flutter://callback';
    await c.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirect,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  // Favorites table helpers
  // Table schema expected: favorites(id, user_id uuid, item_number int, item_type text ['hymn'|'keerthane'], created_at)
  Future<List<Map<String, dynamic>>> fetchFavorites() async {
    final c = client;
    if (c == null) return [];
    final user = currentUser;
    if (user == null) return [];
    final response = await c
        .from('favorites')
        .select('item_number,item_type')
        .eq('user_id', user.id);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addFavorite({required int itemNumber, required String itemType}) async {
    final c = client;
    if (c == null) return;
    final user = currentUser;
    if (user == null) return;
    try {
      await c.from('favorites').insert({
        'user_id': user.id,
        'item_number': itemNumber,
        'item_type': itemType,
      });
    } catch (_) {
      // ignore duplicates or transient errors silently for UX
    }
  }

  Future<void> removeFavorite({required int itemNumber, required String itemType}) async {
    final c = client;
    if (c == null) return;
    final user = currentUser;
    if (user == null) return;
    await c
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
  final CategoriesDB _categoriesDB = CategoriesDB();

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
    final supabaseClient = _requireClient;
    final Map<int, int> idMap = {};
    for (final c in localCats.where((c) => (c['deleted'] ?? 0) == 0)) {
      final inserted = await supabaseClient
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
          await _requireClient.from('custom_category_songs').insert({
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

  // Unified API (works offline on mobile, online-only on web)
  // Web: Always uses Supabase (online only)
  // Mobile: Syncs with server when online, uses local DB when offline
  Future<List<Map<String, dynamic>>> fetchCustomCategoriesUnified() async {
    final user = currentUser;
    
    // Try Supabase first (when online and authenticated)
    List<Map<String, dynamic>> remoteCategories = [];
    if (user != null) {
      try {
        // On mobile: migrate local data if needed
        if (!kIsWeb) {
          await _migrateLocalIfNeeded();
        }
        remoteCategories = await fetchCustomCategories();
        debugPrint('SupabaseService: Loaded ${remoteCategories.length} categories from Supabase');
        
        // On mobile: save to local DB for offline access
        if (!kIsWeb && remoteCategories.isNotEmpty) {
          try {
            final categoriesWithUserId = remoteCategories.map((cat) => {
              ...cat,
              'user_id': user.id,
              'deleted': 0,
              'created_at': cat['created_at'] ?? DateTime.now().toIso8601String(),
              'updated_at': cat['updated_at'] ?? DateTime.now().toIso8601String(),
            }).toList();
            await _categoriesDB.upsertCategories(categoriesWithUserId);
            debugPrint('SupabaseService: Saved ${remoteCategories.length} categories to local DB');
          } catch (dbError) {
            debugPrint('SupabaseService: Failed to save categories to local DB: $dbError');
          }
        }
      } catch (e) {
        debugPrint('SupabaseService: Supabase load failed: $e');
        if (kIsWeb) {
          // On web, if Supabase fails, we have no fallback
          debugPrint('SupabaseService: Web version requires online connection');
        }
      }
    }
    
    // On web: always return remote (Supabase) data
    if (kIsWeb) {
      return remoteCategories;
    }
    
    // On mobile: try to load from local DB (for offline access or as fallback)
    try {
      final localCategories = await _categoriesDB.getAllCategories(userId: user?.id);
      debugPrint('SupabaseService: Loaded ${localCategories.length} categories from local DB');
      
      // Use remote if available, otherwise use local
      if (remoteCategories.isNotEmpty) {
        return remoteCategories;
      } else {
        return localCategories;
      }
    } catch (dbError) {
      debugPrint('SupabaseService: Local DB load failed: $dbError');
      // If local DB fails and we're not authenticated, fall back to SharedPreferences
      if (user == null) {
        final rows = await _readLocalCategories();
        return rows.where((e) => (e['deleted'] ?? 0) == 0).toList();
      }
      return remoteCategories;
    }
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
      // On mobile: also save to SQLite DB
      if (!kIsWeb) {
        try {
          await _categoriesDB.upsertCategory({
            ...row,
            'user_id': null,
          });
        } catch (e) {
          debugPrint('SupabaseService: Failed to save guest category to SQLite: $e');
        }
      }
      return nextId;
    }
    if (!kIsWeb) {
      await _migrateLocalIfNeeded();
    }
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
      // On mobile: also update SQLite DB
      if (!kIsWeb) {
        try {
          await _categoriesDB.updateCategoryName(categoryId, newName);
        } catch (e) {
          debugPrint('SupabaseService: Failed to update guest category in SQLite: $e');
        }
      }
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
      // On mobile: also update SQLite DB
      if (!kIsWeb) {
        try {
          await _categoriesDB.softDeleteCategory(categoryId);
        } catch (e) {
          debugPrint('SupabaseService: Failed to delete guest category in SQLite: $e');
        }
      }
      return;
    }
    await softDeleteCustomCategory(categoryId);
  }

  Future<List<Map<String, dynamic>>> fetchSongsInCategoryUnified(int categoryId) async {
    final user = currentUser;
    
    // On web: always use Supabase (online only)
    // On mobile: try Supabase first, fallback to local DB
    if (user != null && categoryId >= 0) {
      try {
        final songs = await fetchSongsInCategory(categoryId);
        if (songs.isNotEmpty) {
          return songs;
        }
      } catch (e) {
        debugPrint('SupabaseService: Supabase load failed for category songs: $e');
        if (kIsWeb) {
          // On web, if Supabase fails, we have no fallback
          return [];
        }
      }
    }
    
    // On mobile: fallback to local DB
    if (!kIsWeb) {
      try {
        if (user != null) {
          return await _categoriesDB.getSongsInCategory(categoryId, userId: user.id);
        } else if (categoryId < 0) {
          // Guest user with local category
          final rows = await _readLocalSongs();
          return rows.where((r) => (r['category_id'] as num).toInt() == categoryId && (r['deleted'] ?? 0) == 0).toList();
        }
      } catch (dbError) {
        debugPrint('SupabaseService: Local DB load failed for category songs: $dbError');
      }
    }
    
    return [];
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
    final c = client;
    if (c == null) return [];
    final user = currentUser;
    if (user == null) return [];
    try {
      final rows = await c
          .from('custom_categories')
          .select('id,name,created_at,updated_at')
          .eq('user_id', user.id)
          .eq('deleted', 0)
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('SupabaseService: Error fetching categories from Supabase: $e');
      rethrow;
    }
  }

  Future<int?> createCustomCategory(String name) async {
    final c = client;
    if (c == null) return null;
    final user = currentUser;
    if (user == null) return null;
    try {
      final rows = await c
          .from('custom_categories')
          .insert({
            'user_id': user.id,
            'name': name,
          })
          .select('id')
          .single();
      final categoryId = (rows['id'] as num?)?.toInt();
      
      // On mobile: also save to local DB
      if (!kIsWeb && categoryId != null) {
        try {
          await _categoriesDB.upsertCategory({
            'id': categoryId,
            'user_id': user.id,
            'name': name,
            'deleted': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (dbError) {
          debugPrint('SupabaseService: Failed to save category to local DB: $dbError');
        }
      }
      
      return categoryId;
    } catch (e) {
      debugPrint('SupabaseService: Error creating category in Supabase: $e');
      rethrow;
    }
  }

  Future<void> renameCustomCategory(int categoryId, String newName) async {
    final c = client;
    if (c == null) return;
    final user = currentUser;
    if (user == null) return;
    try {
      await c
          .from('custom_categories')
          .update({'name': newName, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', categoryId)
          .eq('user_id', user.id);
      
      // On mobile: also update local DB
      if (!kIsWeb) {
        try {
          await _categoriesDB.updateCategoryName(categoryId, newName);
        } catch (dbError) {
          debugPrint('SupabaseService: Failed to update category in local DB: $dbError');
        }
      }
    } catch (e) {
      debugPrint('SupabaseService: Error renaming category in Supabase: $e');
      rethrow;
    }
  }

  Future<void> softDeleteCustomCategory(int categoryId) async {
    final c = client;
    if (c == null) return;
    final user = currentUser;
    if (user == null) return;
    try {
      // Prefer soft delete; fallback to hard delete if RLS blocks UPDATE
      try {
        await c
            .from('custom_categories')
            .update({'deleted': 1, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', categoryId)
            .eq('user_id', user.id);
      } on PostgrestException catch (_) {
        await c
            .from('custom_categories')
            .delete()
            .eq('id', categoryId)
            .eq('user_id', user.id);
      }
      
      // On mobile: also update local DB
      if (!kIsWeb) {
        try {
          await _categoriesDB.softDeleteCategory(categoryId);
        } catch (dbError) {
          debugPrint('SupabaseService: Failed to delete category in local DB: $dbError');
        }
      }
    } catch (e) {
      debugPrint('SupabaseService: Error deleting category in Supabase: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchSongsInCategory(int categoryId) async {
    final c = client;
    if (c == null) return [];
    final user = currentUser;
    if (user == null) return [];
    try {
      final rows = await c
          .from('custom_category_songs')
          .select('id,song_id,song_type,created_at')
          .eq('user_id', user.id)
          .eq('category_id', categoryId)
          .eq('deleted', 0)
          .order('created_at', ascending: false);
      final songs = List<Map<String, dynamic>>.from(rows);
      
      // On mobile: also save to local DB
      if (!kIsWeb && songs.isNotEmpty) {
        try {
          final songsWithUserId = songs.map((song) => {
            ...song,
            'user_id': user.id,
            'category_id': categoryId,
            'deleted': 0,
            'created_at': song['created_at'] ?? DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }).toList();
          await _categoriesDB.upsertCategorySongs(songsWithUserId);
        } catch (dbError) {
          debugPrint('SupabaseService: Failed to save category songs to local DB: $dbError');
        }
      }
      
      return songs;
    } catch (e) {
      debugPrint('SupabaseService: Error fetching songs from Supabase, trying local DB: $e');
      // Fallback to local DB
      try {
        return await _categoriesDB.getSongsInCategory(categoryId, userId: user.id);
      } catch (dbError) {
        debugPrint('SupabaseService: Local DB load also failed: $dbError');
        return [];
      }
    }
  }

  Future<void> addSongToCategory({required int categoryId, required int songId, required String songType}) async {
    final c = client;
    if (c == null) return;
    final user = currentUser;
    if (user == null) return;
    try {
      await c.from('custom_category_songs').insert({
        'category_id': categoryId,
        'user_id': user.id,
        'song_id': songId,
        'song_type': songType,
      });
      
      // On mobile: also save to local DB
      if (!kIsWeb) {
        try {
          await _categoriesDB.upsertCategorySong({
            'category_id': categoryId,
            'user_id': user.id,
            'song_id': songId,
            'song_type': songType,
            'deleted': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (dbError) {
          debugPrint('SupabaseService: Failed to save song to local DB: $dbError');
        }
      }
    } catch (e) {
      debugPrint('SupabaseService: Error adding song to category in Supabase: $e');
      // On mobile: still try to save locally as fallback
      // On web: rethrow since we need Supabase
      if (kIsWeb) {
        rethrow;
      } else {
        try {
          await _categoriesDB.upsertCategorySong({
            'category_id': categoryId,
            'user_id': user.id,
            'song_id': songId,
            'song_type': songType,
            'deleted': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (dbError) {
          debugPrint('SupabaseService: Failed to save song to local DB: $dbError');
        }
      }
    }
  }

  Future<void> removeSongFromCategory({required int categoryId, required int songId, required String songType}) async {
    final c = client;
    if (c == null) return;
    final user = currentUser;
    if (user == null) return;
    try {
      await c
          .from('custom_category_songs')
          .update({'deleted': 1, 'updated_at': DateTime.now().toIso8601String()})
          .eq('user_id', user.id)
          .eq('category_id', categoryId)
          .eq('song_id', songId)
          .eq('song_type', songType);
      
      // On mobile: also update local DB
      if (!kIsWeb) {
        try {
          await _categoriesDB.softDeleteCategorySong(categoryId, songId, songType);
        } catch (dbError) {
          debugPrint('SupabaseService: Failed to remove song from local DB: $dbError');
        }
      }
    } catch (e) {
      debugPrint('SupabaseService: Error removing song from category in Supabase: $e');
      // On mobile: still try to update locally as fallback
      // On web: rethrow since we need Supabase
      if (kIsWeb) {
        rethrow;
      } else {
        try {
          await _categoriesDB.softDeleteCategorySong(categoryId, songId, songType);
        } catch (dbError) {
          debugPrint('SupabaseService: Failed to remove song from local DB: $dbError');
        }
      }
    }
  }
}


