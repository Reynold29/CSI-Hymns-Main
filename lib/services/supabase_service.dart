import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
        debugPrint(
            'SupabaseService: URL or anonKey is empty, skipping initialization');
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
  /// Returns true for 403/user_not_found auth errors that occur after account
  /// deletion. Use in stream onError and global error handler to avoid crashes.
  static bool isPostDeleteAuthError(Object? error) {
    if (error == null) return false;
    if (error is AuthException) {
      if (error.statusCode == '403' || error.code == 'user_not_found') {
        return true;
      }
    }
    final s = error.toString();
    return s.contains('user_not_found') ||
        (s.contains('403') && s.contains('JWT'));
  }

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
    final rows = await c
        .from('users')
        .select('full_name')
        .eq('auth_uid', user.id)
        .maybeSingle();
    if (rows == null) return null;
    return rows['full_name'] as String?;
  }

  Future<void> sendPasswordResetEmail(String email,
      {String? redirectTo}) async {
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
      // Use the external browser (Safari.app) instead of SFSafariViewController.
      // SFSafariViewController does NOT auto-dismiss on custom URL scheme redirect,
      // leaving the OAuth sheet stuck open. Safari.app handles it properly.
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Performs Apple sign in on iOS or macOS
  Future<AuthResponse> signInWithApple() async {
    final c = _requireClient;
    final rawNonce = _requireClient.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Could not find ID Token from Apple Sign In.');
    }

    final AuthResponse res = await c.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    // If we got user info from Apple (usually only on first sign in), save it
    if (res.user != null) {
      final String? name =
          (credential.givenName != null || credential.familyName != null)
              ? '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                  .trim()
              : null;
      if (name != null && name.isNotEmpty) {
        await upsertProfile(fullName: name);
      }
    }

    return res;
  }

  /// Deletes the user account by calling the Supabase RPC, then signs out
  /// immediately so the app never uses the deleted user's session. Any 403
  /// (user_not_found) is expected after deletion and treated as success.
  Future<void> deleteAccount() async {
    final c = _requireClient;
    final user = currentUser;
    if (user == null) return;

    try {
      await c.rpc('delete_user_account');
    } catch (e) {
      if (isPostDeleteAuthError(e)) {
        // User was deleted; treat as success and clear session below.
      } else {
        rethrow;
      }
    } finally {
      // Always clear session and local data so we never use the deleted user again.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('favoriteHymnIds');
        await prefs.remove('favoriteKeerthaneIds');
        await prefs.remove('favorites_owner_auth_uid');
      } catch (_) {}
      try {
        await c.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
    }
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

  Future<void> addFavorite(
      {required int itemNumber, required String itemType}) async {
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

  Future<void> removeFavorite(
      {required int itemNumber, required String itemType}) async {
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

  // Local helpers
  Future<List<Map<String, dynamic>>> _readLocalCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localCatsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List)
        .cast<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
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
    final list = (jsonDecode(raw) as List)
        .cast<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
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
        debugPrint(
            'SupabaseService: Loaded ${remoteCategories.length} categories from Supabase');
      } catch (e) {
        debugPrint('SupabaseService: Supabase load failed: $e');
        if (kIsWeb) {
          // On web, if Supabase fails, we have no fallback
          debugPrint('SupabaseService: Web version requires online connection');
        }
      }
    }

    // On web or if authenticated, return remote (Supabase) data
    if (kIsWeb || user != null) {
      return remoteCategories;
    }

    // Guest user: fallback to SharedPreferences
    final rows = await _readLocalCategories();
    return rows.where((e) => (e['deleted'] ?? 0) == 0).toList();
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
        final mins = current
            .map((e) => (e['id'] as num).toInt())
            .reduce((a, b) => a < b ? a : b);
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
    if (!kIsWeb) {
      await _migrateLocalIfNeeded();
    }
    return await createCustomCategory(name);
  }

  Future<void> renameCustomCategoryUnified(
      int categoryId, String newName) async {
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

  Future<List<Map<String, dynamic>>> fetchSongsInCategoryUnified(
      int categoryId) async {
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
        debugPrint(
            'SupabaseService: Supabase load failed for category songs: $e');
        if (kIsWeb) {
          // On web, if Supabase fails, we have no fallback
          return [];
        }
      }
    }

    // Guest user or offline (mobile): fallback to SharedPreferences
    if (!kIsWeb && user == null && categoryId < 0) {
      final rows = await _readLocalSongs();
      return rows
          .where((r) =>
              (r['category_id'] as num).toInt() == categoryId &&
              (r['deleted'] ?? 0) == 0)
          .toList();
    }

    return [];
  }

  Future<void> addSongToCategoryUnified(
      {required int categoryId,
      required int songId,
      required String songType}) async {
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
    await addSongToCategory(
        categoryId: categoryId, songId: songId, songType: songType);
  }

  Future<void> removeSongFromCategoryUnified(
      {required int categoryId,
      required int songId,
      required String songType}) async {
    final user = currentUser;
    if (user == null || categoryId < 0) {
      final rows = await _readLocalSongs();
      for (final r in rows) {
        if ((r['category_id'] as num).toInt() == categoryId &&
            (r['song_id'] as num).toInt() == songId &&
            r['song_type'] == songType) {
          r['deleted'] = 1;
          r['updated_at'] = DateTime.now().toIso8601String();
        }
      }
      await _writeLocalSongs(rows);
      return;
    }
    await removeSongFromCategory(
        categoryId: categoryId, songId: songId, songType: songType);
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
      debugPrint(
          'SupabaseService: Error fetching categories from Supabase: $e');
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
          .update(
              {'name': newName, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', categoryId)
          .eq('user_id', user.id);
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
            .update(
                {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', categoryId)
            .eq('user_id', user.id);
      } on PostgrestException catch (_) {
        await c
            .from('custom_categories')
            .delete()
            .eq('id', categoryId)
            .eq('user_id', user.id);
      }
    } catch (e) {
      debugPrint('SupabaseService: Error deleting category in Supabase: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchSongsInCategory(
      int categoryId) async {
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
      return songs;
    } catch (e) {
      debugPrint(
          'SupabaseService: Error fetching songs from Supabase: $e');
      return [];
    }
  }

  Future<void> addSongToCategory(
      {required int categoryId,
      required int songId,
      required String songType}) async {
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
    } catch (e) {
      debugPrint(
          'SupabaseService: Error adding song to category in Supabase: $e');
      if (kIsWeb) {
        rethrow;
      }
    }
  }

  Future<void> removeSongFromCategory(
      {required int categoryId,
      required int songId,
      required String songType}) async {
    final c = client;
    if (c == null) return;
    final user = currentUser;
    if (user == null) return;
    try {
      await c
          .from('custom_category_songs')
          .update(
              {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()})
          .eq('user_id', user.id)
          .eq('category_id', categoryId)
          .eq('song_id', songId)
          .eq('song_type', songType);
    } catch (e) {
      debugPrint(
          'SupabaseService: Error removing song from category in Supabase: $e');
      if (kIsWeb) {
        rethrow;
      }
    }
  }
}
