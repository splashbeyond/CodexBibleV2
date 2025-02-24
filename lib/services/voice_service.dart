import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
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

  VoiceService() {
    _apiKey = dotenv.env['ELEVENLABS_API_KEY'] ?? '';
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

  Future<String> generateChapterAudio(List<String> verses, String voiceId) async {
    if (verses.isEmpty) {
      throw Exception('No text provided for audio generation');
    }

    try {
      // Process single verse
      final text = verses[0];

      final response = await http.post(
        Uri.parse('$baseUrl/text-to-speech/$voiceId'),
        headers: {
          'xi-api-key': _apiKey,
          'Content-Type': 'application/json',
          'accept': 'audio/mpeg',
        },
        body: json.encode({
          'text': text,
          'model_id': 'eleven_monolingual_v1',
          'voice_settings': {
            'stability': 0.3,
            'similarity_boost': 0.3,
            'use_speaker_boost': false
          },
        }),
      );

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${directory.path}/verse_$timestamp.mp3');

        try {
          await file.writeAsBytes(response.bodyBytes);
          return file.path;
        } catch (e) {
          print('Error writing audio file: $e');
          throw Exception('Failed to save audio file: $e');
        }
      } else {
        final errorMsg = 'ElevenLabs API Error: ${response.statusCode} - ${response.body}';
        print(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Error in generateChapterAudio: $e';
      print(errorMsg);
      throw Exception(errorMsg);
    }
  }
}

