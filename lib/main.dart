import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'dart:math';
import 'services/bible_service.dart';
import 'services/asv_audio_service.dart';
import 'constants/bible_data.dart';
import 'models/bible_book.dart';
import 'models/bookmarked_verse.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = true; // Set dark mode as default

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
    return MaterialApp(
            title: 'Codex Bible',
      theme: ThemeData(
              primarySwatch: Colors.blue,
              brightness: Brightness.light,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
            ),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const BibleReaderScreen(),
          );
        },
      ),
    );
  }
}

class BibleReaderScreen extends StatefulWidget {
  const BibleReaderScreen({super.key});

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  final BibleService _bibleService = BibleService();
  late final ASVAudioService _asvAudioService;
  final ScrollController _scrollController = ScrollController();
  List<BookmarkedVerse> _bookmarkedVerses = [];
  String? selectedBook = 'Genesis';
  int? selectedChapter = 1;
  List<String>? currentVerses;
  bool isPlaying = false;
  List<Map<String, dynamic>>? availableBibles;
  String? selectedBibleId;
  bool isLoading = false;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _checkAudioFiles();
    _loadBookmarks();
  }

  Future<void> _initializeServices() async {
    _asvAudioService = ASVAudioService();
    _asvAudioService.setOnChapterChangeCallback((String book, int chapter) {
      setState(() {
        selectedBook = book;
        selectedChapter = chapter;
      });
      _loadPassage();
    });
    await _loadBibles().then((_) {
      _loadPassage();
    });
  }

  @override
  void dispose() {
    _asvAudioService.dispose();
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

    setState(() {
      isLoading = true;
    });

    try {
      final result = await _bibleService.getChapter(selectedBook!, selectedChapter!);
      final verses = (result['verses'] as List).map((v) => v['text'] as String).toList();
      
      setState(() {
        currentVerses = verses;
        isLoading = false;
      });

      // Set verses in the audio service with book and chapter info
      await _asvAudioService.setPassage(selectedBook!, selectedChapter!, verses);
      
      // If we were playing before loading the new passage, continue playing
      if (isPlaying) {
        await _asvAudioService.play();
      }
    } catch (e) {
      print('Error loading passage: $e');
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

    if (_asvAudioService.isPlaying) {
      await _asvAudioService.pause();
      setState(() {
        isPlaying = false;
      });
    } else {
      await _asvAudioService.play();
      setState(() {
        isPlaying = true;
      });
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

  Future<void> _checkAudioFiles() async {
    final hasAudioFiles = await _asvAudioService.areAudioFilesExtracted();
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

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = prefs.getString('bookmarks');
    if (bookmarksJson != null) {
      final List<dynamic> bookmarksList = jsonDecode(bookmarksJson);
      setState(() {
        _bookmarkedVerses = bookmarksList
            .map((json) => BookmarkedVerse.fromJson(json))
            .toList();
      });
    }
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = jsonEncode(
      _bookmarkedVerses.map((bookmark) => bookmark.toJson()).toList(),
    );
    await prefs.setString('bookmarks', bookmarksJson);
  }

  void _showBookmarksDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bookmarked Verses',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _bookmarkedVerses.length,
                itemBuilder: (context, index) {
                  final bookmark = _bookmarkedVerses[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Text(
                        '${bookmark.book} ${bookmark.chapter}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        bookmark.text,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          setState(() {
                            _bookmarkedVerses.removeAt(index);
                          });
                          await _saveBookmarks();
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _showBookmarksDialog();
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          selectedBook = bookmark.book;
                          selectedChapter = bookmark.chapter;
                        });
                        _loadPassage();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Codex Bible'),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: themeProvider.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.book),
            onPressed: _showBookmarksDialog,
          ),
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
            icon: Text('Ch. $selectedChapter'),
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
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          '$selectedBook ${selectedChapter}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ),
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
                  ],
                ),
              ),
              _buildPlaybackControls(),
            ],
          ),
          if (!isLoading) ...[
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
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
              bottom: 0,
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
        ],
      ),
    );
  }

  Widget _buildVerseText(String verse, int verseIndex) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isBookmarked = _bookmarkedVerses.any((bookmark) =>
        bookmark.book == selectedBook &&
        bookmark.chapter == selectedChapter &&
        bookmark.verse == verseIndex + 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bookmark icon with animation
          SizedBox(
            width: 30,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0.0,
                end: isBookmarked ? 1.0 : 0.0,
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (value * 0.2), // Subtle scale animation
                  child: IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                    ),
                    onPressed: () => _toggleBookmark(verseIndex),
                    color: isDarkMode 
                      ? Color.lerp(Colors.white54, Colors.white, value)
                      : Color.lerp(
                          Theme.of(context).textTheme.bodySmall?.color,
                          Theme.of(context).primaryColor,
                          value,
                        ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8), // Add spacing between icon and text
          // Verse text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0), // Align text with icon
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
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: _playPassage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay),
                    onPressed: isPlaying ? () async {
                      await _asvAudioService.restart();
                      setState(() {
                        isPlaying = true;
                      });
                    } : null,
                    style: IconButton.styleFrom(
                      foregroundColor: isPlaying ? null : Theme.of(context).disabledColor,
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
          await _playPassage();
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
          await _playPassage();
        }
      }
    } else {
      setState(() {
        selectedChapter = newChapter;
      });
      await _loadPassage();
      if (isPlaying) {
        await _playPassage();
      }
    }
  }

  void _changePlaybackSpeed(double value) {
    setState(() {
      _playbackSpeed = value;
    });
    _asvAudioService.setPlaybackSpeed(value);
  }

  Future<void> _toggleBookmark(int verseIndex) async {
    if (selectedBook == null || selectedChapter == null || currentVerses == null) {
      return;
    }

    final verse = currentVerses![verseIndex];
    final existingIndex = _bookmarkedVerses.indexWhere((bookmark) =>
        bookmark.book == selectedBook &&
        bookmark.chapter == selectedChapter &&
        bookmark.verse == verseIndex + 1);

    setState(() {
      if (existingIndex >= 0) {
        _bookmarkedVerses.removeAt(existingIndex);
      } else {
        _bookmarkedVerses.add(BookmarkedVerse(
          book: selectedBook!,
          chapter: selectedChapter!,
          verse: verseIndex + 1,
          text: verse,
        ));
      }
    });

    await _saveBookmarks();
  }
}
