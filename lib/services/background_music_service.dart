import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundMusicService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  double _volume = 0.5;
  String? _currentSong;
  List<String> _availableSongs = [];

  bool get isPlaying => _isPlaying;
  double get volume => _volume;
  String? get currentSong => _currentSong;
  List<String> get availableSongs => _availableSongs;

  BackgroundMusicService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _setupAudioPlayer();
      await _loadSettings();
      await _loadAvailableSongs();
      print('BackgroundMusicService initialized successfully');
    } catch (e) {
      print('Error initializing BackgroundMusicService: $e');
    }
  }

  Future<void> _setupAudioPlayer() async {
    try {
      print('Setting up audio player');
      
      // Configure audio player for background playback
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(_volume);
      
      // Set up audio context
      final audioContext = AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: [
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.defaultToSpeaker
          ]
        )
      );
      await _audioPlayer.setAudioContext(audioContext);
      
      _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
        print('Background music player state changed: $state');
        _isPlaying = state == PlayerState.playing;
      });

      print('Audio player setup completed');
    } catch (e) {
      print('Error setting up audio player: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _volume = prefs.getDouble('backgroundMusicVolume') ?? 0.5;
      _currentSong = prefs.getString('currentBackgroundSong');
      print('Loaded settings - Volume: $_volume, Current song: $_currentSong');
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> _loadAvailableSongs() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestContent);
      
      _availableSongs = manifest.keys
          .where((String key) => key.startsWith('assets/background_music/') && key.endsWith('.mp3'))
          .map((String path) => path.split('/').last)
          .toList();
      
      print('Available songs: $_availableSongs');
    } catch (e) {
      print('Error loading available songs: $e');
    }
  }

  Future<void> playSong(String songName) async {
    try {
      print('Playing song: $songName');
      
      // Stop current playback
      await _audioPlayer.stop();
      
      // Set up the audio player
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      
      // Play the song
      final source = AssetSource('background_music/$songName');
      await _audioPlayer.play(source);
      
      _currentSong = songName;
      _isPlaying = true;
      await _saveSettings();
      
      print('Started playing background music');
    } catch (e) {
      print('Error playing song: $e');
    }
  }

  Future<void> pause() async {
    try {
      print('Pausing background music');
      await _audioPlayer.pause();
      _isPlaying = false;
      await _saveSettings();
    } catch (e) {
      print('Error pausing: $e');
    }
  }

  Future<void> resume() async {
    try {
      print('Resuming background music');
      if (_currentSong != null) {
        if (_audioPlayer.state == PlayerState.paused) {
          await _audioPlayer.resume();
        } else {
          await playSong(_currentSong!);
        }
        _isPlaying = true;
        await _saveSettings();
      }
    } catch (e) {
      print('Error resuming: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      print('Setting volume: $volume');
      _volume = volume;
      await _audioPlayer.setVolume(volume);
      await _saveSettings();
    } catch (e) {
      print('Error setting volume: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('backgroundMusicVolume', _volume);
      if (_currentSong != null) {
        await prefs.setString('currentBackgroundSong', _currentSong!);
      }
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
} 