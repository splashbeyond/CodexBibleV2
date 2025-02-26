import 'package:flutter/services.dart';
import '../constants/bible_data.dart';

class LocalBibleService {
  static const String _baseTextPath = 'assets/CodexASVBible/WEBTEXT.txt';
  final Map<String, Map<int, List<String>>> _cache = {};

  List<String> getBooks() {
    return BibleData.books.keys.toList();
  }

  int getChapterCount(String book) {
    return BibleData.books[book] ?? 1;
  }

  String _getTestamentPath(String book) {
    final newTestamentBooks = {
      'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
      '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
      'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
      '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
      'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
      'Jude', 'Revelation'
    };
    return '$_baseTextPath/${newTestamentBooks.contains(book) ? 'New_Testament' : 'Old_Testament'}';
  }

  Future<Map<String, dynamic>> getChapter(String book, int chapter) async {
    try {
      print('Loading chapter: $book $chapter');
      
      // Check cache first
      if (_cache.containsKey(book) && _cache[book]!.containsKey(chapter)) {
        print('Returning cached chapter: $book $chapter');
        return {
          'verses': _cache[book]![chapter]!.map((text) => {'text': text}).toList()
        };
      }

      String content;
      // First try WEBTEXT.txt directory
      try {
        final bookForPath = book.replaceAll(' ', '_'); // Replace spaces with underscores for file path
        final webtextPath = '${_getTestamentPath(book)}/engwebp_${_getBookNumber(book)}_${_getBookAbbreviation(book)}_${chapter.toString().padLeft(2, '0')}_read.txt';
        print('Attempting to load from WEBTEXT: $webtextPath');
        content = await rootBundle.loadString(webtextPath);
      } catch (e) {
        // If not found, try the New/Old Testament directory
        final testament = _getTestamentPath(book).contains('New_Testament') ? 'New Testament' : 'Old Testament';
        final bookNum = _getBookNumber(book).padLeft(2, '0');
        final bookForPath = book.replaceAll(' ', '_'); // Replace spaces with underscores for file path
        final fileName = '${bookNum}_${bookForPath}_${chapter.toString().padLeft(2, '0')}.txt';
        final altPath = 'assets/CodexASVBible/$testament/$fileName';
        print('Attempting to load from alternate path: $altPath');
        content = await rootBundle.loadString(altPath);
      }
      
      print('File loaded successfully');

      // Split into lines and process
      final lines = content.split('\n');
      final verses = <String>[];
      int lineCount = 0;
      
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        
        // Skip the first two lines (book name and chapter)
        lineCount++;
        if (lineCount <= 2) continue;
        
        // Add the line as is (it already contains the verse text)
        verses.add(line);
      }

      // Cache the verses
      _cache[book] ??= {};
      _cache[book]![chapter] = verses;

      print('Processed ${verses.length} verses');
      return {
        'verses': verses.map((text) => {'text': text}).toList()
      };
    } catch (e) {
      print('Error loading chapter: $e');
      return {'verses': []};
    }
  }

  String _getBookNumber(String book) {
    final bookNumbers = {
      'Genesis': '002', 'Exodus': '003', 'Leviticus': '004', 'Numbers': '005', 'Deuteronomy': '006',
      'Joshua': '007', 'Judges': '008', 'Ruth': '009', '1 Samuel': '010', '2 Samuel': '011',
      '1 Kings': '012', '2 Kings': '013', '1 Chronicles': '014', '2 Chronicles': '015', 'Ezra': '016',
      'Nehemiah': '017', 'Esther': '018', 'Job': '019', 'Psalms': '020', 'Proverbs': '021',
      'Ecclesiastes': '022', 'Song of Solomon': '023', 'Isaiah': '024', 'Jeremiah': '025', 'Lamentations': '026',
      'Ezekiel': '027', 'Daniel': '028', 'Hosea': '029', 'Joel': '030', 'Amos': '031',
      'Obadiah': '032', 'Jonah': '033', 'Micah': '034', 'Nahum': '035', 'Habakkuk': '036',
      'Zephaniah': '037', 'Haggai': '038', 'Zechariah': '039', 'Malachi': '040',
      'Matthew': '070', 'Mark': '071', 'Luke': '072', 'John': '073', 'Acts': '074',
      'Romans': '075', '1 Corinthians': '076', '2 Corinthians': '077', 'Galatians': '078', 'Ephesians': '079',
      'Philippians': '080', 'Colossians': '081', '1 Thessalonians': '082', '2 Thessalonians': '083', '1 Timothy': '084',
      '2 Timothy': '085', 'Titus': '086', 'Philemon': '087', 'Hebrews': '088', 'James': '089',
      '1 Peter': '090', '2 Peter': '091', '1 John': '092', '2 John': '093', '3 John': '094',
      'Jude': '095', 'Revelation': '096'
    };
    return bookNumbers[book] ?? '002';
  }

  String _getBookAbbreviation(String book) {
    final bookAbbreviations = {
      'Genesis': 'GEN', 'Exodus': 'EXO', 'Leviticus': 'LEV', 'Numbers': 'NUM', 'Deuteronomy': 'DEU',
      'Joshua': 'JOS', 'Judges': 'JDG', 'Ruth': 'RUT', '1 Samuel': 'SA1', '2 Samuel': 'SA2',
      '1 Kings': 'KI1', '2 Kings': 'KI2', '1 Chronicles': 'CH1', '2 Chronicles': 'CH2', 'Ezra': 'EZR',
      'Nehemiah': 'NEH', 'Esther': 'EST', 'Job': 'JOB', 'Psalms': 'PSA', 'Proverbs': 'PRO',
      'Ecclesiastes': 'ECC', 'Song of Solomon': 'SNG', 'Isaiah': 'ISA', 'Jeremiah': 'JER', 'Lamentations': 'LAM',
      'Ezekiel': 'EZK', 'Daniel': 'DAN', 'Hosea': 'HOS', 'Joel': 'JOL', 'Amos': 'AMO',
      'Obadiah': 'OBA', 'Jonah': 'JON', 'Micah': 'MIC', 'Nahum': 'NAM', 'Habakkuk': 'HAB',
      'Zephaniah': 'ZEP', 'Haggai': 'HAG', 'Zechariah': 'ZEC', 'Malachi': 'MAL',
      'Matthew': 'MAT', 'Mark': 'MRK', 'Luke': 'LUK', 'John': 'JHN', 'Acts': 'ACT',
      'Romans': 'ROM', '1 Corinthians': '1CO', '2 Corinthians': '2CO', 'Galatians': 'GAL', 'Ephesians': 'EPH',
      'Philippians': 'PHP', 'Colossians': 'COL', '1 Thessalonians': '1TH', '2 Thessalonians': '2TH', '1 Timothy': '1TI',
      '2 Timothy': '2TI', 'Titus': 'TIT', 'Philemon': 'PHM', 'Hebrews': 'HEB', 'James': 'JAS',
      '1 Peter': '1PE', '2 Peter': '2PE', '1 John': '1JN', '2 John': '2JN', '3 John': '3JN',
      'Jude': 'JUD', 'Revelation': 'REV'
    };
    return bookAbbreviations[book] ?? 'GEN';
  }
} 