import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}


