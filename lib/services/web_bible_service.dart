import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:math';

class WEBBibleService {
  static const String pdfPath = 'assets/CodexASVBible/WEBTEXT.pdf';
  Map<String, Map<int, List<String>>> _cachedVerses = {};
  late PdfDocument _pdfDocument;
  bool _isInitialized = false;

  Future<void> initializeCache() async {
    if (_isInitialized) return;

    try {
      final ByteData data = await rootBundle.load(pdfPath);
      final List<int> bytes = data.buffer.asUint8List();
      _pdfDocument = PdfDocument(inputBytes: bytes);
      _isInitialized = true;
      print('WEB Bible PDF loaded successfully');
    } catch (e) {
      print('Error initializing WEB Bible cache: $e');
      throw Exception('Failed to load WEB Bible PDF');
    }
  }

  Future<Map<String, dynamic>> getChapter(String book, int chapter) async {
    if (!_isInitialized) {
      await initializeCache();
    }

    try {
      // Check if we have cached verses for this chapter
      if (_cachedVerses[book]?[chapter] != null) {
        return {
          'verses': _cachedVerses[book]![chapter]!,
          'reference': '$book $chapter'
        };
      }

      // Extract text from PDF and parse verses
      final verses = await _extractVersesFromPdf(book, chapter);
      
      // Cache the verses
      _cachedVerses[book] ??= {};
      _cachedVerses[book]![chapter] = verses;

      return {
        'verses': verses,
        'reference': '$book $chapter'
      };
    } catch (e) {
      print('Error getting WEB chapter: $e');
      throw Exception('Failed to load WEB chapter');
    }
  }

  Future<List<String>> _extractVersesFromPdf(String book, int chapter) async {
    try {
      List<String> verses = [];
      String chapterPattern = '$book $chapter';
      bool foundChapter = false;
      bool inChapter = false;
      
      print('Searching for chapter pattern: $chapterPattern');
      print('Total pages in PDF: ${_pdfDocument.pages.count}');
      
      // First, find which page contains our chapter
      int targetPage = -1;
      for (int i = 0; i < _pdfDocument.pages.count && targetPage == -1; i++) {
        String pageText = PdfTextExtractor(_pdfDocument).extractText(startPageIndex: i, endPageIndex: i);
        if (pageText.contains(chapterPattern)) {
          targetPage = i;
          print('Found chapter on page ${i + 1}');
        }
      }
      
      if (targetPage == -1) {
        print('Chapter not found in PDF');
        return [];
      }
      
      // Extract text from the target page and the next page (in case chapter spans pages)
      for (int i = targetPage; i <= min(targetPage + 1, _pdfDocument.pages.count - 1); i++) {
        String pageText = PdfTextExtractor(_pdfDocument).extractText(startPageIndex: i, endPageIndex: i);
        List<String> lines = pageText.split('\n');
        
        for (String line in lines) {
          String trimmedLine = line.trim();
          
          // Check for chapter heading
          if (trimmedLine.startsWith(chapterPattern)) {
            print('Found chapter heading: $chapterPattern');
            foundChapter = true;
            inChapter = true;
            continue;
          }
          
          // Check for next chapter
          if (foundChapter && (
              trimmedLine.startsWith('$book ${chapter + 1}') ||
              trimmedLine.startsWith('${book.split(' ')[0]} ${chapter + 1}') // For books like "1 Kings"
          )) {
            print('Found next chapter, stopping extraction');
            inChapter = false;
            break;
          }
          
          // Extract verse if it starts with a number and we're in the right chapter
          if (inChapter) {
            // Updated regex to better handle verse numbers and clean the text
            RegExpMatch? match = RegExp(r'^(\d+)\s*(.+)$').firstMatch(trimmedLine);
            if (match != null) {
              String verseText = match.group(2) ?? '';
              if (verseText.isNotEmpty) {
                // Clean up the verse text by removing stray numbers and quotes
                verseText = verseText
                    .replaceAll(RegExp(r'\s+\d+\s*[""]\s*'), ' ') // Remove stray verse numbers with quotes
                    .replaceAll(RegExp(r'\s+\d+\s+(?=\w)'), ' ') // Remove stray numbers before words
                    .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
                    .trim();
                
                print('Adding verse ${match.group(1)}: ${verseText.substring(0, min(40, verseText.length))}...');
                verses.add(verseText);
              }
            }
          }
        }
      }
      
      print('Extracted ${verses.length} verses from $book $chapter');
      if (verses.isEmpty) {
        print('WARNING: No verses were extracted!');
      } else {
        print('First verse: ${verses[0]}');
        print('Last verse: ${verses[verses.length - 1]}');
      }
      return verses;
    } catch (e, stackTrace) {
      print('Error extracting verses from PDF: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  void dispose() {
    if (_isInitialized) {
      _pdfDocument.dispose();
    }
  }
} 