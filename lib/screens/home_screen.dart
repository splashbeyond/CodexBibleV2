import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/local_bible_service.dart';
import '../services/asv_audio_service.dart';
import '../constants/bible_data.dart';
import '../models/bookmarked_verse.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_state_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocalBibleService _bibleService = LocalBibleService();
  final ScrollController _scrollController = ScrollController();
  String? selectedBook = 'Genesis';
  int? selectedChapter = 1;
  List<String>? currentVerses;
  bool isPlaying = false;
  bool isLoading = false;
  double _playbackSpeed = 1.0;

  late final AudioStateManager _audioStateManager;

  @override
  void initState() {
    super.initState();
    _audioStateManager = Provider.of<AudioStateManager>(context, listen: false);
    _loadSavedPosition().then((_) => _initializeServices());
  }

  Future<void> _loadSavedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        selectedBook = prefs.getString('selectedBook') ?? 'Genesis';
        selectedChapter = prefs.getInt('selectedChapter') ?? 1;
      });
      print('Loaded saved position: $selectedBook chapter $selectedChapter');
    } catch (e) {
      print('Error loading saved position: $e');
    }
  }

  Future<void> _savePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedBook', selectedBook ?? 'Genesis');
      await prefs.setInt('selectedChapter', selectedChapter ?? 1);
      print('Saved position: $selectedBook chapter $selectedChapter');
    } catch (e) {
      print('Error saving position: $e');
    }
  }

  Future<void> _initializeServices() async {
    // Set up the chapter change callback on the AudioStateManager's ASVAudioService
    _audioStateManager.asvAudioService.setOnChapterChangeCallback((String book, int chapter) {
      print('Chapter changed callback: $book $chapter');
      if (!mounted) return;
      
      setState(() {
        selectedBook = book;
        selectedChapter = chapter;
        isPlaying = true; // Update playing state since this is auto-navigation
      });
      
      // Load the new passage
      _loadPassage();
      
      // Scroll to top when chapter changes
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
    
    _loadPassage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPassage() async {
    if (selectedBook == null || selectedChapter == null) {
      return;
    }

    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      final result = await _bibleService.getChapter(selectedBook!, selectedChapter!);
      final verses = (result['verses'] as List).map((v) => v['text'] as String).toList();
      
      if (!mounted) return;
      setState(() {
        currentVerses = verses;
        isLoading = false;
      });

      // Set verses in the AudioStateManager's ASVAudioService
      await _audioStateManager.asvAudioService.setPassage(selectedBook!, selectedChapter!, verses);
      
      // If we were playing before loading the new passage, continue playing
      if (isPlaying) {
        await _audioStateManager.asvAudioService.play();
      }
    } catch (e) {
      print('Error loading passage: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        currentVerses = [];
      });
    }
  }

  Future<void> _playPassage() async {
    if (currentVerses == null || currentVerses!.isEmpty) {
      _showError('Please select a passage first');
      return;
    }

    // Set the current passage in the ASV audio service
    await _audioStateManager.asvAudioService.setPassage(selectedBook!, selectedChapter!, currentVerses!);
    
    // Toggle playback through the audio state manager
    await _audioStateManager.togglePlayback();
    setState(() {
      isPlaying = _audioStateManager.isPlaying;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final books = _bibleService.getBooks();
    final maxChapters = selectedBook != null ? _bibleService.getChapterCount(selectedBook!) : 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bible Reader'),
        actions: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _playPassage,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedBook,
                    items: books.map((String book) {
                      return DropdownMenuItem<String>(
                        value: book,
                        child: Text(book),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedBook = newValue;
                        selectedChapter = 1;
                      });
                      _loadPassage();
                      _savePosition();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<int>(
                    value: selectedChapter,
                    items: List.generate(maxChapters, (index) {
                      return DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text('Chapter ${index + 1}'),
                      );
                    }),
                    onChanged: (int? newValue) {
                      setState(() {
                        selectedChapter = newValue;
                      });
                      _loadPassage();
                      _savePosition();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (currentVerses == null || currentVerses!.isEmpty)
                  const Center(child: Text('No verses available'))
                else
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: currentVerses!.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          '${index + 1}. ${currentVerses![index]}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => _navigateChapter(-1),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => _navigateChapter(1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.speed),
                Expanded(
                  child: Slider(
                    value: _playbackSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 6,
                    label: '${_playbackSpeed}x',
                    onChanged: _changePlaybackSpeed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateChapter(int delta) async {
    if (selectedBook == null || selectedChapter == null || isLoading) return;

    final maxChapters = _bibleService.getChapterCount(selectedBook!);
    final newChapter = selectedChapter! + delta;

    if (newChapter < 1) {
      // Go to previous book's last chapter
      final booksList = _bibleService.getBooks();
      final currentIndex = booksList.indexOf(selectedBook!);
      if (currentIndex > 0) {
        final previousBook = booksList[currentIndex - 1];
        final lastChapter = _bibleService.getChapterCount(previousBook);

        setState(() {
          selectedBook = previousBook;
          selectedChapter = lastChapter;
        });
        await _loadPassage();
        await _savePosition();
        if (isPlaying) {
          await _audioStateManager.resumeAll();
        }
      }
    } else if (newChapter > maxChapters) {
      // Go to next book's first chapter
      final booksList = _bibleService.getBooks();
      final currentIndex = booksList.indexOf(selectedBook!);
      if (currentIndex < booksList.length - 1) {
        final nextBook = booksList[currentIndex + 1];

        setState(() {
          selectedBook = nextBook;
          selectedChapter = 1;
        });
        await _loadPassage();
        await _savePosition();
        if (isPlaying) {
          await _audioStateManager.resumeAll();
        }
      }
    } else {
      setState(() {
        selectedChapter = newChapter;
      });
      await _loadPassage();
      await _savePosition();
      if (isPlaying) {
        await _audioStateManager.resumeAll();
      }
    }
  }

  void _changePlaybackSpeed(double value) {
    setState(() {
      _playbackSpeed = value;
    });
    _audioStateManager.asvAudioService.setPlaybackSpeed(value);
  }
} 