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
        currentVerses = null;
      });

      final response = await _bibleService.getChapter(selectedBook!, selectedChapter!);
      if (response['verses'].isNotEmpty) {
        final verses = List<Map<String, dynamic>>.from(response['verses']);
        final List<String> verseTexts = verses.map((verse) => verse['text'].toString().trim()).toList();

        setState(() {
          currentVerses = verseTexts;
          currentVerseData = verses;
          isLoading = false;
        });
      } else {
        setState(() {
          currentVerses = [];
          currentVerseData = [];
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Codex Bible'),
        actions: [
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: themeProvider.toggleTheme,
          ),
          _buildSpeedControl(),
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _playPassage,
          ),
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
        maxHeight: MediaQuery.of(context).size.height * 0.6,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
        panel: _buildSelectorsPanel(),
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: Column(
                key: ValueKey('$selectedBook$selectedChapter'),
                children: [
                  if (isLoading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    Expanded(
                      child: CustomScrollView(
                        key: PageStorageKey('$selectedBook$selectedChapter'),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.grey[100],
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
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (currentVerses == null || index >= currentVerses!.length) {
                                  return null;
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 8.0),
                                  decoration: BoxDecoration(
                                    color: currentVerseIndex == index
                                        ? (Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.black.withOpacity(0.1))
                                        : null,
                                  ),
                                  child: Text(
                                    currentVerses![index].replaceAll(RegExp(r'^\d+\.\s*'), ''),
                                    style: TextStyle(
                                      fontSize: 18,
                                      height: 1.5,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                );
                              },
                              childCount: currentVerses?.length ?? 0,
                            ),
                          ),
                          // Add bottom padding
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: MediaQuery.of(context).padding.bottom + 100,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
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
      ),
    );
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
      child: SingleChildScrollView(
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
                      isExpanded: true,
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
                      isExpanded: true,
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
                    });
                  },
                ),
              ),
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
      ),
    );
  }

  Widget _buildSpeedControl() {
    return PopupMenuButton<double>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.speed),
          const SizedBox(width: 4),
          Text('${_playbackSpeed}x'),
        ],
      ),
      onSelected: _changePlaybackSpeed,
      itemBuilder: (BuildContext context) {
        return [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
          return PopupMenuItem<double>(
            value: speed,
            child: Text('${speed}x'),
          );
        }).toList();
      },
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
        setState(() {
          selectedBook = previousBook;
          selectedChapter = BibleData.books[previousBook];
          currentVerses = null;
        });
        await _loadPassage();
        if (isContinuousPlaying) {
          currentVerseIndex = 0;
          _playCurrentVerse();
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
          currentVerses = null;
        });
        await _loadPassage();
        if (isContinuousPlaying) {
          currentVerseIndex = 0;
          _playCurrentVerse();
        }
      } else {
        setState(() {
          isContinuousPlaying = false;
          isPlaying = false;
        });
      }
    } else {
      setState(() {
        selectedChapter = newChapter;
        currentVerses = null;
      });
      await _loadPassage();
      if (isContinuousPlaying) {
        currentVerseIndex = 0;
        _playCurrentVerse();
      }
    }
  }

  void _changePlaybackSpeed(double value) {
    setState(() {
      _playbackSpeed = value;
    });
  }

  void _showSettings() {
    // Implementation of _showSettings method
    // This method should handle the settings dialog
    // For now, we'll just print a message
    print('Settings button pressed');
  }
}
