import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hymns_latest/models/christmas_carol.dart';
import 'package:hymns_latest/services/christmas_carols_db.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

/// Service for managing Christmas Carols data.
/// 
/// **Visibility Rules:**
/// - ALL uploaded carols are PUBLIC and visible to everyone
/// - Any user (registered or not) can browse and view all carols
/// - Only AUTHENTICATED users can add, edit, or delete carols
/// - ADMIN users can edit/delete any carol
/// 
/// **Data Sources:**
/// - Bundled assets (seed data) - always available
/// - Supabase (user-uploaded carols) - public read, authenticated write
/// - Local storage (fallback when offline)
/// 
/// **PDF Storage:**
/// - PDFs are uploaded to Supabase Storage with public URLs
/// - Everyone can view PDFs attached to carols
class ChristmasCarolsService with ChangeNotifier {
  static const String _hiddenChurchesKey = 'hidden_churches';
  static const String _remoteJsonUrlKey = 'remote_carols_json_url';
  static const String _remoteJsonLastFetchKey = 'remote_carols_last_fetch';
  static const String _supabaseTable = 'christmas_carols';
  static const String _supabaseBucket = 'carol-pdfs';
  
  final ChristmasCarolsDB _db = ChristmasCarolsDB();
  
  // Default remote JSON URL
  static const String _defaultRemoteJsonUrl = 'https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/carols_data.json';
  
  // Cache duration for remote JSON (24 hours)
  static const Duration _remoteJsonCacheDuration = Duration(hours: 24);
  
  /// Admin emails with full CRUD access to all carols
  static const List<String> adminEmails = [
    'reynoldclare29022902@gmail.com',
    'reynoldclare02@gmail.com',
    'reyziecrafts@gmail.com',
    'reynold.clare29022902@gmail.com'
  ];
  
  /// Check if current user is an admin
  bool get isAdmin {
    try {
      final supabase = _getSupabaseClient();
      if (supabase == null) return false;
      final user = supabase.auth.currentUser;
      if (user == null) return false;
      return adminEmails.contains(user.email?.toLowerCase());
    } catch (e) {
      debugPrint('ChristmasCarolsService: Error checking admin status: $e');
      return false;
    }
  }
  
  /// Check if current user can edit a specific carol
  bool canEditCarol(ChristmasCarol carol) {
    try {
      final supabase = _getSupabaseClient();
      if (supabase == null) return false;
      final user = supabase.auth.currentUser;
      if (user == null) return false;
      // Admins can edit anything, or user can edit their own
      return isAdmin || carol.createdByUserId == user.id;
    } catch (e) {
      debugPrint('ChristmasCarolsService: Error checking edit permission: $e');
      return false;
    }
  }
  
  /// Check if current user can delete a specific carol
  bool canDeleteCarol(ChristmasCarol carol) {
    return canEditCarol(carol); // Same rules as edit
  }
  
  List<ChristmasCarol> _carols = [];
  bool _isLoading = false;
  
  List<ChristmasCarol> get carols => _carols;
  bool get isLoading => _isLoading;

  final Uuid _uuid = const Uuid();
  
  /// Safely get Supabase client, returns null if not initialized
  SupabaseClient? _getSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('ChristmasCarolsService: Supabase not initialized: $e');
      return null;
    }
  }

  /// Loads all carols from bundled assets, remote JSON, and local/remote storage
  /// Web: Always loads from Supabase/GitHub (online only)
  /// Mobile: When online loads from Supabase and saves to local DB, when offline loads from local DB
  Future<List<ChristmasCarol>> loadAllCarols({bool checkGitHub = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<ChristmasCarol> allCarols = [];
      
      // Get list of hidden churches (for bundled/remote carols)
      final hiddenChurches = await _getHiddenChurches();
      
      // 1. Load bundled seed carols (filter out hidden churches)
      final bundledCarols = await _loadBundledCarols();
      final visibleBundled = bundledCarols.where((c) => !hiddenChurches.contains(c.churchName)).toList();
      allCarols.addAll(visibleBundled);
      
      // 2. Load remote JSON carols (if URL is configured)
      final remoteJsonCarols = await _loadRemoteJsonCarols();
      final visibleRemoteJson = remoteJsonCarols.where((c) => !hiddenChurches.contains(c.churchName)).toList();
      allCarols.addAll(visibleRemoteJson);
      
      // 3. Load user carols from Supabase
      List<ChristmasCarol> userCarols = [];
      List<ChristmasCarol> remoteCarols = [];
      
      // Try Supabase first
      try {
        remoteCarols = await _loadFromSupabase();
        debugPrint('ChristmasCarolsService: Loaded ${remoteCarols.length} carols from Supabase');
        
        // On web: always use Supabase, skip local DB
        // On mobile: save to local DB for offline access
        if (!kIsWeb && remoteCarols.isNotEmpty) {
          try {
            await _db.upsertCarols(remoteCarols);
            debugPrint('ChristmasCarolsService: Saved ${remoteCarols.length} carols to local DB');
          } catch (dbError) {
            debugPrint('ChristmasCarolsService: Failed to save to local DB: $dbError');
            // Continue even if DB save fails
          }
        }
      } catch (e) {
        // Supabase failed (offline or error)
        debugPrint('ChristmasCarolsService: Supabase load failed: $e');
        if (kIsWeb) {
          // On web, if Supabase fails, we have no fallback - return what we have
          debugPrint('ChristmasCarolsService: Web version requires online connection');
        }
      }
      
      // On mobile: try to load from local DB (for offline access or as fallback)
      // On web: skip local DB entirely
      if (!kIsWeb) {
        try {
          final localCarols = await _loadFromLocalDB();
          debugPrint('ChristmasCarolsService: Loaded ${localCarols.length} carols from local DB');
          
          // Merge: prefer remote if available, otherwise use local
          if (remoteCarols.isNotEmpty) {
            userCarols = remoteCarols;
          } else {
            userCarols = localCarols;
          }
        } catch (dbError) {
          debugPrint('ChristmasCarolsService: Local DB load failed: $dbError');
          // If local DB fails, use remote if we got it
          userCarols = remoteCarols;
        }
      } else {
        // Web: always use remote (Supabase)
        userCarols = remoteCarols;
      }
      
      allCarols.addAll(userCarols);
      debugPrint('ChristmasCarolsService: Total carols after loading: ${allCarols.length} (bundled: ${visibleBundled.length}, remote JSON: ${visibleRemoteJson.length}, user: ${userCarols.length})');
      
      // Remove duplicates (keep the one with latest updatedAt)
      final Map<String, ChristmasCarol> uniqueCarols = {};
      for (final carol in allCarols) {
        if (!uniqueCarols.containsKey(carol.id)) {
          uniqueCarols[carol.id] = carol;
        } else {
          final existing = uniqueCarols[carol.id]!;
          // Keep the one with newer updatedAt, or createdAt if updatedAt is null
          final existingDate = existing.updatedAt ?? existing.createdAt;
          final carolDate = carol.updatedAt ?? carol.createdAt;
          if (carolDate.isAfter(existingDate)) {
            uniqueCarols[carol.id] = carol;
          }
        }
      }
      
      // Sort by created date (newest first) then by title
      final sortedCarols = uniqueCarols.values.toList();
      sortedCarols.sort((a, b) {
        final dateCompare = b.createdAt.compareTo(a.createdAt);
        if (dateCompare != 0) return dateCompare;
        return a.title.compareTo(b.title);
      });
      
      _carols = sortedCarols;
      _isLoading = false;
      notifyListeners();
      
      return sortedCarols;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('ChristmasCarolsService: Error loading carols: $e');
      rethrow;
    }
  }
  
  /// Refreshes carols from all sources
  Future<void> refreshCarols() async {
    await loadAllCarols(checkGitHub: false);
  }
  
  /// Gets list of hidden churches (for bundled carols)
  Future<Set<String>> _getHiddenChurches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hidden = prefs.getStringList(_hiddenChurchesKey) ?? [];
      return hidden.toSet();
    } catch (e) {
      return {};
    }
  }
  
  /// Marks a church as hidden (for bundled carols)
  Future<void> _hideChurch(String churchName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hidden = prefs.getStringList(_hiddenChurchesKey) ?? [];
      if (!hidden.contains(churchName)) {
        hidden.add(churchName);
        await prefs.setStringList(_hiddenChurchesKey, hidden);
      }
    } catch (e) {
      debugPrint('ChristmasCarolsService: Failed to hide church: $e');
    }
  }

  /// Loads bundled carols from assets
  Future<List<ChristmasCarol>> _loadBundledCarols() async {
    try {
      final String jsonData = await rootBundle.loadString(
        'lib/assets/data/christmas_carols.json',
      );
      final List<dynamic> data = jsonDecode(jsonData);
      return data.map((item) => ChristmasCarol.fromJson(item)).toList();
    } catch (e) {
      debugPrint('ChristmasCarolsService: No bundled carols found: $e');
      return [];
    }
  }
  
  /// Loads carols from remote JSON URL (with caching)
  Future<List<ChristmasCarol>> _loadRemoteJsonCarols() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? remoteUrl = prefs.getString(_remoteJsonUrlKey);
      
      // Use default URL if none is configured
      if (remoteUrl == null || remoteUrl.isEmpty) {
        remoteUrl = _defaultRemoteJsonUrl;
      }
      
      // Check cache
      final lastFetchStr = prefs.getString(_remoteJsonLastFetchKey);
      if (lastFetchStr != null) {
        final lastFetch = DateTime.parse(lastFetchStr);
        final now = DateTime.now();
        if (now.difference(lastFetch) < _remoteJsonCacheDuration) {
          // Use cached data
          final cachedData = prefs.getString('remote_carols_cached');
          if (cachedData != null) {
            final List<dynamic> data = jsonDecode(cachedData);
            return data.map((item) => ChristmasCarol.fromJson(item)).toList();
          }
        }
      }
      
      // Fetch from remote URL
      final response = await http.get(Uri.parse(remoteUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final carols = data.map((item) => ChristmasCarol.fromJson(item)).toList();
        
        // Cache the data
        await prefs.setString('remote_carols_cached', response.body);
        await prefs.setString(_remoteJsonLastFetchKey, DateTime.now().toIso8601String());
        
        return carols;
      } else {
        debugPrint('ChristmasCarolsService: Remote JSON fetch failed: ${response.statusCode}');
        // Return cached data if available
        final cachedData = prefs.getString('remote_carols_cached');
        if (cachedData != null) {
          final List<dynamic> data = jsonDecode(cachedData);
          return data.map((item) => ChristmasCarol.fromJson(item)).toList();
        }
        return [];
      }
    } catch (e) {
      debugPrint('ChristmasCarolsService: Remote JSON load failed: $e');
      // Return cached data if available
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString('remote_carols_cached');
        if (cachedData != null) {
          final List<dynamic> data = jsonDecode(cachedData);
          return data.map((item) => ChristmasCarol.fromJson(item)).toList();
        }
      } catch (_) {}
      return [];
    }
  }
  
  /// Sets the remote JSON URL for carols
  Future<void> setRemoteJsonUrl(String? url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url == null || url.isEmpty) {
        await prefs.remove(_remoteJsonUrlKey);
        await prefs.remove(_remoteJsonLastFetchKey);
        await prefs.remove('remote_carols_cached');
      } else {
        await prefs.setString(_remoteJsonUrlKey, url);
        // Clear cache to force refresh
        await prefs.remove(_remoteJsonLastFetchKey);
        await prefs.remove('remote_carols_cached');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('ChristmasCarolsService: Failed to set remote JSON URL: $e');
    }
  }
  
  /// Gets the current remote JSON URL (returns default if none set)
  Future<String?> getRemoteJsonUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customUrl = prefs.getString(_remoteJsonUrlKey);
      // Return custom URL if set, otherwise return default
      return customUrl ?? _defaultRemoteJsonUrl;
    } catch (e) {
      return _defaultRemoteJsonUrl;
    }
  }
  
  /// Gets the default remote JSON URL
  String get defaultRemoteJsonUrl => _defaultRemoteJsonUrl;
  
  /// Imports carols from a local JSON file
  Future<List<ChristmasCarol>> importFromJsonFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }
      
      final jsonData = await file.readAsString();
      final List<dynamic> data = jsonDecode(jsonData);
      final carols = data.map((item) => ChristmasCarol.fromJson(item)).toList();
      
      // Save to local database
      await _db.upsertCarols(carols);
      
      // Refresh
      await loadAllCarols();
      
      return carols;
    } catch (e) {
      debugPrint('ChristmasCarolsService: Import from JSON failed: $e');
      rethrow;
    }
  }
  
  /// Exports all carols to JSON file
  Future<String> exportToJsonFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/christmas_carols_export_${DateTime.now().millisecondsSinceEpoch}.json');
      
      final jsonData = jsonEncode(_carols.map((c) => c.toJson()).toList());
      await file.writeAsString(jsonData);
      
      return file.path;
    } catch (e) {
      debugPrint('ChristmasCarolsService: Export to JSON failed: $e');
      rethrow;
    }
  }
  
  /// Forces refresh of remote JSON (bypasses cache)
  Future<void> refreshRemoteJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_remoteJsonLastFetchKey);
      await prefs.remove('remote_carols_cached');
      await loadAllCarols();
    } catch (e) {
      debugPrint('ChristmasCarolsService: Refresh remote JSON failed: $e');
    }
  }


  /// Loads ALL carols from Supabase - PUBLIC ACCESS
  /// No authentication required to read carols.
  /// All uploaded carols are visible to everyone.
  Future<List<ChristmasCarol>> _loadFromSupabase() async {
    try {
      final supabase = _getSupabaseClient();
      if (supabase == null) return [];
      
      // Fetch ALL carols - no user filter, everyone can see everything
      final response = await supabase
          .from(_supabaseTable)
          .select()
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((item) => ChristmasCarol.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('ChristmasCarolsService: Supabase load failed: $e');
      return [];
    }
  }

  /// Loads carols from local SQLite database
  /// This is the primary source for offline access (mobile only)
  /// Web version always returns empty list
  Future<List<ChristmasCarol>> _loadFromLocalDB() async {
    // Web doesn't use local DB
    if (kIsWeb) {
      return [];
    }
    
    try {
      final count = await _db.getCarolCount();
      debugPrint('ChristmasCarolsService: Local DB has $count carols');
      final carols = await _db.getAllCarols();
      debugPrint('ChristmasCarolsService: Successfully loaded ${carols.length} carols from local DB');
      return carols;
    } catch (e, stackTrace) {
      debugPrint('ChristmasCarolsService: Local DB load failed: $e');
      debugPrint('ChristmasCarolsService: Stack trace: $stackTrace');
      return [];
    }
  }


  /// Adds a new carol
  Future<ChristmasCarol> addCarol({
    required String title,
    String? songNumber,
    required String churchName,
    String? lyrics,
    File? pdfFile,
    int transpose = 0,
    String scale = 'C Major',
    bool hasChords = true,
  }) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) {
      throw Exception('Supabase not initialized');
    }
    
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to add carols');
    }

    final carolId = _uuid.v4();
    String? pdfPath;

    // Upload PDF if provided
    if (pdfFile != null) {
      pdfPath = await _uploadPdf(pdfFile, carolId);
    }

    final carol = ChristmasCarol(
      id: carolId,
      title: title,
      songNumber: songNumber,
      churchName: churchName,
      lyrics: lyrics,
      pdfPath: pdfPath,
      transpose: transpose,
      scale: scale,
      hasChords: hasChords,
      createdByUserId: user.id,
      createdAt: DateTime.now(),
    );

    // Save to Supabase (and local DB on mobile only)
    try {
      await supabase.from(_supabaseTable).insert(carol.toJson());
      // On mobile: also save to local DB for offline access
      if (!kIsWeb) {
        try {
          await _db.upsertCarol(carol);
        } catch (dbError) {
          debugPrint('ChristmasCarolsService: Failed to save to local DB: $dbError');
        }
      }
    } catch (e) {
      // On mobile: If Supabase fails, save locally as fallback
      // On web: rethrow since we need Supabase
      if (kIsWeb) {
        debugPrint('ChristmasCarolsService: Supabase insert failed on web: $e');
        rethrow;
      } else {
        debugPrint('ChristmasCarolsService: Supabase insert failed, saving locally: $e');
        await _db.upsertCarol(carol);
      }
    }

    // Refresh the list
    await loadAllCarols();
    
    return carol;
  }

  /// Uploads a PDF file to storage
  Future<String?> _uploadPdf(File pdfFile, String carolId) async {
    try {
      final supabase = _getSupabaseClient();
      if (supabase == null) return null;
      final fileName = '$carolId.pdf';
      final bytes = await pdfFile.readAsBytes();
      
      // Try Supabase storage first
      try {
        await supabase.storage.from(_supabaseBucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
        
        final publicUrl = supabase.storage.from(_supabaseBucket).getPublicUrl(fileName);
        return publicUrl;
      } catch (e) {
        debugPrint('ChristmasCarolsService: Supabase upload failed: $e');
        // Fallback: save locally
        return await _savePdfLocally(pdfFile, carolId);
      }
    } catch (e) {
      debugPrint('ChristmasCarolsService: PDF upload failed: $e');
      return null;
    }
  }

  /// Saves PDF to local app storage
  Future<String?> _savePdfLocally(File pdfFile, String carolId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final pdfDir = Directory('${directory.path}/carol_pdfs');
      
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
      }
      
      final localPath = '${pdfDir.path}/$carolId.pdf';
      await pdfFile.copy(localPath);
      
      return localPath;
    } catch (e) {
      debugPrint('ChristmasCarolsService: Local PDF save failed: $e');
      return null;
    }
  }

  /// Updates an existing carol
  /// Admins can update any carol, regular users can only update their own
  Future<void> updateCarol(ChristmasCarol carol) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) {
      throw Exception('Supabase not initialized');
    }
    final user = supabase.auth.currentUser;
    
    if (user == null) {
      throw Exception('User must be authenticated to update carols');
    }
    
    if (!canEditCarol(carol)) {
      throw Exception('You can only update your own carols');
    }

    final updatedCarol = carol.copyWith(updatedAt: DateTime.now());

    // Only send updatable fields to Supabase (exclude id, created_at, created_by_user_id)
    final updateData = {
      'title': updatedCarol.title,
      'song_number': updatedCarol.songNumber,
      'church_name': updatedCarol.churchName,
      'lyrics': updatedCarol.lyrics,
      'pdf': updatedCarol.pdfPath,
      'pdf_pages': updatedCarol.pdfPages,
      'transpose': updatedCarol.transpose,
      'scale': updatedCarol.scale,
      'has_chords': updatedCarol.hasChords,
      'updated_at': updatedCarol.updatedAt?.toIso8601String(),
    };

    try {
      if (isAdmin) {
        // Admins can update any carol
        await supabase
            .from(_supabaseTable)
            .update(updateData)
            .eq('id', carol.id);
      } else {
        // Regular users can only update their own
        await supabase
            .from(_supabaseTable)
            .update(updateData)
            .eq('id', carol.id)
            .eq('created_by_user_id', user.id);
      }
      // Also update local DB for offline access
      // On mobile: also update local DB
      if (!kIsWeb) {
        try {
          await _db.upsertCarol(updatedCarol);
        } catch (dbError) {
          debugPrint('ChristmasCarolsService: Failed to update local DB: $dbError');
        }
      }
    } catch (e) {
      debugPrint('ChristmasCarolsService: Supabase update failed: $e');
      // On mobile: update locally as fallback
      // On web: rethrow since we need Supabase
      if (kIsWeb) {
        rethrow;
      } else {
        await _db.upsertCarol(updatedCarol);
      }
    }

    await loadAllCarols();
  }

  /// Deletes a carol
  /// Admins can delete any carol, regular users can only delete their own
  Future<void> deleteCarol(String carolId, {ChristmasCarol? carol}) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) {
      throw Exception('Supabase not initialized');
    }
    final user = supabase.auth.currentUser;
    
    if (user == null) {
      throw Exception('User must be authenticated to delete carols');
    }
    
    // Check permissions if carol object provided
    if (carol != null && !canDeleteCarol(carol)) {
      throw Exception('You can only delete your own carols');
    }

    try {
      // Delete PDF from storage first
      try {
        await supabase.storage.from(_supabaseBucket).remove(['$carolId.pdf']);
      } catch (e) {
        // Ignore storage deletion errors
      }

      if (isAdmin) {
        // Admins can delete any carol
        await supabase
            .from(_supabaseTable)
            .delete()
            .eq('id', carolId);
      } else {
        // Regular users can only delete their own
        await supabase
            .from(_supabaseTable)
            .delete()
            .eq('id', carolId)
            .eq('created_by_user_id', user.id);
      }
      // On mobile: also delete from local DB
      if (!kIsWeb) {
        try {
          await _db.deleteCarol(carolId);
        } catch (dbError) {
          debugPrint('ChristmasCarolsService: Failed to delete from local DB: $dbError');
        }
      }
    } catch (e) {
      debugPrint('ChristmasCarolsService: Supabase delete failed: $e');
      // Delete locally as fallback
      await _db.deleteCarol(carolId);
    }

    await loadAllCarols();
  }
  
  /// Deletes an entire church and all its carols
  /// Only admins or the user who created the first carol in the church can do this
  /// For bundled churches, marks them as hidden instead of deleting
  Future<void> deleteChurch(String churchName) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) {
      throw Exception('Supabase not initialized');
    }
    final user = supabase.auth.currentUser;
    
    if (user == null) {
      throw Exception('User must be authenticated to delete churches');
    }
    
      // Get all carols for this church
      final carols = _carols.where((c) => c.churchName == churchName).toList();
      
    if (carols.isEmpty) {
      throw Exception('Church not found');
    }
    
    // Check permissions: Admin OR creator of the first carol
    final firstCarol = carols.first;
    final canDelete = isAdmin || firstCarol.createdByUserId == user.id;
    
    if (!canDelete) {
      throw Exception('Only admins or the church creator can delete churches');
    }
    
    try {
      // Separate bundled and user-uploaded carols
      final bundledCarols = carols.where((c) => c.createdByUserId == 'system').toList();
      final userCarols = carols.where((c) => c.createdByUserId != 'system').toList();
      
      // If there are bundled carols, mark church as hidden
      if (bundledCarols.isNotEmpty) {
        await _hideChurch(churchName);
      }
      
      // Delete user-uploaded carols from Supabase
      if (userCarols.isNotEmpty) {
        // Delete PDFs first
        for (final carol in userCarols) {
          if (carol.hasPdf) {
            try {
              await supabase.storage.from(_supabaseBucket).remove(['${carol.id}.pdf']);
            } catch (e) {
              // Ignore storage errors
            }
          }
        }
        
        // Delete all user carols for this church from database
        final userCarolIds = userCarols.map((c) => c.id).toList();
        for (final carolId in userCarolIds) {
          try {
            await supabase
                .from(_supabaseTable)
                .delete()
                .eq('id', carolId);
          } catch (e) {
            debugPrint('ChristmasCarolsService: Failed to delete carol $carolId: $e');
          }
        }
      }
      
      // On mobile: also delete from local DB
      if (!kIsWeb) {
        try {
          await _db.deleteCarolsByChurch(churchName);
        } catch (dbError) {
          debugPrint('ChristmasCarolsService: Failed to delete church from local DB: $dbError');
        }
      }
    } catch (e) {
      debugPrint('ChristmasCarolsService: Delete church failed: $e');
      rethrow;
    }
    
    await loadAllCarols();
  }
  
  /// Check if current user can delete a church
  bool canDeleteChurch(String churchName) {
    final supabase = _getSupabaseClient();
    if (supabase == null) return false;
    final user = supabase.auth.currentUser;
    
    if (user == null) return false;
    if (isAdmin) return true;
    
    // Check if user created the first carol in this church
    final carols = _carols.where((c) => c.churchName == churchName).toList();
    if (carols.isEmpty) return false;
    
    final firstCarol = carols.first;
    return firstCarol.createdByUserId == user.id;
  }

  /// Gets a single carol by ID
  ChristmasCarol? getCarolById(String id) {
    try {
      return _carols.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Adds a new carol with just a PDF file (no lyrics)
  Future<ChristmasCarol> addCarolWithPdf({
    required String title,
    String? songNumber,
    required String churchName,
    required String pdfPath,
    int transpose = 0,
    String scale = 'C Major',
  }) async {
    final pdfFile = File(pdfPath);
    return addCarol(
      title: title,
      songNumber: songNumber,
      churchName: churchName,
      pdfFile: pdfFile,
      transpose: transpose,
      scale: scale,
    );
  }

  /// Migrates local carols to Supabase when user logs in
  Future<void> migrateLocalToRemote() async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return;
    final user = supabase.auth.currentUser;
    
    if (user == null) return;

    final localCarols = await _loadFromLocalDB();
    if (localCarols.isEmpty) return;

    for (final carol in localCarols) {
      try {
        final updatedCarol = carol.copyWith(createdByUserId: user.id);
        await supabase.from(_supabaseTable).insert(updatedCarol.toJson());
      } catch (e) {
        debugPrint('ChristmasCarolsService: Migration failed for ${carol.id}: $e');
      }
    }

    // Migration complete - local DB will be synced from Supabase on next load
    await loadAllCarols();
  }
}

