import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'dart:convert';
import '../constants/bible_data.dart';

class ASVAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  String? _currentBook;
  int? _currentChapter;
  List<String> _currentVerses = [];
  Duration _totalDuration = Duration.zero;
  double _currentPosition = 0.0;

  // Define which books belong to which testament
  final Set<String> newTestamentBooks = {
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
    '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
    'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
    'Jude', 'Revelation'
  };

  // Map of book names to their numbers
  final Map<String, String> _bookNumbers = {
    // Old Testament
    'Genesis': '01', 'Exodus': '02', 'Leviticus': '03', 'Numbers': '04', 'Deuteronomy': '05',
    'Joshua': '06', 'Judges': '07', 'Ruth': '08', '1 Samuel': '09', '2 Samuel': '10',
    '1 Kings': '11', '2 Kings': '12', '1 Chronicles': '13', '2 Chronicles': '14', 'Ezra': '15',
    'Nehemiah': '16', 'Esther': '17', 'Job': '18', 'Psalms': '19', 'Proverbs': '20',
    'Ecclesiastes': '21', 'Song of Solomon': '22', 'Isaiah': '23', 'Jeremiah': '24', 'Lamentations': '25',
    'Ezekiel': '26', 'Daniel': '27', 'Hosea': '28', 'Joel': '29', 'Amos': '30',
    'Obadiah': '31', 'Jonah': '32', 'Micah': '33', 'Nahum': '34', 'Habakkuk': '35',
    'Zephaniah': '36', 'Haggai': '37', 'Zechariah': '38', 'Malachi': '39',
    // New Testament
    'Matthew': '40', 'Mark': '41', 'Luke': '42', 'John': '43', 'Acts': '44',
    'Romans': '45', '1 Corinthians': '46', '2 Corinthians': '47', 'Galatians': '48', 'Ephesians': '49',
    'Philippians': '50', 'Colossians': '51', '1 Thessalonians': '52', '2 Thessalonians': '53', '1 Timothy': '54',
    '2 Timothy': '55', 'Titus': '56', 'Philemon': '57', 'Hebrews': '58', 'James': '59',
    '1 Peter': '60', '2 Peter': '61', '1 John': '62', '2 John': '63', '3 John': '64',
    'Jude': '65', 'Revelation': '66'
  };

  String _getTestament(String book) {
    return newTestamentBooks.contains(book) ? 'New Testament' : 'Old Testament';
  }

  bool get isPlaying => _isPlaying;

  double get currentPosition => _currentPosition;

  ASVAudioService() {
    _setupAudioPlayer();
  }

  Future<void> _setupAudioPlayer() async {
    try {
      print('ASVAudioService: Setting up audio player');
      
      // Configure audio player for voice playback
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      
      // Set up audio context for voice playback
      await _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: [
            AVAudioSessionOptions.mixWithOthers,  // Allow mixing with other audio
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.defaultToSpeaker
          ]
        )
      ));

      // Listen for position updates
      _audioPlayer.onPositionChanged.listen((Duration position) {
        _currentPosition = position.inMilliseconds / 1000.0;
      });

      // Listen for state changes
      _audioPlayer.onPlayerStateChanged.listen((PlayerState state) async {
        print('Player state changed to: $state');
        
        if (state == PlayerState.playing) {
          _isPlaying = true;
        } else if (state == PlayerState.completed) {
          print('ASVAudioService: Playback completed');
          _currentPosition = 0.0;
          _isPlaying = false;
          await _handlePlaybackCompletion();
          // After handling completion, start playing the next chapter if available
          if (_currentBook != null && _currentChapter != null) {
            await play();
          }
        } else if (state == PlayerState.stopped || state == PlayerState.paused) {
          _isPlaying = false;
        }
      });

      print('ASVAudioService: Audio player setup completed successfully');
    } catch (e, stackTrace) {
      print('ASVAudioService: Error setting up audio player: $e');
      print('ASVAudioService: Stack trace: $stackTrace');
    }
  }

  Future<void> _handlePlaybackCompletion() async {
    print('ASVAudioService: Handling playback completion');
    try {
      if (_currentBook != null && _currentChapter != null) {
        // Get the maximum chapters for the current book
        final maxChapters = BibleData.books[_currentBook] ?? 1;
        
        if (_currentChapter! < maxChapters) {
          // Move to next chapter
          print('ASVAudioService: Moving to next chapter: ${_currentChapter! + 1}');
          _currentChapter = _currentChapter! + 1;
          if (_onChapterChangeCallback != null) {
            print('ASVAudioService: Notifying chapter change: $_currentBook $_currentChapter');
            await stop(); // Ensure clean state before callback
            await Future.delayed(const Duration(milliseconds: 500)); // Add delay before callback
            await _onChapterChangeCallback!(_currentBook!, _currentChapter!);
            // Start playing the new chapter automatically
            await Future.delayed(const Duration(milliseconds: 500)); // Add delay before playing
            await play();
          }
        } else {
          // Find the next book
          final booksList = BibleData.books.keys.toList();
          final currentIndex = booksList.indexOf(_currentBook!);
          if (currentIndex < booksList.length - 1) {
            final nextBook = booksList[currentIndex + 1];
            print('ASVAudioService: Moving to next book: $nextBook chapter 1');
            _currentBook = nextBook;
            _currentChapter = 1;
            if (_onChapterChangeCallback != null) {
              print('ASVAudioService: Notifying chapter change: $_currentBook $_currentChapter');
              await stop(); // Ensure clean state before callback
              await Future.delayed(const Duration(milliseconds: 500)); // Add delay before callback
              await _onChapterChangeCallback!(_currentBook!, _currentChapter!);
              // Start playing the new chapter automatically
              await Future.delayed(const Duration(milliseconds: 500)); // Add delay before playing
              await play();
            }
          } else {
            print('ASVAudioService: Reached end of Bible, stopping playback');
            await stop();
          }
        }
      }
    } catch (e, stackTrace) {
      print('ASVAudioService: Error in _handlePlaybackCompletion: $e');
      print('ASVAudioService: Stack trace: $stackTrace');
      // Reset state on error
      _isPlaying = false;
      _currentPosition = 0.0;
    }
  }

  Future<void> setPassage(String book, int chapter, List<String> verses, {bool maintainState = false}) async {
    print('ASVAudioService: Setting passage to $book chapter $chapter (maintainState: $maintainState)');
    bool wasPlaying = _isPlaying;
    
    try {
      // Store current state before changing passage
      _currentBook = book;
      _currentChapter = chapter;
      _currentVerses = verses;

      // If we should maintain state and audio was playing, or if we're just switching chapters
      if (wasPlaying && (maintainState || _isPlaying)) {
        print('ASVAudioService: Audio was playing, continuing playback with new chapter');
        await _playCurrentChapter();
        _isPlaying = true;
      }
    } catch (e, stackTrace) {
      print('ASVAudioService: Error in setPassage: $e');
      print('ASVAudioService: Stack trace: $stackTrace');
      if (!maintainState) {
        _isPlaying = false;
      }
    }
  }

  Future<String?> _findAudioAssetForChapter(String book, int chapter) async {
    try {
      final testament = _getTestament(book);
      print('ASVAudioService: Testament path: $testament');
      
      // Get the book number based on the actual file naming
      String bookNumber;
      if (book == '1 Thessalonians') {
        bookNumber = '52';
      } else if (book == '2 Thessalonians') {
        bookNumber = '53';
      } else {
        final number = _bookNumbers[book];
        if (number == null) {
          print('ASVAudioService: Book number not found for: $book');
          return null;
        }
        bookNumber = number;
      }

      print('ASVAudioService: Looking for audio file with book number: $bookNumber');

      // Format chapter number with leading zero if needed
      String chapterStr = chapter.toString().padLeft(2, '0');
      
      // Special cases for single-chapter books
      if (book == 'Obadiah' || book == 'Philemon' || book == 'Jude' || 
          book == '2 John' || book == '3 John') {
        String bookInPath = book;
        if (book == '2 John') {
          bookInPath = '2John';
        } else if (book == '3 John') {
          bookInPath = '3John';
        }
        final fileName = '${bookNumber}_${bookInPath.replaceAll(' ', '')}.mp3';
        final path = 'CodexASVBible/$testament/$fileName';
        print('ASVAudioService: Trying single-chapter book path: $path');
        return path;
      }

      // Handle special book name abbreviations
      String bookInPath = book;
      if (book == 'Galatians') {
        bookInPath = 'Gal';
      } else if (book == '1 John') {
        bookInPath = '1John';
      } else if (book == '1 Samuel') {
        bookInPath = '1Samuel';
      } else if (book == '2 Samuel') {
        bookInPath = '2Samuel';
      } else if (book == '1 Kings') {
        bookInPath = '1Kings';
      } else if (book == '2 Kings') {
        bookInPath = '2Kings';
      } else if (book == '1 Chronicles') {
        bookInPath = '1Chronicles';
      } else if (book == '2 Chronicles') {
        bookInPath = '2Chronicles';
      } else if (book == 'Lamentations') {
        bookInPath = 'Lam';
      } else if (book == 'Proverbs') {
        bookInPath = 'Prov';
      } else if (book == 'Psalms') {
        bookInPath = 'Psalm';
        chapterStr = chapter.toString().padLeft(3, '0');
      } else if (book == 'Matthew') {
        bookInPath = 'Matt';  // Add special case for Matthew
      }
      
      // Remove spaces from book name
      bookInPath = bookInPath.replaceAll(' ', '');

      // Regular multi-chapter books
      final fileName = '${bookNumber}_${bookInPath}_$chapterStr.mp3';
      final path = 'CodexASVBible/$testament/$fileName';
      print('ASVAudioService: Trying path: $path');

      try {
        final manifestContent = await rootBundle.loadString('AssetManifest.json');
        final Map<String, dynamic> manifest = Map<String, dynamic>.from(
          await json.decode(manifestContent) as Map,
        );

        final fullPath = 'assets/$path';
        print('ASVAudioService: Checking manifest for: $fullPath');
        
        if (manifest.containsKey(fullPath)) {
          print('ASVAudioService: Found audio file at: $fullPath');
          return path;
        }

        print('ASVAudioService: Audio file not found in manifest. Available audio files:');
        manifest.keys.where((key) => key.endsWith('.mp3') && key.contains(bookNumber)).forEach((key) {
          print('- $key');
        });

        return null;
      } catch (e) {
        print('ASVAudioService: Error checking manifest: $e');
        return null;
      }
    } catch (e, stackTrace) {
      print('ASVAudioService: Error finding audio file: $e');
      print('ASVAudioService: Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> play() async {
    try {
      print('ASVAudioService: Attempting to play audio for $_currentBook chapter $_currentChapter');
      if (_currentBook == null || _currentChapter == null) {
        print('ASVAudioService: No current book or chapter set');
        return;
      }

      final audioAsset = await _findAudioAssetForChapter(_currentBook!, _currentChapter!);
      if (audioAsset == null) {
        print('ASVAudioService: No audio file found for $_currentBook chapter $_currentChapter');
        // Try to advance to next chapter if current one fails
        await _handlePlaybackCompletion();
        return;
      }

      print('ASVAudioService: Loading audio file: $audioAsset');
      await _audioPlayer.play(AssetSource(audioAsset));
      _isPlaying = true;
      print('ASVAudioService: Playback started successfully');
    } catch (e, stackTrace) {
      print('ASVAudioService: Error in play(): $e');
      print('ASVAudioService: Stack trace: $stackTrace');
      _isPlaying = false;
      // Try to advance to next chapter if current one fails
      await _handlePlaybackCompletion();
    }
  }

  Future<void> _playCurrentChapter() async {
    try {
      print('ASVAudioService: Finding audio asset for chapter');
      final audioAsset = await _findAudioAssetForChapter(_currentBook!, _currentChapter!);
      
      if (audioAsset == null) {
        print('ASVAudioService: No audio file found for $_currentBook chapter $_currentChapter');
        throw Exception('Audio file not found');
      }
      
      print('ASVAudioService: Found audio asset: $audioAsset');
      
      // Set up playback parameters
      await _audioPlayer.setPlaybackRate(_playbackSpeed);
      print('ASVAudioService: Set playback rate to $_playbackSpeed');
      
      // Create the source and start playback
      final source = AssetSource(audioAsset);
      print('ASVAudioService: Created AssetSource, attempting to play');
      
      // Attempt to play the audio
      await _audioPlayer.play(source);
      print('ASVAudioService: Successfully started playback');
      
      // Set up duration listener
      _audioPlayer.onDurationChanged.listen((Duration duration) {
        print('ASVAudioService: Audio duration: $duration');
        _totalDuration = duration;
      });
      
    } catch (e, stackTrace) {
      print('ASVAudioService: Error in _playCurrentChapter(): $e');
      print('ASVAudioService: Stack trace: $stackTrace');
      _isPlaying = false;
      await stop();
      rethrow;
    }
  }

  Future<void> pause() async {
    print('ASVAudioService: Pausing playback');
    _isPlaying = false;
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    print('ASVAudioService: Resuming playback');
    await _audioPlayer.resume();
    _isPlaying = true;
  }

  Future<void> stop() async {
    print('ASVAudioService: Stopping playback');
    await _audioPlayer.stop();
    _isPlaying = false;
    _currentPosition = 0.0;
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    _audioPlayer.setPlaybackRate(speed);
  }

  Future<void> restart() async {
    if (_isPlaying) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.resume();
    }
  }

  Future<void> dispose() async {
    // Don't dispose of the audio player, just stop it
    await stop();
  }

  Future<bool> areAudioFilesExtracted() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = Map<String, dynamic>.from(
        await json.decode(manifestContent) as Map,
      );
      
      final hasFiles = manifest.keys.any((key) => 
        key.startsWith('assets/CodexASVBible/') && 
        key.endsWith('.mp3')
      );
      
      print('Checking audio files. Found files: $hasFiles');
      if (!hasFiles) {
        print('Available assets: ${manifest.keys.join('\n')}');
      }
      
      return hasFiles;
    } catch (e) {
      print('Error checking audio files: $e');
      return false;
    }
  }

  // Callback for chapter changes
  Function(String book, int chapter)? _onChapterChangeCallback;

  void setOnChapterChangeCallback(Function(String book, int chapter) callback) {
    _onChapterChangeCallback = callback;
  }
} 