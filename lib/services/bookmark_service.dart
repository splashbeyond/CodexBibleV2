import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkedVerse {
  final String book;
  final int chapter;
  final int verse;
  final String text;
  final DateTime timestamp;

  BookmarkedVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'book': book,
    'chapter': chapter,
    'verse': verse,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory BookmarkedVerse.fromJson(Map<String, dynamic> json) => BookmarkedVerse(
    book: json['book'],
    chapter: json['chapter'],
    verse: json['verse'],
    text: json['text'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class BookmarkService {
  static const String _bookmarksKey = 'bible_bookmarks';
  List<BookmarkedVerse> _bookmarks = [];
  
  Future<void> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? bookmarksJson = prefs.getString(_bookmarksKey);
    if (bookmarksJson != null) {
      final List<dynamic> decoded = json.decode(bookmarksJson);
      _bookmarks = decoded.map((item) => BookmarkedVerse.fromJson(item)).toList();
    }
  }

  Future<void> saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_bookmarks.map((b) => b.toJson()).toList());
    await prefs.setString(_bookmarksKey, encoded);
  }

  List<BookmarkedVerse> getBookmarks() {
    return List.unmodifiable(_bookmarks);
  }

  bool isVerseBookmarked(String book, int chapter, int verse) {
    return _bookmarks.any((b) => 
      b.book == book && b.chapter == chapter && b.verse == verse
    );
  }

  Future<void> toggleBookmark(String book, int chapter, int verse, String text) async {
    final isBookmarked = isVerseBookmarked(book, chapter, verse);
    
    if (isBookmarked) {
      _bookmarks.removeWhere((b) => 
        b.book == book && b.chapter == chapter && b.verse == verse
      );
    } else {
      _bookmarks.add(BookmarkedVerse(
        book: book,
        chapter: chapter,
        verse: verse,
        text: text,
        timestamp: DateTime.now(),
      ));
    }
    
    await saveBookmarks();
  }
} 