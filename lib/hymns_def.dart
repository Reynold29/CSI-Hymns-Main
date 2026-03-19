import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Hymn {
  final int number;
  final String title;
  final String signature;
  final String lyrics;
  final String? kannadaLyrics;

  Hymn({
    required this.number,
    required this.title,
    required this.signature,
    required this.lyrics,
    this.kannadaLyrics,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'title': title,
        'signature': signature,
        'lyrics': lyrics,
        'kannadaLyrics': kannadaLyrics
      };

  factory Hymn.fromJson(Map<String, dynamic> json) => Hymn(
        number: json['number'],
        title: json['title'],
        signature: json['signature'],
        lyrics: json['lyrics'],
        kannadaLyrics: json['kannadaLyrics'],
      );
}

/// Top-level function required by compute() — parses JSON string in a background isolate.
List<Hymn> _parseHymnsJson(String jsonData) {
  final data = jsonDecode(jsonData) as List<dynamic>;
  return data
      .map((item) => Hymn.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<List<Hymn>> loadHymns() async {
  final prefs = await SharedPreferences.getInstance();
  final savedJson = prefs.getString('hymnsData');

  if (savedJson != null) {
    // Parse cached JSON off the main thread
    return compute(_parseHymnsJson, savedJson);
  } else {
    // Load asset and parse off the main thread
    final assetJson = await rootBundle.loadString('lib/assets/hymns_data.json');
    return compute(_parseHymnsJson, assetJson);
  }
}

Future<List<Hymn>> loadHymnsFromNetwork(String jsonData) async {
  return compute(_parseHymnsJson, jsonData);
}
