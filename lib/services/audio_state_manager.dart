import 'package:flutter/foundation.dart';
import 'background_music_service.dart';
import 'asv_audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Verse {
  final String text;
  
  Verse({required this.text});
}

class AudioStateManager extends ChangeNotifier {
  static final AudioStateManager _instance = AudioStateManager._internal();
  factory AudioStateManager() => _instance;

  final BackgroundMusicService backgroundMusicService = BackgroundMusicService();
  final ASVAudioService asvAudioService = ASVAudioService();
  bool _isVoiceOverPlaying = false;
  bool _isBackgroundMusicEnabled = true;
  double _backgroundMusicVolume = 0.5;

  String? _currentBook;
  int? _currentChapter;
  bool _isPlaying = false;
  List<Verse> _currentVerses = [];

  AudioStateManager._internal() {
    _initialize();
  }

  bool get isPlaying => _isVoiceOverPlaying;
  bool get isBackgroundMusicEnabled => _isBackgroundMusicEnabled;
  double get backgroundMusicVolume => _backgroundMusicVolume;
  String? get book => _currentBook;
  int? get chapter => _currentChapter;
  double get currentPosition => asvAudioService.currentPosition;

  Future<void> _initialize() async {
    await _loadSettings();
    
    // Set up the ASVAudioService to update playing state when chapter changes
    asvAudioService.setOnChapterChangeCallback((String book, int chapter) {
      _currentBook = book;
      _currentChapter = chapter;
      // Maintain the playing state during chapter changes
      _isVoiceOverPlaying = true;
      notifyListeners();
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isBackgroundMusicEnabled = prefs.getBool('backgroundMusicEnabled') ?? true;
      _backgroundMusicVolume = prefs.getDouble('backgroundMusicVolume') ?? 0.5;
      
      // Initialize background music
      if (_isBackgroundMusicEnabled) {
        await backgroundMusicService.setVolume(_backgroundMusicVolume);
        if (backgroundMusicService.currentSong != null) {
          await backgroundMusicService.resume();
        }
      }
    } catch (e) {
      print('Error loading audio settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('backgroundMusicEnabled', _isBackgroundMusicEnabled);
      await prefs.setDouble('backgroundMusicVolume', _backgroundMusicVolume);
    } catch (e) {
      print('Error saving audio settings: $e');
    }
  }

  Future<void> toggleBackgroundMusic() async {
    try {
      _isBackgroundMusicEnabled = !_isBackgroundMusicEnabled;
      
      if (_isBackgroundMusicEnabled) {
        if (backgroundMusicService.currentSong != null) {
          // Only resume if it was previously playing
          await backgroundMusicService.resume();
        }
      } else {
        await backgroundMusicService.pause();
      }
      
      await _saveSettings();
      notifyListeners();
    } catch (e) {
      print('Error toggling background music: $e');
    }
  }

  Future<void> setBackgroundMusicVolume(double volume) async {
    try {
      _backgroundMusicVolume = volume;
      await backgroundMusicService.setVolume(volume);
      await _saveSettings();
      notifyListeners();
    } catch (e) {
      print('Error setting background music volume: $e');
    }
  }

  Future<void> togglePlayback() async {
    try {
      print('AudioStateManager: Toggling playback. Current state: $_isVoiceOverPlaying');
      if (_isVoiceOverPlaying) {
        print('AudioStateManager: Stopping playback');
        await asvAudioService.stop();
        _isVoiceOverPlaying = false;
      } else {
        print('AudioStateManager: Starting playback');
        if (_currentBook == null || _currentChapter == null) {
          print('AudioStateManager: No current book or chapter set');
          return;
        }
        
        // Ensure we're in a clean state before starting playback
        await asvAudioService.stop();
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Set the current passage and start playing
        await asvAudioService.setPassage(
          _currentBook!,
          _currentChapter!,
          _currentVerses.map((v) => v.text).toList(),
          maintainState: false
        );
        await asvAudioService.play();
        _isVoiceOverPlaying = true;
      }
      notifyListeners();
    } catch (e, stackTrace) {
      print('AudioStateManager: Error in togglePlayback: $e');
      print('AudioStateManager: Stack trace: $stackTrace');
      _isVoiceOverPlaying = false;
      notifyListeners();
    }
  }

  Future<void> stopAll() async {
    try {
      await asvAudioService.pause();
      _isVoiceOverPlaying = false;
      notifyListeners();
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  Future<void> resumeAll() async {
    try {
      await asvAudioService.resume();
      _isVoiceOverPlaying = true;
      notifyListeners();
    } catch (e) {
      print('Error resuming audio: $e');
    }
  }

  Future<void> navigateToPassage(String book, int chapter, List<int> verses) async {
    try {
      print('AudioStateManager: Navigating to passage: $book $chapter');
      // Stop current playback if any
      await asvAudioService.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Update state
      _currentBook = book;
      _currentChapter = chapter;
      _currentVerses = verses.map((e) => Verse(text: e.toString())).toList();
      _isVoiceOverPlaying = false;
      
      // Set the new passage
      await asvAudioService.setPassage(
        book,
        chapter,
        verses.map((e) => e.toString()).toList(),
        maintainState: false
      );
      notifyListeners();
    } catch (e, stackTrace) {
      print('AudioStateManager: Error in navigateToPassage: $e');
      print('AudioStateManager: Stack trace: $stackTrace');
      _isVoiceOverPlaying = false;
      notifyListeners();
    }
  }

  Future<void> setCurrentPassage(String book, int chapter, List<Verse> verses) async {
    print('AudioStateManager: Setting current passage to $book chapter $chapter');
    bool wasPlaying = _isVoiceOverPlaying;
    _currentBook = book;
    _currentChapter = chapter;
    final verseTexts = verses.map((v) => v.text).toList();
    
    // Pass the current playback state to maintain it during passage changes
    await asvAudioService.setPassage(book, chapter, verseTexts, maintainState: wasPlaying);
    
    // Maintain the playing state if it was playing before
    _isVoiceOverPlaying = wasPlaying;
    notifyListeners();
  }

  Future<void> stop() async {
    print('AudioStateManager: Stopping playback');
    await asvAudioService.stop();
    _isVoiceOverPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    // Don't dispose of the audio services since they need to persist
    super.dispose();
  }
} 