import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';

class Voice {
  final String id;
  final String name;

  Voice({
    required this.id,
    required this.name,
  });

  factory Voice.fromJson(Map<String, dynamic> json) {
    return Voice(
      id: json['voice_id'],
      name: json['name'],
    );
  }
}

class VoiceService {
  final String baseUrl = 'https://api.elevenlabs.io/v1';
  late final String _apiKey;
  static const int _optimalChunkLength = 400; // Increased for fewer API calls
  final Map<String, String> _audioCache = {};
  static const int _maxCacheSize = 100; // Maximum number of cached audio files

  VoiceService() {
    _apiKey = dotenv.env['ELEVENLABS_API_KEY'] ?? '';
    _initializeCache();
  }

  Future<void> _initializeCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audio_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create();
      }
    } catch (e) {
      print('Error initializing cache: $e');
    }
  }

  Future<List<Voice>> getVoices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/voices'),
        headers: {
          'xi-api-key': _apiKey,
          'accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['voices'] as List).map((voice) => Voice.fromJson(voice)).toList();
      } else {
        throw Exception('Failed to load voices: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load voices: $e');
    }
  }

  String _generateCacheKey(String text, String voiceId) {
    final bytes = utf8.encode(text + voiceId);
    return sha256.convert(bytes).toString();
  }

  Future<String?> _getCachedAudio(String text, String voiceId) async {
    try {
      final cacheKey = _generateCacheKey(text, voiceId);
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/audio_cache/$cacheKey.mp3';
      final file = File(filePath);

      if (await file.exists()) {
        print('Cache hit: Using cached audio for text chunk');
        return filePath;
      }
    } catch (e) {
      print('Error checking cache: $e');
    }
    return null;
  }

  Future<void> _cacheAudio(String text, String voiceId, List<int> audioData) async {
    try {
      final cacheKey = _generateCacheKey(text, voiceId);
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/audio_cache/$cacheKey.mp3';
      final file = File(filePath);
      await file.writeAsBytes(audioData);

      // Manage cache size
      if (_audioCache.length >= _maxCacheSize) {
        final oldestKey = _audioCache.keys.first;
        final oldestFile = File(_audioCache[oldestKey]!);
        if (await oldestFile.exists()) {
          await oldestFile.delete();
        }
        _audioCache.remove(oldestKey);
      }

      _audioCache[cacheKey] = filePath;
      print('Cached audio for text chunk');
    } catch (e) {
      print('Error caching audio: $e');
    }
  }

  String _optimizeText(String text) {
    return text
        .trim()
        // Remove extra whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        // Remove redundant punctuation
        .replaceAll(RegExp(r'[.]{2,}'), '.')
        .replaceAll(RegExp(r'[,]{2,}'), ',')
        .replaceAll(RegExp(r'[!]{2,}'), '!')
        .replaceAll(RegExp(r'[?]{2,}'), '?')
        // Remove unnecessary parentheses and brackets
        .replaceAll(RegExp(r'[\(\)\[\]]'), '')
        // Normalize quotes
        .replaceAll('"', '"')
        .replaceAll('"', '"')
        .replaceAll(''', "'")
        .replaceAll(''', "'")
        // Remove other special characters
        .replaceAll(RegExp(r'[*#@~]'), '')
        .trim();
  }

  int _countWords(String text) {
    return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  Future<String> generateChapterAudio(List<String> verses, String voiceId) async {
    if (verses.isEmpty) {
      throw Exception('No text provided for audio generation');
    }

    try {
      final text = verses[0];
      final optimizedText = _optimizeText(text);
      final wordCount = _countWords(optimizedText);

      print('Processing verse with $wordCount words: $optimizedText');

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Check cache first
      final cachedPath = await _getCachedAudio(optimizedText, voiceId);
      if (cachedPath != null) {
        print('Using cached audio for verse ($wordCount words)');
        return cachedPath;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/text-to-speech/$voiceId'),
        headers: {
          'xi-api-key': _apiKey,
          'Content-Type': 'application/json',
          'accept': 'audio/mpeg',
        },
        body: json.encode({
          'text': optimizedText,
          'model_id': 'eleven_monolingual_v1',
          'voice_settings': {
            'stability': 0.3,
            'similarity_boost': 0.3,
            'use_speaker_boost': false
          },
        }),
      );

      if (response.statusCode == 200) {
        final file = File('${directory.path}/verse_$timestamp.mp3');
        await file.writeAsBytes(response.bodyBytes);

        // Cache the audio
        await _cacheAudio(optimizedText, voiceId, response.bodyBytes);

        print('Generated audio for verse ($wordCount words)');
        return file.path;
      } else {
        throw Exception('Failed to generate audio: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in generateChapterAudio: $e');
      throw Exception('Failed to generate audio: $e');
    }
  }

  Future<void> clearCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audio_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }
      _audioCache.clear();
      print('Cache cleared successfully');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}

