import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'dart:math';
import 'services/bible_service.dart';
import 'services/voice_service.dart';
import 'constants/bible_data.dart';
import 'models/bible_book.dart';
import 'dart:io';

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
  late final VoiceService _voiceService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final PanelController _panelController = PanelController();
  String? selectedBook = 'Genesis';
  int? selectedChapter = 1;
  Voice? selectedVoice;
  List<String>? currentVerses;
  bool isPlaying = false;
  List<Voice>? voices;
  String? currentAudioPath;
  List<Map<String, dynamic>>? availableBibles;
  String? selectedBibleId;
  bool isLoading = false;
  bool isContinuousPlaying = false;
  int currentVerseIndex = 0;
  static const int versesPerChunk = 1; // Only read one verse at a time
  String? nextAudioPath; // Store the next audio chunk path
  bool isPreloading = false; // Track preloading state
  bool isProcessing = false;
  List<String> audioQueue = [];
  List<String> verseQueue = [];
  double _playbackSpeed = 1.0;
  List<Map<String, dynamic>>? currentVerseData;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final elevenlabsKey = dotenv.env['ELEVENLABS_API_KEY'];
    if (elevenlabsKey == null || elevenlabsKey.isEmpty) {
      _showError('ElevenLabs API key not found. Please check your .env file.');
      return;
    }

    _voiceService = VoiceService();
    print('Initializing with ElevenLabs API key: ${elevenlabsKey.substring(0, 10)}...');

    await _loadVoices();
    await _loadBibles().then((_) {
      _loadPassage();
    });
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    // Remove all existing listeners
    _audioPlayer.onPlayerComplete.listen((event) {
      if (!isContinuousPlaying) {
        setState(() {
          isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    isContinuousPlaying = false;
    isPlaying = false;
    _audioPlayer.stop();
    _audioPlayer.dispose();

    // Clean up current audio file
    if (currentAudioPath != null) {
      try {
        final file = File(currentAudioPath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        print('Error cleaning up audio file during dispose: $e');
      }
    }
    super.dispose();
  }

  Future<void> _loadVoices() async {
    try {
      final loadedVoices = await _voiceService.getVoices();
      setState(() {
        voices = loadedVoices;
        if (loadedVoices.isNotEmpty) {
          selectedVoice = loadedVoices.first;
        }
      });
    } catch (e) {
      _showError('Failed to load voices');
    }
  }

  Future<void> _loadBibles() async {
    try {
      final bibles = await _bibleService.getAvailableBibles();
      print('Available Bibles: ${bibles.map((b) => '${b['name']} (${b['id']})').join(', ')}');

      setState(() {
        availableBibles = bibles;
        if (bibles.isNotEmpty) {
          // Look for KJV Bible
          final kjvBible = bibles.firstWhere(
            (bible) =>
              bible['abbreviation']?.toString().toUpperCase() == 'KJV' ||
              bible['name'].toString().contains('King James') ||
              bible['id'] == 'de4e12af7f28f599-02', // KJV Bible ID
            orElse: () => bibles.first,
          );

          print('Selected Bible: ${kjvBible['name']} (${kjvBible['id']})');
          selectedBibleId = kjvBible['id'];
          _bibleService.setBibleId(selectedBibleId!);
        }
      });
    } catch (e) {
      print('Error loading Bibles: $e');
      _showError('Failed to load Bible translations');
    }
  }

  // Add this method to extract verse number from text
  int _extractVerseNumber(String verseText, int index) {
    // First try to find a verse number at the start of the text
    final numberMatch = RegExp(r'^\d+').firstMatch(verseText);
    if (numberMatch != null) {
      return int.parse(numberMatch.group(0)!);
    }
    // If no number found in text, use the index + 1 as fallback
    return index + 1;
  }

  // Update the verse parsing method to preserve verse numbers
  List<String> _parseVerses(String content) {
    // First, remove all HTML tags and clean up the content
    String cleanContent = content
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('¶', '') // Remove paragraph markers
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
        .trim();

    // Split into verses using a more robust pattern that preserves quotes
    List<String> verses = cleanContent.split(RegExp(r'(?<=\.) (?=\d+|[A-Z])'));
    return verses.where((verse) => verse.isNotEmpty).toList();
  }

  Future<void> _loadPassage() async {
    try {
      if (selectedBook == null || selectedChapter == null) return;

      setState(() {
        isLoading = true;
      });

      final response = await _bibleService.getChapter(selectedBook!, selectedChapter!);
      if (response['content'].isNotEmpty) {
        final verses = _parseVerses(response['content']);
        setState(() {
          currentVerses = verses;
          currentVerseData = response['verses'];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading passage: $e');
      setState(() {
        isLoading = false;
        currentVerses = [];
        currentVerseData = [];
      });
    }
  }

  Future<void> _playCurrentVerse() async {
    if (!mounted || !isContinuousPlaying || currentVerses == null || currentVerses!.isEmpty) {
      setState(() {
        isPlaying = false;
        isContinuousPlaying = false;
      });
      return;
    }

    if (currentVerseIndex >= currentVerses!.length) {
      setState(() {
        isPlaying = false;
        isContinuousPlaying = false;
        currentVerseIndex = 0;
      });
      return;
    }

    try {
      await _audioPlayer.stop();

      // Clean up previous audio file
      if (currentAudioPath != null) {
        try {
          final file = File(currentAudioPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('Error cleaning up previous audio file: $e');
        }
        currentAudioPath = null;
      }

      String audioPath;
      final currentIndex = currentVerseIndex;

      // Check if we have a preloaded audio file for this verse
      if (nextAudioPath != null && currentIndex > 0) {
        audioPath = nextAudioPath!;
        nextAudioPath = null;
      } else {
        // Generate audio for current verse
        final verse = currentVerses![currentIndex];
        print('Processing verse ${currentIndex + 1}: $verse');
        audioPath = await _voiceService.generateChapterAudio(
          [verse],
          selectedVoice!.id,
        );
      }

      if (!mounted || !isContinuousPlaying || currentIndex != currentVerseIndex) {
        try {
          await File(audioPath).delete();
        } catch (e) {
          print('Error cleaning up cancelled audio file: $e');
        }
        return;
      }

      currentAudioPath = audioPath;
      print('Playing verse ${currentIndex + 1}');

      // Start preloading next verse while current verse is playing
      if (currentIndex + 1 < currentVerses!.length) {
        _preloadNextVerse();
      }

      // Set playback speed and play current verse
      await _audioPlayer.setPlaybackRate(_playbackSpeed);
      await _audioPlayer.play(DeviceFileSource(audioPath));

      // Wait for completion
      await _audioPlayer.onPlayerComplete.first;

      // Move to next verse if still playing
      if (mounted && isContinuousPlaying && currentIndex == currentVerseIndex) {
        setState(() {
          currentVerseIndex++;
        });
        // Reduced delay between verses since we're preloading
        await Future.delayed(const Duration(milliseconds: 100));
        _playCurrentVerse();
      }
    } catch (e) {
      print('Error playing verse ${currentVerseIndex + 1}: $e');
      if (mounted) {
        setState(() {
          isPlaying = false;
          isContinuousPlaying = false;
        });
        _showError('Failed to play verse ${currentVerseIndex + 1}');
      }
    }
  }

  Future<void> _preloadNextVerse() async {
    if (currentVerses == null || currentVerses!.isEmpty || isPreloading) return;

    final nextIndex = currentVerseIndex + 1;
    if (nextIndex >= currentVerses!.length) return;

    try {
      isPreloading = true;
      final nextVerse = currentVerses![nextIndex];
      print('Preloading verse ${nextIndex + 1}: $nextVerse');

      final audioPath = await _voiceService.generateChapterAudio(
        [nextVerse],
        selectedVoice!.id,
      );

      // Only store the preloaded path if we're still playing and haven't moved past this verse
      if (mounted && isContinuousPlaying && nextIndex == currentVerseIndex + 1) {
        nextAudioPath = audioPath;
      } else {
        // Clean up the audio file if it's no longer needed
        try {
          await File(audioPath).delete();
        } catch (e) {
          print('Error cleaning up unused preloaded file: $e');
        }
      }
    } catch (e) {
      print('Error preloading next verse: $e');
      nextAudioPath = null;
    } finally {
      isPreloading = false;
    }
  }

  Future<void> _playPassage() async {
    if (currentVerses == null || selectedVoice == null || currentVerses!.isEmpty) {
      _showError('Please select a passage and voice first');
      return;
    }

    if (isPlaying) {
      // Stop playback
      await _audioPlayer.stop();
      setState(() {
        isPlaying = false;
        isContinuousPlaying = false;
        currentVerseIndex = 0;
      });
      return;
    }

    // Start from the beginning
    setState(() {
      currentVerseIndex = 0;
      isPlaying = true;
      isContinuousPlaying = true;
    });

    // Start playing verses
    _playCurrentVerse();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _navigateChapter(int delta) {
    if (selectedBook == null || selectedChapter == null) return;

    final maxChapters = BibleData.books[selectedBook] ?? 1;
    final newChapter = selectedChapter! + delta;

    if (newChapter < 1) {
      // Go to previous book's last chapter
      final booksList = BibleData.books.keys.toList();
      final currentIndex = booksList.indexOf(selectedBook!);
      if (currentIndex > 0) {
        final previousBook = booksList[currentIndex - 1];
        setState(() {
          selectedBook = previousBook;
          selectedChapter = BibleData.books[previousBook];
          currentVerses = null;
          currentAudioPath = null;
        });
        _loadPassage().then((_) {
          if (isContinuousPlaying) {
            currentVerseIndex = 0;
            _playCurrentVerse();
          }
        });
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
          currentVerses = null;
          currentAudioPath = null;
        });
        _loadPassage().then((_) {
          if (isContinuousPlaying) {
            currentVerseIndex = 0;
            _playCurrentVerse();
          }
        });
      } else {
        // We've reached the end of the Bible
        setState(() {
          isContinuousPlaying = false;
          isPlaying = false;
        });
      }
    } else {
      setState(() {
        selectedChapter = newChapter;
        currentVerses = null;
        currentAudioPath = null;
      });
      _loadPassage().then((_) {
        if (isContinuousPlaying) {
          currentVerseIndex = 0;
          _playCurrentVerse();
        }
      });
    }
  }

  Widget _buildSelectorsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          if (availableBibles != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButton<String>(
                value: selectedBibleId,
                hint: const Text('Select Bible Translation'),
                isExpanded: true,
                items: availableBibles!.map((bible) {
                  return DropdownMenuItem<String>(
                    value: bible['id'],
                    child: Text(bible['nameLocal'] ?? bible['name']),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedBibleId = newValue;
                    _bibleService.setBibleId(newValue!);
                    currentVerses = null;
                    currentAudioPath = null;
                  });
                  _loadPassage();
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedBook,
                    hint: const Text('Select Book'),
                    items: BibleData.books.keys.map((String book) {
                      return DropdownMenuItem<String>(
                        value: book,
                        child: Text(book),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedBook = newValue;
                        selectedChapter = 1;
                        currentVerses = null;
                        currentAudioPath = null;
                      });
                      _loadPassage();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<int>(
                    value: selectedChapter,
                    hint: const Text('Select Chapter'),
                    items: selectedBook != null
                        ? List.generate(BibleData.books[selectedBook]!, (index) => index + 1)
                            .map((int chapter) {
                          return DropdownMenuItem<int>(
                            value: chapter,
                            child: Text('Chapter $chapter'),
                          );
                        }).toList()
                        : [],
                    onChanged: (int? newValue) {
                      setState(() {
                        selectedChapter = newValue;
                        currentAudioPath = null;
                      });
                      _loadPassage();
                    },
                  ),
                ),
              ],
            ),
          ),
          if (voices != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButton<Voice>(
                value: selectedVoice,
                hint: const Text('Select Voice'),
                isExpanded: true,
                items: voices!.map((Voice voice) {
                  return DropdownMenuItem<Voice>(
                    value: voice,
                    child: Text(voice.name),
                  );
                }).toList(),
                onChanged: (Voice? newValue) {
                  setState(() {
                    selectedVoice = newValue;
                    currentAudioPath = null;
                  });
                },
              ),
            ),
          // Add playback speed control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text('Playback Speed: '),
                Expanded(
                  child: Slider(
                    value: _playbackSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 6,
                    label: '${_playbackSpeed}x',
                    onChanged: (value) {
                      _changePlaybackSpeed(value);
                    },
                  ),
                ),
                Text('${_playbackSpeed}x'),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Update the verse reference popup method
  void _showVerseReference(String verseText, int index) {
    if (currentVerseData != null && index < currentVerseData!.length) {
      final verseData = currentVerseData![index];
      final reference = verseData['reference'] ?? '$selectedBook ${selectedChapter}:${index + 1}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reference),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

  // Update the verse list builder
  Widget _buildVerseList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        currentVerses!.length,
        (index) {
          final isCurrentVerse = index == currentVerseIndex && isPlaying;
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          final verseText = currentVerses![index];

          return GestureDetector(
            onTap: () => _showVerseReference(verseText, index),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              decoration: BoxDecoration(
                color: isCurrentVerse
                    ? (isDarkMode
                        ? Colors.blue.withOpacity(0.15)
                        : Theme.of(context).primaryColor.withOpacity(0.1))
                    : null,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
              ),
              child: Text(
                verseText,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.6,
                  letterSpacing: 0.3,
                  color: isCurrentVerse
                      ? (isDarkMode ? Colors.blue[300] : Theme.of(context).primaryColor)
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Codex Bible'),
        actions: [
          // Theme toggle button
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme();
            },
            tooltip: themeProvider.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
          // Play button
          if (currentVerses != null && currentVerses!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: _playPassage,
                tooltip: isPlaying ? 'Pause' : 'Play',
              ),
            ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              if (_panelController.isPanelOpen) {
                _panelController.close();
              } else {
                _panelController.open();
              }
            },
          ),
        ],
      ),
      body: SlidingUpPanel(
        controller: _panelController,
        minHeight: 0,
        maxHeight: 300,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
        panel: _buildSelectorsPanel(),
        body: Stack(
          children: [
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: currentVerses != null && currentVerses!.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48.0), // Add padding for the side buttons
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$selectedBook ${selectedChapter ?? ""}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildVerseList(),
                            // Add extra padding at the bottom to ensure last verse is visible
                            SizedBox(
                              height: MediaQuery.of(context).padding.bottom + 120,
                            ),
                          ],
                        ),
                      )
                    : const Center(
                        child: Text('Select a book and chapter to begin'),
                      ),
              ),
            if (!isLoading && currentVerses != null) ...[
              // Left arrow for previous chapter
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(2, 0),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () => _navigateChapter(-1),
                      tooltip: 'Previous Chapter',
                    ),
                  ),
                ),
              ),
              // Right arrow for next chapter
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(-2, 0),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () => _navigateChapter(1),
                      tooltip: 'Next Chapter',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: null,
    );
  }

  void _changePlaybackSpeed(double value) {
    setState(() {
      _playbackSpeed = value;
    });
  }
}
