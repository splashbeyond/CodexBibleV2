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
  static const int _maxChunkLength = 250; // Maximum characters per chunk

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

  List<String> _splitTextIntoChunks(String text) {
    List<String> chunks = [];

    // Split the text at sentence boundaries
    List<String> sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    String currentChunk = '';

    for (String sentence in sentences) {
      // If adding this sentence would exceed the chunk size, save current chunk and start new one
      if (currentChunk.length + sentence.length > _maxChunkLength && currentChunk.isNotEmpty) {
        chunks.add(currentChunk.trim());
        currentChunk = '';
      }

      // If a single sentence is longer than max chunk size, split it by commas or other natural breaks
      if (sentence.length > _maxChunkLength) {
        List<String> subParts = sentence.split(RegExp(r'(?<=[,;])\s+'));
        for (String part in subParts) {
          if (part.length > _maxChunkLength) {
            // If still too long, split by spaces while preserving words
            List<String> words = part.split(' ');
            String subChunk = '';
            for (String word in words) {
              if (subChunk.length + word.length + 1 > _maxChunkLength) {
                chunks.add(subChunk.trim());
                subChunk = '';
              }
              subChunk += '${subChunk.isEmpty ? '' : ' '}$word';
            }
            if (subChunk.isNotEmpty) {
              chunks.add(subChunk.trim());
            }
          } else {
            if (currentChunk.length + part.length > _maxChunkLength) {
              chunks.add(currentChunk.trim());
              currentChunk = part;
            } else {
              currentChunk += '${currentChunk.isEmpty ? '' : ' '}$part';
            }
          }
        }
      } else {
        currentChunk += '${currentChunk.isEmpty ? '' : ' '}$sentence';
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.trim());
    }

    return chunks;
  }

  Future<String> generateChapterAudio(List<String> verses, String voiceId) async {
    if (verses.isEmpty) {
      throw Exception('No text provided for audio generation');
    }

    try {
      final text = verses[0];
      final chunks = _splitTextIntoChunks(text);
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final List<String> audioFiles = [];

      // Generate audio for each chunk
      for (int i = 0; i < chunks.length; i++) {
        final response = await http.post(
          Uri.parse('$baseUrl/text-to-speech/$voiceId'),
          headers: {
            'xi-api-key': _apiKey,
            'Content-Type': 'application/json',
            'accept': 'audio/mpeg',
          },
          body: json.encode({
            'text': chunks[i],
            'model_id': 'eleven_monolingual_v1',
            'voice_settings': {
              'stability': 0.3,
              'similarity_boost': 0.3,
              'use_speaker_boost': false
            },
          }),
        );

        if (response.statusCode == 200) {
          final file = File('${directory.path}/verse_${timestamp}_part$i.mp3');
          await file.writeAsBytes(response.bodyBytes);
          audioFiles.add(file.path);
        } else {
          throw Exception('Failed to generate audio for chunk $i: ${response.statusCode}');
        }
      }

      // If we have multiple chunks, concatenate them
      if (audioFiles.length > 1) {
        final outputFile = File('${directory.path}/verse_$timestamp.mp3');
        List<int> combinedBytes = [];

        for (String filePath in audioFiles) {
          final file = File(filePath);
          combinedBytes.addAll(await file.readAsBytes());
          await file.delete(); // Clean up temporary chunk files
        }

        await outputFile.writeAsBytes(combinedBytes);
        return outputFile.path;
      } else if (audioFiles.length == 1) {
        return audioFiles[0];
      } else {
        throw Exception('No audio files generated');
      }
    } catch (e) {
      print('Error in generateChapterAudio: $e');
      throw Exception('Failed to generate audio: $e');
    }
  }
}

