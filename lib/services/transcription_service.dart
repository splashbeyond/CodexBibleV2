import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:path/path.dart' as path;

class TranscriptionService {
  final StreamController<List<TranscriptionResult>> _transcriptionController = 
      StreamController<List<TranscriptionResult>>.broadcast();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  
  Stream<List<TranscriptionResult>> get transcriptionStream => _transcriptionController.stream;

  Future<void> transcribeAudioAsset(String assetPath) async {
    try {
      // 1. Get the audio file from assets
      final audioBytes = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      
      // 2. Save the audio file temporarily
      final originalAudioPath = path.join(tempDir.path, 'original_audio.mp3');
      final wavAudioPath = path.join(tempDir.path, 'audio_for_transcription.wav');
      
      File(originalAudioPath).writeAsBytesSync(audioBytes.buffer.asUint8List());

      // 3. Convert MP3 to WAV (required format for speech recognition)
      await FFmpegKit.execute(
        '-i $originalAudioPath -acodec pcm_s16le -ac 1 -ar 16000 $wavAudioPath'
      );

      // 4. Initialize speech recognition
      final available = await _speechToText.initialize(
        onError: (error) => print('Speech recognition error: $error'),
        onStatus: (status) => print('Speech recognition status: $status'),
      );

      if (!available) {
        throw Exception('Speech recognition not available');
      }

      // 5. Start listening to the audio file
      final results = <TranscriptionResult>[];
      var currentTime = 0.0;
      const wordsPerSecond = 2.5; // Estimated average speaking rate

      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            // Add words with estimated timings
            final words = result.recognizedWords.split(' ');
            for (var word in words) {
              results.add(TranscriptionResult(
                word: word,
                startTime: currentTime,
                endTime: currentTime + (1 / wordsPerSecond),
              ));
              currentTime += (1 / wordsPerSecond);
            }
            _transcriptionController.add(List.from(results));
          }
        },
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      );

      // 6. Clean up temporary files
      await Future.delayed(const Duration(seconds: 1));
      await _speechToText.stop();
      await File(originalAudioPath).delete();
      await File(wavAudioPath).delete();

    } catch (e) {
      print('Error during transcription: $e');
      _transcriptionController.addError(e);
    }
  }

  void dispose() {
    _speechToText.stop();
    _transcriptionController.close();
  }
}

class TranscriptionResult {
  final String word;
  final double startTime;
  final double endTime;

  TranscriptionResult({
    required this.word,
    required this.startTime,
    required this.endTime,
  });
} 