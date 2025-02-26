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

  ASVAudioService() {
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerComplete.listen((_) async {
      print('Audio playback completed for $_currentBook chapter $_currentChapter');
      if (_currentBook != null && _currentChapter != null) {
        // Get the maximum chapters for the current book
        final maxChapters = BibleData.books[_currentBook] ?? 1;
        
        if (_currentChapter! < maxChapters) {
          // Move to next chapter
          print('Moving to next chapter: ${_currentChapter! + 1}');
          _currentChapter = _currentChapter! + 1;
          // Notify listeners about the chapter change before setting new passage
          if (_onChapterChangeCallback != null) {
            print('Notifying chapter change: $_currentBook $_currentChapter');
            _onChapterChangeCallback!(_currentBook!, _currentChapter!);
          }
          // The HomeScreen will call setPassage when it loads the new chapter
        } else {
          // Find the next book
          final booksList = BibleData.books.keys.toList();
          final currentIndex = booksList.indexOf(_currentBook!);
          if (currentIndex < booksList.length - 1) {
            final nextBook = booksList[currentIndex + 1];
            print('Moving to next book: $nextBook chapter 1');
            _currentBook = nextBook;
            _currentChapter = 1;
            // Notify listeners about the chapter change before setting new passage
            if (_onChapterChangeCallback != null) {
              print('Notifying chapter change: $_currentBook $_currentChapter');
              _onChapterChangeCallback!(_currentBook!, _currentChapter!);
            }
            // The HomeScreen will call setPassage when it loads the new chapter
          } else {
            print('Reached end of Bible, stopping playback');
            await _stop();
          }
        }
      } else {
        print('No current book or chapter set, stopping playback');
        await _stop();
      }
    });

    _audioPlayer.onDurationChanged.listen((Duration duration) {
      _totalDuration = duration;
    });
  }

  Future<void> setPassage(String book, int chapter, List<String> verses) async {
    _currentBook = book;
    _currentChapter = chapter;
    _currentVerses = verses;
  }

  Future<String?> _findAudioAssetForChapter(String book, int chapter) async {
    try {
      final testament = _getTestament(book);
      
      // Get the book number based on the actual file naming
      String bookNumber;
      if (book == '1 Thessalonians') {
        bookNumber = '52';
      } else if (book == '2 Thessalonians') {
        bookNumber = '53';
      } else {
        final number = _bookNumbers[book];
        if (number == null) {
          print('Book number not found for: $book');
          return null;
        }
        bookNumber = number;
      }

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
        print('Trying single-chapter book path: $path');
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
        // Handle Psalms special case - it uses 'Psalm' instead of 'Psalms'
        // and needs three-digit chapter numbers
        bookInPath = 'Psalm';
        chapterStr = chapter.toString().padLeft(3, '0'); // Update chapter string to use 3 digits
      }
      
      // Remove spaces from book name
      bookInPath = bookInPath.replaceAll(' ', '');

      // Regular multi-chapter books
      final fileName = '${bookNumber}_${bookInPath}_$chapterStr.mp3';
      final path = 'CodexASVBible/$testament/$fileName';
      print('Trying path: $path');

      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = Map<String, dynamic>.from(
        await json.decode(manifestContent) as Map,
      );

      final fullPath = 'assets/$path';
      if (manifest.containsKey(fullPath)) {
        print('Found audio file at: $fullPath');
        return path;
      }

      print('Audio file not found. Available audio files:');
      manifest.keys.where((key) => key.endsWith('.mp3')).forEach((key) {
        print('- $key');
      });

      return null;
    } catch (e) {
      print('Error finding audio file: $e');
      return null;
    }
  }

  Future<void> play() async {
    if (_currentVerses.isEmpty || _currentBook == null || _currentChapter == null) {
      print('Cannot play: book or chapter not set');
      return;
    }

    _isPlaying = true;
    await _playCurrentChapter();
  }

  Future<void> _playCurrentChapter() async {
    final audioAsset = await _findAudioAssetForChapter(_currentBook!, _currentChapter!);
    if (audioAsset != null) {
      try {
        print('Playing audio file: $audioAsset');
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
        await _audioPlayer.play(AssetSource(audioAsset));
      } catch (e) {
        print('Error playing audio file: $e');
        await _stop();
      }
    } else {
      print('No audio file found for $_currentBook chapter $_currentChapter');
      await _stop();
    }
  }

  Future<void> pause() async {
    _isPlaying = false;
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    _isPlaying = true;
    await _audioPlayer.resume();
  }

  Future<void> _stop() async {
    _isPlaying = false;
    await _audioPlayer.stop();
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
    await _audioPlayer.dispose();
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