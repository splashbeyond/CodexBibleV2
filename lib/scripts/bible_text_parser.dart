import 'dart:io';

class BibleTextParser {
  static const String sourceDir = 'assets/source_text';
  
  // Parse a raw text file and extract verses
  static Future<List<String>> parseChapterText(String rawText) async {
    final List<String> verses = [];
    final lines = rawText.split('\n');
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Skip header lines that contain book name or chapter info
      if (line.contains('Chapter') || line.contains('Book of')) continue;
      
      // Extract verse number and text
      final match = RegExp(r'^(\d+)\.\s*(.+)$').firstMatch(line);
      if (match != null) {
        final verseNum = int.parse(match.group(1)!);
        final verseText = match.group(2)!.trim();
        verses.add('$verseNum. $verseText');
      }
    }
    
    return verses;
  }

  // Format a verse to ensure consistent style
  static String formatVerse(String verse) {
    // Replace common substitutions
    verse = verse.replaceAll('Yahweh', 'LORD');
    verse = verse.replaceAll('  ', ' '); // Remove double spaces
    
    return verse.trim();
  }

  // Process an entire book
  static Future<Map<int, List<String>>> processBook(String bookPath) async {
    final Map<int, List<String>> chapters = {};
    final file = File(bookPath);
    
    if (await file.exists()) {
      final content = await file.readAsString();
      final chapterTexts = content.split(RegExp(r'Chapter \d+'));
      
      for (var i = 1; i < chapterTexts.length; i++) {
        final verses = await parseChapterText(chapterTexts[i]);
        if (verses.isNotEmpty) {
          chapters[i] = verses.map(formatVerse).toList();
        }
      }
    }
    
    return chapters;
  }
}

// Helper function to write verses to a file
Future<void> writeVersesToFile(String filePath, List<String> verses) async {
  final file = File(filePath);
  await file.writeAsString(verses.join('\n'));
}

// Example usage:
void main() async {
  // Example of processing a book
  final bookPath = '$sourceDir/genesis.txt';
  final chapters = await BibleTextParser.processBook(bookPath);
  
  // Example of writing a chapter to a file
  if (chapters.containsKey(1)) {
    final outputPath = 'assets/CodexASVBible/WEBTEXT.txt/Old_Testament/engwebp_002_GEN_01_read.txt';
    await writeVersesToFile(outputPath, chapters[1]!);
  }
} 