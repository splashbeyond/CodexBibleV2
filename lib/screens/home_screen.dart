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
import '../services/bookmark_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocalBibleService _bibleService = LocalBibleService();
  final BookmarkService _bookmarkService = BookmarkService();
  final ScrollController _scrollController = ScrollController();
  String? selectedBook = 'Genesis';
  int? selectedChapter = 1;
  List<String>? currentVerses;
  bool isLoading = false;
  double _playbackSpeed = 1.0;
  bool _isControlsExpanded = true;

  late final AudioStateManager _audioStateManager;

  @override
  void initState() {
    super.initState();
    _audioStateManager = Provider.of<AudioStateManager>(context, listen: false);
    _loadSavedPosition().then((_) => _initializeServices());
    _bookmarkService.setupAuthListener();
    _loadBookmarks();

    // Listen to audio state changes
    _audioStateManager.addListener(_onAudioStateChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioStateManager.removeListener(_onAudioStateChanged);
    super.dispose();
  }

  void _onAudioStateChanged() {
    if (mounted) {
      setState(() {
        // This will trigger a rebuild of the UI with the current audio state
      });
    }
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
      
      // Update the UI state first
      setState(() {
        selectedBook = book;
        selectedChapter = chapter;
        isLoading = true; // Show loading indicator during transition
      });
      
      // Load the new passage
      await _loadPassage();
      
      // Scroll to top with a smooth animation
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      // Resume playback for the new chapter
      if (_audioStateManager.isPlaying) {
        print('HomeScreen: Auto-resuming playback for new chapter');
        // Ensure we have the current passage set before resuming
        await _audioStateManager.setCurrentPassage(
          book,
          chapter,
          currentVerses!.map((text) => Verse(text: text)).toList(),
        );
        // Don't call resumeAll() here as play() is already called in _handlePlaybackCompletion
      }
    });
    
    await _loadPassage();
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
    try {
      print('HomeScreen: Play button pressed');
      if (currentVerses == null || currentVerses!.isEmpty) {
        print('HomeScreen: No verses available to play');
        _showError('Please select a passage first');
        return;
      }

      print('HomeScreen: Current state - Book: $selectedBook, Chapter: $selectedChapter');
      try {
        if (_audioStateManager.isPlaying) {
          print('HomeScreen: Attempting to pause playback');
          await _audioStateManager.togglePlayback();
        } else {
          print('HomeScreen: Attempting to start playback');
          // Make sure we have the current passage set
          await _audioStateManager.setCurrentPassage(
            selectedBook!,
            selectedChapter!,
            currentVerses!.map((text) => Verse(text: text)).toList(),
          );
          // Start playback using AudioStateManager
          await _audioStateManager.togglePlayback();
        }
      } catch (e) {
        print('HomeScreen: Error during playback toggle: $e');
        rethrow;
      }
    } catch (e, stackTrace) {
      print('HomeScreen: Error in _playPassage: $e');
      print('HomeScreen: Stack trace: $stackTrace');
      _showError('Error playing audio: ${e.toString()}');
    }
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
    return Scaffold(
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final books = _bibleService.getBooks();
    final maxChapters = selectedBook != null ? _bibleService.getChapterCount(selectedBook!) : 1;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Logo section with padding
            Container(
              width: double.infinity,
              color: isDarkMode ? Colors.transparent : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Image.asset(
                'assets/images/logo.png',
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
            // Collapsible Controls Section
            Container(
              color: isDarkMode ? Colors.black.withOpacity(0.7) : Colors.white,
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
                          Text(
                            'Controls',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          const Spacer(),
                          RotatedBox(
                            quarterTurns: _isControlsExpanded ? 2 : 0,
                            child: Icon(
                              Icons.arrow_drop_down,
                              color: isDarkMode ? Colors.white : Colors.black,
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
                                canvasColor: isDarkMode ? Colors.black : Colors.white,
                              ),
                              child: DropdownButton<String>(
                                value: selectedBook,
                                items: books.map((String book) {
                                  return DropdownMenuItem<String>(
                                    value: book,
                                    child: Text(
                                      book,
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                    ),
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
                                canvasColor: isDarkMode ? Colors.black : Colors.white,
                              ),
                              child: DropdownButton<int>(
                                value: selectedChapter,
                                items: List.generate(maxChapters, (index) {
                                  return DropdownMenuItem<int>(
                                    value: index + 1,
                                    child: Text(
                                      'Chapter ${index + 1}',
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                    ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Row(
                        children: [
                          // Play and Restart buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _audioStateManager.isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                                onPressed: _playPassage,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.replay,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                                onPressed: () => _audioStateManager.asvAudioService.restart(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Playback speed controls
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
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
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 45,
                                  child: Text(
                                    '${_playbackSpeed}x',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Divider for visual separation
                  Divider(
                    height: 1,
                    color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2),
                  ),
                ],
              ),
            ),
            // Verses Section (no longer collapsible)
            Expanded(
              child: Stack(
                children: [
                  Container(
                    color: isDarkMode ? Colors.black.withOpacity(0.7) : Colors.white,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0), // Reduced padding to extend text
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
                                color: isDarkMode ? Colors.white : Colors.black,
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
                        final isBookmarked = _bookmarkService.isVerseBookmarked(
                          selectedBook!,
                          selectedChapter!,
                          verseIndex + 1
                        );
                        
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row for bookmark icon and verse number
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Bookmark button
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () async {
                                          try {
                                            if (!_bookmarkService.isAuthenticated) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Please sign in to bookmark verses'),
                                                  duration: Duration(seconds: 2),
                                                ),
                                              );
                                              return;
                                            }

                                            final wasBookmarked = _bookmarkService.isVerseBookmarked(
                                              selectedBook!,
                                              selectedChapter!,
                                              verseIndex + 1
                                            );

                                            // Update UI immediately
                                            setState(() {});

                                            await _bookmarkService.toggleBookmark(
                                              selectedBook!,
                                              selectedChapter!,
                                              verseIndex + 1,
                                              currentVerses![verseIndex]
                                            );

                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    wasBookmarked ? 'Bookmark removed' : 'Verse bookmarked'
                                                  ),
                                                  duration: const Duration(seconds: 1),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            print('Error toggling bookmark: $e');
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: Colors.red,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                            // Refresh bookmarks to ensure UI is in sync
                                            await _loadBookmarks();
                                          }
                                        },
                                        child: Icon(
                                          _bookmarkService.isVerseBookmarked(
                                            selectedBook!,
                                            selectedChapter!,
                                            verseIndex + 1
                                          ) ? Icons.bookmark : Icons.bookmark_border,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Verse number
                                  Text(
                                    '${verseIndex + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8), // Add some spacing
                              // Verse text
                              Expanded(
                                child: _buildVerseText(currentVerses![verseIndex], verseIndex),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Previous Chapter Button (Left)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 48,
                      color: Colors.transparent, // Make container transparent
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.chevron_left,
                              size: 40,
                              color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.4),
                            ),
                            onPressed: () => _navigateChapter(-1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Next Chapter Button (Right)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 48,
                      color: Colors.transparent, // Make container transparent
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.chevron_right,
                              size: 40,
                              color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.4),
                            ),
                            onPressed: () => _navigateChapter(1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerseText(String verseText, int verseIndex) {
    return Text(
      verseText,
      style: TextStyle(
        fontSize: 16,
        color: Theme.of(context).brightness == Brightness.dark 
          ? Colors.white 
          : Colors.black,
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
        if (_audioStateManager.isPlaying) {
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
        if (_audioStateManager.isPlaying) {
          await _audioStateManager.resumeAll();
        }
      }
    } else {
      setState(() {
        selectedChapter = newChapter;
      });
      await _loadPassage();
      await _savePosition();
      if (_audioStateManager.isPlaying) {
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

  Future<void> _loadBookmarks() async {
    try {
      await _bookmarkService.loadBookmarks();
      if (mounted) {
        setState(() {}); // Refresh UI after loading bookmarks
      }
    } catch (e) {
      print('Error loading bookmarks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bookmarks: $e')),
        );
      }
    }
  }
} 