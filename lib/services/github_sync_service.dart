import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hymns_latest/models/christmas_carol.dart';
import 'package:flutter/foundation.dart';

/// Service for syncing Christmas carols with GitHub repository
///
/// This service allows you to:
/// - Push carols data to a GitHub repository
/// - Pull carols data from a GitHub repository
/// - Keep local and remote data in sync
class GitHubSyncService {
  static const String _githubTokenKey = 'github_token';
  static const String _githubRepoKey = 'github_repo';
  static const String _githubFilePathKey = 'github_file_path';

  // Default values (can be configured)
  static const String _defaultRepo = 'Reynold29/csi-hymns-vault';
  static const String _defaultFilePath = 'carols_data.json';

  /// Sets GitHub authentication token
  Future<void> setGitHubToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_githubTokenKey, token);
  }

  /// Gets GitHub authentication token
  Future<String?> getGitHubToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_githubTokenKey);
  }

  /// Sets GitHub repository (format: owner/repo)
  Future<void> setGitHubRepo(String repo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_githubRepoKey, repo);
  }

  /// Gets GitHub repository
  Future<String> getGitHubRepo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_githubRepoKey) ?? _defaultRepo;
  }

  /// Sets file path in repository
  Future<void> setFilePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_githubFilePathKey, path);
  }

  /// Gets file path in repository
  Future<String> getFilePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_githubFilePathKey) ?? _defaultFilePath;
  }

  /// Pushes carols data to GitHub
  ///
  /// Returns true if successful, false otherwise
  Future<bool> pushToGitHub(List<ChristmasCarol> carols) async {
    try {
      final token = await getGitHubToken();
      if (token == null || token.isEmpty) {
        debugPrint('GitHubSyncService: No GitHub token configured');
        return false;
      }

      final repo = await getGitHubRepo();
      final filePath = await getFilePath();

      // Convert carols to JSON
      final jsonData = jsonEncode(carols.map((c) => c.toJson()).toList());
      final base64Content = base64Encode(utf8.encode(jsonData));

      // Check if file exists
      final existingFile = await _getFileContent(repo, filePath, token);

      // Prepare request
      final url = 'https://api.github.com/repos/$repo/contents/$filePath';
      final headers = {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      };

      final body = {
        'message': 'Update carols data - ${DateTime.now().toIso8601String()}',
        'content': base64Content,
      };

      // If file exists, include SHA for update
      if (existingFile != null) {
        body['sha'] = existingFile['sha'] as String;
      }

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('GitHubSyncService: Successfully pushed to GitHub');
        return true;
      } else {
        debugPrint(
            'GitHubSyncService: Failed to push - ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('GitHubSyncService: Error pushing to GitHub: $e');
      return false;
    }
  }

  /// Gets file content from GitHub
  Future<Map<String, dynamic>?> _getFileContent(
      String repo, String filePath, String token) async {
    try {
      final url = 'https://api.github.com/repos/$repo/contents/$filePath';
      final headers = {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
      };

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        // File doesn't exist yet
        return null;
      } else {
        debugPrint(
            'GitHubSyncService: Failed to get file - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('GitHubSyncService: Error getting file: $e');
      return null;
    }
  }

  /// Pulls carols data from GitHub
  ///
  /// Returns list of carols or null if failed
  Future<List<ChristmasCarol>?> pullFromGitHub() async {
    try {
      final token = await getGitHubToken();
      if (token == null || token.isEmpty) {
        debugPrint('GitHubSyncService: No GitHub token configured');
        return null;
      }

      final repo = await getGitHubRepo();
      final filePath = await getFilePath();

      final fileContent = await _getFileContent(repo, filePath, token);

      if (fileContent == null) {
        debugPrint('GitHubSyncService: File not found on GitHub');
        return [];
      }

      // Decode base64 content
      final content = fileContent['content'] as String;
      final decodedContent =
          utf8.decode(base64Decode(content.replaceAll('\n', '')));

      // Parse JSON
      final List<dynamic> data = jsonDecode(decodedContent);
      return data
          .map((item) => ChristmasCarol.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('GitHubSyncService: Error pulling from GitHub: $e');
      return null;
    }
  }

  /// Syncs carols: pushes local data to GitHub
  ///
  /// This should be called after adding/updating/deleting carols
  Future<bool> syncToGitHub(List<ChristmasCarol> carols) async {
    return await pushToGitHub(carols);
  }
}
