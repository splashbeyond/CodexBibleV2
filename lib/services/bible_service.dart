import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/bible_book.dart';

class BibleService {
  final String baseUrl = 'https://api.scripture.api.bible/v1';
  late final String _apiKey;
  String? _currentBibleId;

  BibleService() {
    _apiKey = dotenv.env['API_BIBLE_KEY'] ?? '';
  }

  void setBibleId(String bibleId) {
    print('Setting Bible ID to: $bibleId');
    _currentBibleId = bibleId;
  }

  Map<String, String> get _headers => {
        'api-key': _apiKey,
      };

  Future<Map<String, dynamic>> getChapter(String book, int chapter) async {
    try {
      final bookId = await _getBookId(book);
      if (bookId == null) {
        print('Book ID not found for: $book');
        return {'verses': []};
      }

      final chapterUrl = '$baseUrl/bibles/$_currentBibleId/chapters/$bookId.$chapter';
      print('Fetching chapter from URL: $chapterUrl');

      final response = await http.get(
        Uri.parse(chapterUrl),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['data']['content'] as String;

        // Clean and split the content into verses
        final cleanContent = _cleanHtml(content);
        final verses = cleanContent
            .split(RegExp(r'(?<=\.) (?=\w)'))
            .where((verse) => verse.trim().isNotEmpty)
            .map((verse) => {
              'text': verse.trim()
                  .replaceAll(RegExp(r'^\d+\s*'), '') // Remove leading numbers
                  .replaceAll(RegExp(r'\s*\d+\s*(?=\w)'), ' ') // Remove numbers before words
                  .trim()
            })
            .toList();

        print('Processed ${verses.length} verses');
        return {'verses': verses};
      } else {
        print('Failed to fetch chapter. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return {'verses': []};
      }
    } catch (e) {
      print('Error in getChapter: $e');
      return {'verses': []};
    }
  }

  String _cleanHtml(String content) {
    // Remove verse numbers and HTML tags
    content = content
        .replaceAll(RegExp(r'<sup[^>]*>\d+</sup>'), '') // Remove verse numbers in sup tags
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove all HTML tags
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('¶', '')
        .replaceAll(RegExp(r'^\d+\s*'), '') // Remove verse numbers at start of text
        .replaceAll(RegExp(r'\s*\d+\s*(?=\w)'), ' ') // Remove verse numbers before words
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
        .trim();
    return content;
  }

  String _normalizeBookName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<String> getPassage(String reference) async {
    if (_currentBibleId == null) {
      throw Exception('Bible ID not set');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bibles/$_currentBibleId/passages/$reference'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']['content'];
      } else {
        throw Exception('Failed to load passage');
      }
    } catch (e) {
      throw Exception('Failed to load passage: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableBibles() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bibles'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to load available Bibles');
      }

      final data = json.decode(response.body);
      final bibles = List<Map<String, dynamic>>.from(data['data']);

      // Sort bibles to prioritize English versions
      bibles.sort((a, b) {
        final aIsEnglish = (a['language']?['name'] ?? '').toLowerCase().contains('english');
        final bIsEnglish = (b['language']?['name'] ?? '').toLowerCase().contains('english');

        if (aIsEnglish && !bIsEnglish) return -1;
        if (!aIsEnglish && bIsEnglish) return 1;
        return 0;
      });

      print('Found ${bibles.length} Bibles');
      return bibles;
    } catch (e) {
      print('Error loading Bibles: $e');
      throw Exception('Failed to load available Bibles: $e');
    }
  }

  Future<String?> _getBookId(String book) async {
    try {
      print('Fetching book ID for: $book');
      final response = await http.get(
        Uri.parse('$baseUrl/bibles/$_currentBibleId/books'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        print('Failed to fetch books. Status code: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final books = data['data'] as List;
      print('Available books: ${books.map((b) => '${b['name']} (${b['id']})').join(', ')}');

      final bookData = books.firstWhere(
        (b) => _normalizeBookName(b['name']?.toString() ?? '') == _normalizeBookName(book) ||
               _normalizeBookName(b['nameLong']?.toString() ?? '') == _normalizeBookName(book) ||
               _normalizeBookName(b['abbreviation']?.toString() ?? '') == _normalizeBookName(book),
        orElse: () => null,
      );

      if (bookData != null) {
        final bookId = bookData['id'];
        print('Found book ID: $bookId for book: $book');
        return bookId;
      }
      return null;
    } catch (e) {
      print('Error in _getBookId: $e');
      return null;
    }
  }
}
