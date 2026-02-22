import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

/// SQLite database helper for storing custom categories locally
/// This ensures categories are available offline
class CategoriesDB {
  static const String _dbName = 'custom_categories.db';
  static const int _dbVersion = 1;
  static const String _categoriesTable = 'categories';
  static const String _categorySongsTable = 'category_songs';
  
  static Database? _database;
  
  /// Get the database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  /// Initialize the database
  static Future<Database> _initDatabase() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, _dbName);
      debugPrint('CategoriesDB: Initializing database at: $path');
      
      final db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      
      debugPrint('CategoriesDB: Database initialized successfully');
      return db;
    } catch (e, stackTrace) {
      debugPrint('CategoriesDB: Error initializing database: $e');
      debugPrint('CategoriesDB: Stack trace: $stackTrace');
      // Don't rethrow - return a minimal in-memory database instead
      try {
        return await openDatabase(
          ':memory:',
          version: _dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
      } catch (e2) {
        debugPrint('CategoriesDB: Failed to create in-memory database: $e2');
        // Last resort: rethrow the original error
        rethrow;
      }
    }
  }
  
  /// Create the database schema
  static Future<void> _onCreate(Database db, int version) async {
    // Categories table
    await db.execute('''
      CREATE TABLE $_categoriesTable (
        id INTEGER PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    
    // Category songs table
    await db.execute('''
      CREATE TABLE $_categorySongsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        user_id TEXT,
        song_id INTEGER NOT NULL,
        song_type TEXT NOT NULL,
        deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (category_id) REFERENCES $_categoriesTable(id) ON DELETE CASCADE
      )
    ''');
    
    // Create indexes
    await db.execute('CREATE INDEX idx_category_user ON $_categoriesTable(user_id)');
    await db.execute('CREATE INDEX idx_category_deleted ON $_categoriesTable(deleted)');
    await db.execute('CREATE INDEX idx_category_songs_category ON $_categorySongsTable(category_id)');
    await db.execute('CREATE INDEX idx_category_songs_user ON $_categorySongsTable(user_id)');
  }
  
  /// Handle database upgrades
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema changes here
  }
  
  // ========== Categories ==========
  
  /// Insert or replace a category (upsert)
  Future<void> upsertCategory(Map<String, dynamic> category) async {
    final db = await database;
    await db.insert(
      _categoriesTable,
      {
        'id': category['id'],
        'user_id': category['user_id'],
        'name': category['name'],
        'deleted': category['deleted'] ?? 0,
        'created_at': category['created_at'],
        'updated_at': category['updated_at'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Insert or replace multiple categories
  Future<void> upsertCategories(List<Map<String, dynamic>> categories) async {
    if (categories.isEmpty) return;
    
    try {
      final db = await database;
      final batch = db.batch();
      
      for (final category in categories) {
        batch.insert(
          _categoriesTable,
          {
            'id': category['id'],
            'user_id': category['user_id'],
            'name': category['name'],
            'deleted': category['deleted'] ?? 0,
            'created_at': category['created_at'],
            'updated_at': category['updated_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
      debugPrint('CategoriesDB: Successfully saved ${categories.length} categories to database');
    } catch (e) {
      debugPrint('CategoriesDB: Error saving categories: $e');
      rethrow;
    }
  }
  
  /// Get all categories for a user
  Future<List<Map<String, dynamic>>> getAllCategories({String? userId}) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps;
      
      if (userId != null) {
        maps = await db.query(
          _categoriesTable,
          where: 'user_id = ? AND deleted = 0',
          whereArgs: [userId],
          orderBy: 'updated_at DESC',
        );
      } else {
        maps = await db.query(
          _categoriesTable,
          where: 'deleted = 0',
          orderBy: 'updated_at DESC',
        );
      }
      
      return maps.map((map) => {
        'id': map['id'],
        'name': map['name'],
        'created_at': map['created_at'],
        'updated_at': map['updated_at'],
      }).toList();
    } catch (e) {
      debugPrint('CategoriesDB: Error loading categories: $e');
      rethrow;
    }
  }
  
  /// Get a category by ID
  Future<Map<String, dynamic>?> getCategoryById(int categoryId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _categoriesTable,
      where: 'id = ? AND deleted = 0',
      whereArgs: [categoryId],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return {
      'id': maps.first['id'],
      'name': maps.first['name'],
      'created_at': maps.first['created_at'],
      'updated_at': maps.first['updated_at'],
    };
  }
  
  /// Update category name
  Future<void> updateCategoryName(int categoryId, String newName) async {
    final db = await database;
    await db.update(
      _categoriesTable,
      {
        'name': newName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }
  
  /// Soft delete a category
  Future<void> softDeleteCategory(int categoryId) async {
    final db = await database;
    await db.update(
      _categoriesTable,
      {
        'deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }
  
  // ========== Category Songs ==========
  
  /// Insert or replace a category song (upsert)
  Future<void> upsertCategorySong(Map<String, dynamic> song) async {
    final db = await database;
    await db.insert(
      _categorySongsTable,
      {
        'category_id': song['category_id'],
        'user_id': song['user_id'],
        'song_id': song['song_id'],
        'song_type': song['song_type'],
        'deleted': song['deleted'] ?? 0,
        'created_at': song['created_at'],
        'updated_at': song['updated_at'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Insert or replace multiple category songs
  Future<void> upsertCategorySongs(List<Map<String, dynamic>> songs) async {
    if (songs.isEmpty) return;
    
    try {
      final db = await database;
      final batch = db.batch();
      
      for (final song in songs) {
        batch.insert(
          _categorySongsTable,
          {
            'category_id': song['category_id'],
            'user_id': song['user_id'],
            'song_id': song['song_id'],
            'song_type': song['song_type'],
            'deleted': song['deleted'] ?? 0,
            'created_at': song['created_at'],
            'updated_at': song['updated_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('CategoriesDB: Error saving category songs: $e');
      rethrow;
    }
  }
  
  /// Get all songs in a category
  Future<List<Map<String, dynamic>>> getSongsInCategory(int categoryId, {String? userId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;
    
    if (userId != null) {
      maps = await db.query(
        _categorySongsTable,
        where: 'category_id = ? AND user_id = ? AND deleted = 0',
        whereArgs: [categoryId, userId],
        orderBy: 'created_at DESC',
      );
    } else {
      maps = await db.query(
        _categorySongsTable,
        where: 'category_id = ? AND deleted = 0',
        whereArgs: [categoryId],
        orderBy: 'created_at DESC',
      );
    }
    
    return maps.map((map) => {
      'id': map['id'],
      'song_id': map['song_id'],
      'song_type': map['song_type'],
      'created_at': map['created_at'],
    }).toList();
  }
  
  /// Soft delete a song from category
  Future<void> softDeleteCategorySong(int categoryId, int songId, String songType) async {
    final db = await database;
    await db.update(
      _categorySongsTable,
      {
        'deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'category_id = ? AND song_id = ? AND song_type = ?',
      whereArgs: [categoryId, songId, songType],
    );
  }
  
  /// Get count of categories
  Future<int> getCategoryCount({String? userId}) async {
    final db = await database;
    if (userId != null) {
      return Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $_categoriesTable WHERE user_id = ? AND deleted = 0',
          [userId]
        )
      ) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_categoriesTable WHERE deleted = 0')
    ) ?? 0;
  }
  
  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

