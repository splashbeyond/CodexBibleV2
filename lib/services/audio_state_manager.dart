import 'package:flutter/foundation.dart';
import 'background_music_service.dart';
import 'asv_audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioStateManager extends ChangeNotifier {
  static final AudioStateManager _instance = AudioStateManager._internal();
  factory AudioStateManager() => _instance;

  final BackgroundMusicService backgroundMusicService = BackgroundMusicService();
  final ASVAudioService asvAudioService = ASVAudioService();
  bool _isVoiceOverPlaying = false;
  bool _isBackgroundMusicEnabled = true;
  double _backgroundMusicVolume = 0.5;

  AudioStateManager._internal() {
    _initialize();
  }

  bool get isPlaying => _isVoiceOverPlaying;
  bool get isBackgroundMusicEnabled => _isBackgroundMusicEnabled;
  double get backgroundMusicVolume => _backgroundMusicVolume;

  Future<void> _initialize() async {
    await _loadSettings();
    
    // Set up the ASVAudioService to update playing state when chapter changes
    asvAudioService.setOnChapterChangeCallback((String book, int chapter) {
      _isVoiceOverPlaying = true; // Keep playing state when chapter changes
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
      if (_isVoiceOverPlaying) {
        await asvAudioService.pause();
        _isVoiceOverPlaying = false;
      } else {
        // Start voice-over without affecting background music
        await asvAudioService.play();
        _isVoiceOverPlaying = true;
      }
      notifyListeners();
    } catch (e) {
      print('Error toggling voice-over playback: $e');
    }
  }

  Future<void> stopAll() async {
    try {
      await asvAudioService.pause();
      if (_isBackgroundMusicEnabled) {
        await backgroundMusicService.pause();
      }
      _isVoiceOverPlaying = false;
      notifyListeners();
    } catch (e) {
      print('Error stopping all audio: $e');
    }
  }

  Future<void> resumeAll() async {
    try {
      if (_isBackgroundMusicEnabled && backgroundMusicService.currentSong != null) {
        await backgroundMusicService.resume();
      }
      await asvAudioService.resume();
      _isVoiceOverPlaying = true;
      notifyListeners();
    } catch (e) {
      print('Error resuming all audio: $e');
    }
  }

  // Add navigation method for bookmarks
  Future<void> navigateToPassage(String book, int chapter) async {
    asvAudioService.setOnChapterChangeCallback((_, __) {}); // Clear existing callback
    await asvAudioService.setPassage(book, chapter, []); // Set new passage
    notifyListeners();
  }

  @override
  void dispose() {
    asvAudioService.dispose();
    backgroundMusicService.dispose();
    super.dispose();
  }
} 