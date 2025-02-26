import 'dart:async';
import 'package:flutter/services.dart';
import '../constants/bible_data.dart';

class WEBBibleService {
  static const String _baseTextPath = 'assets/CodexASVBible/WEBTEXT.txt';
  Map<String, Map<int, List<String>>> _cache = {};
  bool _isInitialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  WEBBibleService() {
    _initialize();
  }

  Future<void> waitForInitialization() async {
    if (_isInitialized) return;
    await _initCompleter.future;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      print('Initializing Bible service...');
      _isInitialized = true;
      _initCompleter.complete();
    } catch (e) {
      print('Error initializing Bible service: $e');
      _initCompleter.completeError(e);
      throw Exception('Failed to initialize Bible service: $e');
    }
  }

  String _getBookNumber(String book) {
    // Map book names to their corresponding numbers in the file naming convention
    final Map<String, String> bookNumbers = {
      'Genesis': '001', 'Exodus': '002', 'Leviticus': '003', 'Numbers': '004',
      'Deuteronomy': '005', 'Joshua': '006', 'Judges': '007', 'Ruth': '008',
      '1 Samuel': '009', '2 Samuel': '010', '1 Kings': '011', '2 Kings': '012',
      '1 Chronicles': '013', '2 Chronicles': '014', 'Ezra': '015', 'Nehemiah': '016',
      'Esther': '017', 'Job': '018', 'Psalms': '019', 'Proverbs': '020',
      'Ecclesiastes': '021', 'Song of Solomon': '022', 'Isaiah': '023', 'Jeremiah': '024',
      'Lamentations': '025', 'Ezekiel': '026', 'Daniel': '027', 'Hosea': '028',
      'Joel': '029', 'Amos': '030', 'Obadiah': '031', 'Jonah': '032',
      'Micah': '033', 'Nahum': '034', 'Habakkuk': '035', 'Zephaniah': '036',
      'Haggai': '037', 'Zechariah': '038', 'Malachi': '039', 'Matthew': '040',
      'Mark': '041', 'Luke': '042', 'John': '043', 'Acts': '044',
      'Romans': '045', '1 Corinthians': '046', '2 Corinthians': '047', 'Galatians': '048',
      'Ephesians': '049', 'Philippians': '050', 'Colossians': '051', '1 Thessalonians': '052',
      '2 Thessalonians': '053', '1 Timothy': '054', '2 Timothy': '055', 'Titus': '056',
      'Philemon': '057', 'Hebrews': '058', 'James': '059', '1 Peter': '060',
      '2 Peter': '061', '1 John': '062', '2 John': '063', '3 John': '064',
      'Jude': '065', 'Revelation': '066'
    };
    return bookNumbers[book] ?? '001';
  }

  String _getBookAbbreviation(String book) {
    // Map book names to their corresponding abbreviations in the file naming convention
    final Map<String, String> bookAbbreviations = {
      'Genesis': 'GEN', 'Exodus': 'EXO', 'Leviticus': 'LEV', 'Numbers': 'NUM',
      'Deuteronomy': 'DEU', 'Joshua': 'JOS', 'Judges': 'JDG', 'Ruth': 'RUT',
      '1 Samuel': '1SA', '2 Samuel': '2SA', '1 Kings': '1KI', '2 Kings': '2KI',
      '1 Chronicles': '1CH', '2 Chronicles': '2CH', 'Ezra': 'EZR', 'Nehemiah': 'NEH',
      'Esther': 'EST', 'Job': 'JOB', 'Psalms': 'PSA', 'Proverbs': 'PRO',
      'Ecclesiastes': 'ECC', 'Song of Solomon': 'SNG', 'Isaiah': 'ISA', 'Jeremiah': 'JER',
      'Lamentations': 'LAM', 'Ezekiel': 'EZK', 'Daniel': 'DAN', 'Hosea': 'HOS',
      'Joel': 'JOL', 'Amos': 'AMO', 'Obadiah': 'OBA', 'Jonah': 'JON',
      'Micah': 'MIC', 'Nahum': 'NAM', 'Habakkuk': 'HAB', 'Zephaniah': 'ZEP',
      'Haggai': 'HAG', 'Zechariah': 'ZEC', 'Malachi': 'MAL', 'Matthew': 'MAT',
      'Mark': 'MRK', 'Luke': 'LUK', 'John': 'JHN', 'Acts': 'ACT',
      'Romans': 'ROM', '1 Corinthians': '1CO', '2 Corinthians': '2CO', 'Galatians': 'GAL',
      'Ephesians': 'EPH', 'Philippians': 'PHP', 'Colossians': 'COL', '1 Thessalonians': '1TH',
      '2 Thessalonians': '2TH', '1 Timothy': '1TI', '2 Timothy': '2TI', 'Titus': 'TIT',
      'Philemon': 'PHM', 'Hebrews': 'HEB', 'James': 'JAS', '1 Peter': '1PE',
      '2 Peter': '2PE', '1 John': '1JN', '2 John': '2JN', '3 John': '3JN',
      'Jude': 'JUD', 'Revelation': 'REV'
    };
    return bookAbbreviations[book] ?? 'GEN';
  }

  Future<List<String>> getChapter(String book, int chapter) async {
    print('Getting $book chapter $chapter');
    
    if (!_isInitialized) {
      print('Waiting for initialization...');
      await waitForInitialization();
    }

    // Check cache first
    if (_cache.containsKey(book) && _cache[book]!.containsKey(chapter)) {
      print('Returning cached verses for $book $chapter');
      return _cache[book]![chapter]!;
    }

    try {
      final bookNumber = _getBookNumber(book);
      final bookAbbrev = _getBookAbbreviation(book);
      final chapterStr = chapter.toString().padLeft(2, '0');
      final filePath = '$_baseTextPath/engwebp_${bookNumber}_${bookAbbrev}_${chapterStr}_read.txt';
      
      print('Loading file: $filePath');
      final String text = await rootBundle.loadString(filePath);
      
      if (text.isEmpty) {
        print('Chapter file is empty: $book $chapter');
        return [];
      }

      final verses = _parseVerses(text);
      
      // Cache the verses
      _cache.putIfAbsent(book, () => {});
      _cache[book]![chapter] = verses;

      print('Parsed ${verses.length} verses from $book $chapter');
      return verses;
    } catch (e) {
      print('Error getting chapter: $e');
      return [];
    }
  }

  List<String> _parseVerses(String chapterText) {
    List<String> verses = [];
    try {
      // Split into lines and remove header lines
      final lines = chapterText.split('\n');
      var startIndex = 0;
      
      // Skip header lines (book name and chapter number)
      while (startIndex < lines.length && 
             (lines[startIndex].contains('Chapter') || 
              lines[startIndex].trim().isEmpty ||
              lines[startIndex].contains('Letter') ||
              lines[startIndex].contains('Gospel') ||
              lines[startIndex].contains('Book'))) {
        startIndex++;
      }
      
      // Process remaining lines as verses
      for (int i = startIndex; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          verses.add(line);
        }
      }
    } catch (e) {
      print('Error parsing verses: $e');
    }
    return verses;
  }

  List<String> getBooks() {
    return BibleData.books.keys.toList();
  }

  int getChapterCount(String book) {
    return BibleData.books[book] ?? 1;
  }

  void dispose() {
    _isInitialized = false;
    _cache.clear();
  }
} 