import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:hymns_latest/models/christmas_carol.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// SQLite database helper for storing Christmas carols locally
/// This ensures carols are available offline (except PDFs which require internet)
class ChristmasCarolsDB {
  static const String _dbName = 'christmas_carols.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'carols';

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
      debugPrint('ChristmasCarolsDB: Initializing database at: $path');

      final db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      debugPrint('ChristmasCarolsDB: Database initialized successfully');
      return db;
    } catch (e, stackTrace) {
      debugPrint('ChristmasCarolsDB: Error initializing database: $e');
      debugPrint('ChristmasCarolsDB: Stack trace: $stackTrace');
      // Don't rethrow - return a minimal in-memory database instead
      try {
        return await openDatabase(
          ':memory:',
          version: _dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
      } catch (e2) {
        debugPrint(
            'ChristmasCarolsDB: Failed to create in-memory database: $e2');
        // Last resort: rethrow the original error
        rethrow;
      }
    }
  }

  /// Create the database schema
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        song_number TEXT,
        church_name TEXT NOT NULL,
        lyrics TEXT,
        pdf TEXT,
        pdf_pages TEXT,
        transpose INTEGER DEFAULT 0,
        scale TEXT DEFAULT 'C Major',
        has_chords INTEGER DEFAULT 1,
        created_by_user_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Create index for faster queries
    await db
        .execute('CREATE INDEX idx_church_name ON $_tableName(church_name)');
    await db
        .execute('CREATE INDEX idx_created_at ON $_tableName(created_at DESC)');
  }

  /// Handle database upgrades
  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // Handle future schema changes here
    if (oldVersion < 2) {
      // Example: Add new columns in future versions
    }
  }

  /// Insert or replace a carol (upsert)
  Future<void> upsertCarol(ChristmasCarol carol) async {
    final db = await database;
    await db.insert(
      _tableName,
      _carolToMap(carol),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert or replace multiple carols
  Future<void> upsertCarols(List<ChristmasCarol> carols) async {
    if (carols.isEmpty) return;

    try {
      final db = await database;
      final batch = db.batch();

      for (final carol in carols) {
        try {
          batch.insert(
            _tableName,
            _carolToMap(carol),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (e) {
          debugPrint(
              'ChristmasCarolsDB: Error inserting carol ${carol.id}: $e');
          rethrow;
        }
      }

      await batch.commit(noResult: true);
      debugPrint(
          'ChristmasCarolsDB: Successfully saved ${carols.length} carols to database');
    } catch (e) {
      debugPrint('ChristmasCarolsDB: Error saving carols: $e');
      rethrow;
    }
  }

  /// Get all carols from local database
  Future<List<ChristmasCarol>> getAllCarols() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        orderBy: 'created_at DESC',
      );

      final carols = maps.map((map) {
        try {
          return _mapToCarol(map);
        } catch (e) {
          debugPrint('ChristmasCarolsDB: Error parsing carol from DB: $e');
          debugPrint('ChristmasCarolsDB: Map data: $map');
          rethrow;
        }
      }).toList();

      debugPrint(
          'ChristmasCarolsDB: Loaded ${carols.length} carols from database');
      return carols;
    } catch (e) {
      debugPrint('ChristmasCarolsDB: Error loading carols: $e');
      rethrow;
    }
  }

  /// Get carols by church name
  Future<List<ChristmasCarol>> getCarolsByChurch(String churchName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'church_name = ?',
      whereArgs: [churchName],
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => _mapToCarol(map)).toList();
  }

  /// Get a single carol by ID
  Future<ChristmasCarol?> getCarolById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return _mapToCarol(maps.first);
  }

  /// Delete a carol by ID
  Future<void> deleteCarol(String id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all carols for a church
  Future<void> deleteCarolsByChurch(String churchName) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'church_name = ?',
      whereArgs: [churchName],
    );
  }

  /// Delete all carols
  Future<void> deleteAllCarols() async {
    final db = await database;
    await db.delete(_tableName);
  }

  /// Get count of carols
  Future<int> getCarolCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_tableName')) ??
        0;
  }

  /// Get all unique church names
  Future<List<String>> getAllChurches() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT DISTINCT church_name FROM $_tableName ORDER BY church_name');

    return maps.map((map) => map['church_name'] as String).toList();
  }

  /// Convert ChristmasCarol to Map for database storage
  Map<String, dynamic> _carolToMap(ChristmasCarol carol) {
    return {
      'id': carol.id,
      'title': carol.title,
      'song_number': carol.songNumber,
      'church_name': carol.churchName,
      'lyrics': carol.lyrics,
      'pdf': carol.pdfPath,
      'pdf_pages': carol.pdfPages != null ? jsonEncode(carol.pdfPages) : null,
      'transpose': carol.transpose,
      'scale': carol.scale,
      'has_chords': carol.hasChords ? 1 : 0,
      'created_by_user_id': carol.createdByUserId,
      'created_at': carol.createdAt.toIso8601String(),
      'updated_at': carol.updatedAt?.toIso8601String(),
    };
  }

  /// Convert Map from database to ChristmasCarol
  ChristmasCarol _mapToCarol(Map<String, dynamic> map) {
    return ChristmasCarol(
      id: map['id'] as String,
      title: map['title'] as String,
      songNumber: map['song_number'] as String?,
      churchName: map['church_name'] as String,
      lyrics: map['lyrics'] as String?,
      pdfPath: map['pdf'] as String?,
      pdfPages: map['pdf_pages'] != null
          ? List<String>.from(jsonDecode(map['pdf_pages'] as String))
          : null,
      transpose: (map['transpose'] as int?) ?? 0,
      scale: map['scale'] as String? ?? 'C Major',
      hasChords: (map['has_chords'] as int? ?? 1) == 1,
      createdByUserId: map['created_by_user_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
