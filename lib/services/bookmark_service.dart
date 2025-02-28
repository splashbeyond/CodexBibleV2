import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    timestamp: json['timestamp'] is Timestamp 
      ? (json['timestamp'] as Timestamp).toDate()
      : DateTime.parse(json['timestamp']),
  );
}

class BookmarkService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<BookmarkedVerse> _bookmarks = [];
  
  // Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  Future<void> loadBookmarks() async {
    try {
      print('Loading bookmarks...');
      if (!isAuthenticated) {
        print('User not authenticated, clearing bookmarks');
        _bookmarks = [];
        return;
      }

      final userId = _auth.currentUser!.uid;
      print('Loading bookmarks for user: $userId');
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .orderBy('timestamp', descending: true)
          .get();

      print('Received ${snapshot.docs.length} bookmarks from Firestore');

      _bookmarks = snapshot.docs
          .map((doc) {
            try {
              return BookmarkedVerse.fromJson(doc.data());
            } catch (e) {
              print('Error parsing bookmark: $e');
              return null;
            }
          })
          .where((bookmark) => bookmark != null)
          .cast<BookmarkedVerse>()
          .toList();

      print('Successfully loaded ${_bookmarks.length} bookmarks');
    } catch (e) {
      print('Error loading bookmarks: $e');
      // If there's a permission error, clear the bookmarks
      if (e.toString().contains('permission-denied')) {
        _bookmarks = [];
      }
      rethrow;
    }
  }

  Future<void> saveBookmarks() async {
    try {
      print('Saving bookmarks...');
      if (!isAuthenticated) {
        print('User not authenticated, cannot save bookmarks');
        throw Exception('User must be signed in to save bookmarks');
      }

      final userId = _auth.currentUser!.uid;
      print('Saving bookmarks for user: $userId');
      
      // Create user document if it doesn't exist
      final userRef = _firestore.collection('users').doc(userId);
      await userRef.set({
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Get all existing bookmarks
      final existingBookmarks = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .get();
      
      final batch = _firestore.batch();
      
      // Delete all existing bookmarks
      for (var doc in existingBookmarks.docs) {
        batch.delete(doc.reference);
      }

      // Add new bookmarks
      for (var bookmark in _bookmarks) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('bookmarks')
            .doc();
        batch.set(docRef, {
          ...bookmark.toJson(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('Successfully saved ${_bookmarks.length} bookmarks');
    } catch (e) {
      print('Error saving bookmarks: $e');
      rethrow;
    }
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
    try {
      print('Toggling bookmark for $book $chapter:$verse');
      if (!isAuthenticated) {
        print('User not authenticated, cannot toggle bookmark');
        throw Exception('User must be signed in to bookmark verses');
      }

      final isBookmarked = isVerseBookmarked(book, chapter, verse);
      print('Verse is currently bookmarked: $isBookmarked');
      
      if (isBookmarked) {
        _bookmarks.removeWhere((b) => 
          b.book == book && b.chapter == chapter && b.verse == verse
        );
        print('Removed bookmark');
      } else {
        _bookmarks.add(BookmarkedVerse(
          book: book,
          chapter: chapter,
          verse: verse,
          text: text,
          timestamp: DateTime.now(),
        ));
        print('Added bookmark');
      }
      
      // Save changes immediately
      await saveBookmarks();
      print('Successfully saved bookmark changes');
    } catch (e) {
      print('Error toggling bookmark: $e');
      // Reload bookmarks to ensure consistency
      await loadBookmarks();
      rethrow;
    }
  }

  // Listen to authentication state changes
  void setupAuthListener() {
    print('Setting up auth listener');
    _auth.authStateChanges().listen((User? user) async {
      if (user == null) {
        print('User signed out, clearing bookmarks');
        _bookmarks = [];
      } else {
        print('User signed in, loading their bookmarks');
        try {
          await loadBookmarks();
        } catch (e) {
          print('Error in auth listener: $e');
          _bookmarks = [];
        }
      }
    });
  }
} 