import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/local_bible_service.dart';
import '../services/asv_audio_service.dart';
import '../constants/bible_data.dart';
import '../models/bookmarked_verse.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_state_manager.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Alignment> _topAlignment;
  late Animation<Alignment> _bottomAlignment;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _topAlignment = TweenSequence<Alignment>([
      TweenSequenceItem(
        weight: 1.0,
        tween: AlignmentTween(
          begin: Alignment.topLeft,
          end: Alignment.topRight,
        ),
      ),
      TweenSequenceItem(
        weight: 1.0,
        tween: AlignmentTween(
          begin: Alignment.topRight,
          end: Alignment.bottomRight,
        ),
      ),
    ]).animate(_controller);

    _bottomAlignment = TweenSequence<Alignment>([
      TweenSequenceItem(
        weight: 1.0,
        tween: AlignmentTween(
          begin: Alignment.bottomRight,
          end: Alignment.bottomLeft,
        ),
      ),
      TweenSequenceItem(
        weight: 1.0,
        tween: AlignmentTween(
          begin: Alignment.bottomLeft,
          end: Alignment.topLeft,
        ),
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _topAlignment.value,
              end: _bottomAlignment.value,
              colors: const [
                Color(0xFF000000),
                Color(0xFF1A1A1A),
                Color(0xFF262626),
                Color(0xFF1A1A1A),
                Color(0xFF000000),
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

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
  bool _isControlsExpanded = true;

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
    _audioStateManager.asvAudioService.setOnChapterChangeCallback((String book, int chapter) async {
      print('Chapter changed callback: $book $chapter');
      if (!mounted) return;
      
      setState(() {
        selectedBook = book;
        selectedChapter = chapter;
        isPlaying = true; // Update playing state since this is auto-navigation
      });
      
      // Load the new passage
      await _loadPassage();
      
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
      
      // If we were playing before loading the new passage or this is an auto-navigation, continue playing
      if (isPlaying) {
        await _audioStateManager.asvAudioService.play();
      }

      // Save the current position
      await _savePosition();
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
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Logo section with padding
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
              // Collapsible Controls Section
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Column(
                  children: [
                    // Header with arrow
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isControlsExpanded = !_isControlsExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            const Text(
                              'Controls',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            RotatedBox(
                              quarterTurns: _isControlsExpanded ? 2 : 0,
                              child: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Collapsible content
                    if (_isControlsExpanded) ...[
                      // Book and Chapter Selection
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  canvasColor: Colors.black,
                                ),
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
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  canvasColor: Colors.black,
                                ),
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
                            ),
                          ],
                        ),
                      ),
                      // Audio Controls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_previous),
                              onPressed: () => _navigateChapter(-1),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                                  onPressed: _playPassage,
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 2.0,
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                                        ),
                                        child: Slider(
                                          value: _playbackSpeed,
                                          min: 0.5,
                                          max: 2.0,
                                          divisions: 6,
                                          onChanged: _changePlaybackSpeed,
                                        ),
                                      ),
                                    ),
                                    Text('${_playbackSpeed}x', 
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next),
                              onPressed: () => _navigateChapter(1),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Divider for visual separation
                    Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ],
                ),
              ),
              // Verses Section (no longer collapsible)
              Expanded(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: currentVerses == null ? 1 : currentVerses!.length + 1, // +1 for the header
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Header item
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            '$selectedBook Chapter $selectedChapter',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }
                      
                      // Verse items
                      if (isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (currentVerses == null || currentVerses!.isEmpty) {
                        return const Center(child: Text('No verses available'));
                      }
                      
                      final verseIndex = index - 1; // Adjust for header
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                        child: Text(
                          '${verseIndex + 1}. ${currentVerses![verseIndex]}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
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