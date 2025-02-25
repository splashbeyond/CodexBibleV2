import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bible_service.dart';
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
  final BibleService _bibleService = BibleService();
  final ScrollController _scrollController = ScrollController();
  String? selectedBook = 'Genesis';
  int? selectedChapter = 1;
  List<String>? currentVerses;
  bool isPlaying = false;
  List<Map<String, dynamic>>? availableBibles;
  String? selectedBibleId;
  bool isLoading = false;
  double _playbackSpeed = 1.0;

  late final AudioStateManager _audioStateManager;

  @override
  void initState() {
    super.initState();
    _audioStateManager = Provider.of<AudioStateManager>(context, listen: false);
    _initializeServices();
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
    
    await _loadBibles().then((_) {
      _loadPassage();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBibles() async {
    try {
      final bibles = await _bibleService.getAvailableBibles();
      print('Available Bibles: ${bibles.map((b) => '${b['name']} (${b['id']})').join(', ')}');

      setState(() {
        availableBibles = bibles;
        if (bibles.isNotEmpty) {
          // Always select WEB Bible
          final webBible = bibles.firstWhere(
            (bible) =>
              bible['abbreviation']?.toString().toUpperCase() == 'WEB' ||
              bible['name'].toString().contains('World English') ||
              bible['id'] == '7142879509583d59-04', // WEB Bible ID
            orElse: () => bibles.first,
          );

          print('Selected Bible: ${webBible['name']} (${webBible['id']})');
          selectedBibleId = webBible['id'];
          _bibleService.setBibleId(selectedBibleId!);
        }
      });
    } catch (e) {
      print('Error loading Bibles: $e');
      _showError('Failed to load Bible translations');
    }
  }

  Future<void> _loadPassage() async {
    if (selectedBook == null || selectedChapter == null || selectedBibleId == null) {
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

  Future<void> _checkAudioFiles() async {
    final hasAudioFiles = await _audioStateManager.asvAudioService.areAudioFilesExtracted();
    if (!hasAudioFiles) {
      // Show error message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio files not found in assets. Please check your app installation.'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final playbackControlsHeight = 80.0;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
                title: Text('$selectedBook ${selectedChapter ?? ""}'),
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.menu),
                    onSelected: (String book) {
                      setState(() {
                        selectedBook = book;
                        selectedChapter = 1;
                      });
                      _loadPassage();
                    },
                    itemBuilder: (BuildContext context) {
                      return BibleData.books.keys.map((String book) {
                        return PopupMenuItem<String>(
                          value: book,
                          child: Text(book),
                        );
                      }).toList();
                    },
                  ),
                  PopupMenuButton<int>(
                    icon: Text('Ch. ${selectedChapter ?? ""}'),
                    onSelected: (int chapter) {
                      setState(() {
                        selectedChapter = chapter;
                      });
                      _loadPassage();
                    },
                    itemBuilder: (BuildContext context) {
                      if (selectedBook == null) return [];
                      return List.generate(BibleData.books[selectedBook]!, (index) => index + 1)
                          .map((int chapter) {
                        return PopupMenuItem<int>(
                          value: chapter,
                          child: Text('Chapter $chapter'),
                        );
                      }).toList();
                    },
                  ),
                ],
              ),
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (currentVerses == null || index >= currentVerses!.length) {
                        return null;
                      }
                      return _buildVerseText(currentVerses![index], index);
                    },
                    childCount: currentVerses?.length ?? 0,
                  ),
                ),
              // Add padding at bottom for playback controls
              SliverToBoxAdapter(
                child: SizedBox(height: playbackControlsHeight + 16),
              ),
            ],
          ),
          if (!isLoading) ...[
            Positioned(
              left: 0,
              top: 0,
              bottom: playbackControlsHeight,
              child: Container(
                width: 40,
                alignment: Alignment.center,
                child: IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _navigateChapter(-1),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: playbackControlsHeight,
              child: Container(
                width: 40,
                alignment: Alignment.center,
                child: IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _navigateChapter(1),
                ),
              ),
            ),
          ],
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildPlaybackControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseText(String verse, int verseIndex) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bookmark icon
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {
              // Handle bookmark in the BookmarksScreen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Go to Bookmarks tab to save verses'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            iconSize: 20,
            color: isDarkMode ? Colors.white54 : Theme.of(context).textTheme.bodySmall?.color,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          // Verse text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                verse,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.5,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_audioStateManager.isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: _playPassage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay),
                    onPressed: _audioStateManager.isPlaying ? () async {
                      await _audioStateManager.asvAudioService.restart();
                    } : null,
                    style: IconButton.styleFrom(
                      foregroundColor: _audioStateManager.isPlaying ? null : Theme.of(context).disabledColor,
                    ),
                  ),
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
                  Text('${_playbackSpeed}x'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateChapter(int delta) async {
    if (selectedBook == null || selectedChapter == null || isLoading) return;

    final maxChapters = BibleData.books[selectedBook] ?? 1;
    final newChapter = selectedChapter! + delta;

    if (newChapter < 1) {
      // Go to previous book's last chapter
      final booksList = BibleData.books.keys.toList();
      final currentIndex = booksList.indexOf(selectedBook!);
      if (currentIndex > 0) {
        final previousBook = booksList[currentIndex - 1];
        final lastChapter = BibleData.books[previousBook]!;

        setState(() {
          selectedBook = previousBook;
          selectedChapter = lastChapter;
        });
        await _loadPassage();
        if (isPlaying) {
          await _audioStateManager.resumeAll();
        }
      }
    } else if (newChapter > maxChapters) {
      // Go to next book's first chapter
      final booksList = BibleData.books.keys.toList();
      final currentIndex = booksList.indexOf(selectedBook!);
      if (currentIndex < booksList.length - 1) {
        final nextBook = booksList[currentIndex + 1];

        setState(() {
          selectedBook = nextBook;
          selectedChapter = 1;
        });
        await _loadPassage();
        if (isPlaying) {
          await _audioStateManager.resumeAll();
        }
      }
    } else {
      setState(() {
        selectedChapter = newChapter;
      });
      await _loadPassage();
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