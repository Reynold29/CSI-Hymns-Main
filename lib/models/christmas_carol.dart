import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a Christmas Carol song entry.
/// 
/// Carols can have either text lyrics or a PDF file (or both).
/// The PDF can be stored locally or uploaded to Supabase storage.
class ChristmasCarol {
  final String id;
  final String title;
  final String? songNumber; // Optional song number for easy searching
  final String churchName;
  final String? lyrics;
  final String? pdfPath; // Path or URL to PDF file
  final List<String>? pdfPages; // Optional pre-rendered page images
  final int transpose;
  final String scale;
  final bool hasChords; // Whether the PDF/lyrics contains chord notation
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChristmasCarol({
    required this.id,
    required this.title,
    this.songNumber,
    required this.churchName,
    this.lyrics,
    this.pdfPath,
    this.pdfPages,
    this.transpose = 0,
    this.scale = 'C Major',
    this.hasChords = true, // Default to true for backward compatibility
    required this.createdByUserId,
    required this.createdAt,
    this.updatedAt,
  });

  /// Creates a ChristmasCarol from JSON data
  factory ChristmasCarol.fromJson(Map<String, dynamic> json) {
    return ChristmasCarol(
      id: json['id'] as String,
      title: json['title'] as String,
      songNumber: json['song_number'] as String?,
      churchName: json['church_name'] as String,
      lyrics: json['lyrics'] as String?,
      pdfPath: json['pdf'] as String?,
      pdfPages: json['pdf_pages'] != null 
          ? List<String>.from(json['pdf_pages'] as List)
          : null,
      transpose: (json['transpose'] as num?)?.toInt() ?? 0,
      scale: json['scale'] as String? ?? 'C Major',
      hasChords: json['has_chords'] as bool? ?? true, // Default to true for backward compatibility
      createdByUserId: json['created_by_user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converts the carol to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'song_number': songNumber,
      'church_name': churchName,
      'lyrics': lyrics,
      'pdf': pdfPath,
      'pdf_pages': pdfPages,
      'transpose': transpose,
      'scale': scale,
      'has_chords': hasChords,
      'created_by_user_id': createdByUserId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Creates a copy with updated fields
  ChristmasCarol copyWith({
    String? id,
    String? title,
    String? songNumber,
    String? churchName,
    String? lyrics,
    String? pdfPath,
    List<String>? pdfPages,
    int? transpose,
    String? scale,
    bool? hasChords,
    String? createdByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChristmasCarol(
      id: id ?? this.id,
      title: title ?? this.title,
      songNumber: songNumber ?? this.songNumber,
      churchName: churchName ?? this.churchName,
      lyrics: lyrics ?? this.lyrics,
      pdfPath: pdfPath ?? this.pdfPath,
      pdfPages: pdfPages ?? this.pdfPages,
      transpose: transpose ?? this.transpose,
      scale: scale ?? this.scale,
      hasChords: hasChords ?? this.hasChords,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Whether this carol has a PDF attached
  bool get hasPdf => pdfPath != null && pdfPath!.isNotEmpty;

  /// Whether this carol has text lyrics
  bool get hasLyrics => lyrics != null && lyrics!.isNotEmpty;

  @override
  String toString() => 'ChristmasCarol(id: $id, title: $title, church: $churchName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChristmasCarol && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// List of common musical scales for the scale picker
class MusicalScales {
  static const List<String> majorScales = [
    'C Major', 'C# Major', 'D Major', 'D# Major', 'E Major', 'F Major',
    'F# Major', 'G Major', 'G# Major', 'A Major', 'A# Major', 'B Major',
  ];

  static const List<String> minorScales = [
    'C Minor', 'C# Minor', 'D Minor', 'D# Minor', 'E Minor', 'F Minor',
    'F# Minor', 'G Minor', 'G# Minor', 'A Minor', 'A# Minor', 'B Minor',
  ];

  static List<String> get allScales => [...majorScales, ...minorScales];
  
  /// Note names in chromatic order
  static const List<String> notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  
  /// Transposes a scale by the given number of semitones
  static String transposeScale(String scale, int semitones) {
    // Parse the scale
    final isMajor = scale.contains('Major');
    final suffix = isMajor ? ' Major' : ' Minor';
    final notePart = scale.replaceAll(' Major', '').replaceAll(' Minor', '');
    
    // Find current note index
    int noteIndex = notes.indexOf(notePart);
    if (noteIndex == -1) return scale; // Unknown scale
    
    // Transpose
    noteIndex = (noteIndex + semitones) % 12;
    if (noteIndex < 0) noteIndex += 12;
    
    return notes[noteIndex] + suffix;
  }
  
  /// Gets the original scale before transpose was applied
  static String getOriginalScale(String currentScale, int transpose) {
    // To get original, we reverse the transpose
    return transposeScale(currentScale, -transpose);
  }
}

/// Loads Christmas carols from local JSON asset
Future<List<ChristmasCarol>> loadChristmasCarolsFromAsset() async {
  try {
    final String jsonData = await rootBundle.loadString('lib/assets/data/christmas_carols.json');
    final data = jsonDecode(jsonData) as List<dynamic>;
    return data.map((item) => ChristmasCarol.fromJson(item as Map<String, dynamic>)).toList();
  } catch (e) {
    // Return empty list if file doesn't exist yet
    return [];
  }
}

/// Loads Christmas carols from SharedPreferences (user-added carols)
Future<List<ChristmasCarol>> loadChristmasCarolsFromLocal() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString('christmas_carols_data');
    if (jsonData == null || jsonData.isEmpty) return [];
    
    final data = jsonDecode(jsonData) as List<dynamic>;
    return data.map((item) => ChristmasCarol.fromJson(item as Map<String, dynamic>)).toList();
  } catch (e) {
    return [];
  }
}

/// Saves Christmas carols to SharedPreferences
Future<void> saveChristmasCarolsToLocal(List<ChristmasCarol> carols) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(carols.map((c) => c.toJson()).toList());
    await prefs.setString('christmas_carols_data', jsonData);
  } catch (e) {
    rethrow;
  }
}

