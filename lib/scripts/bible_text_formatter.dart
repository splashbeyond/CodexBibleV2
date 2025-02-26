import 'dart:io';

void main() async {
  final formatter = BibleTextFormatter();
  await formatter.processAllBooks();
}

class BibleTextFormatter {
  static const String baseDir = 'assets/CodexASVBible/WEBTEXT.txt';

  Future<void> processAllBooks() async {
    for (final book in allBooks) {
      print('Processing ${book.name}...');
      
      for (int chapter = 1; chapter <= book.chapters; chapter++) {
        final chapterStr = chapter.toString().padLeft(2, '0');
        final fileName = 'engwebp_${book.number}_${book.abbreviation}_${chapterStr}_read.txt';
        final filePath = '$baseDir/${book.testament}/$fileName';
        
        await processFile(filePath, book.name, chapter);
      }
    }
    print('All books processed!');
  }

  Future<void> processFile(String filePath, String bookName, int chapter) async {
    final file = File(filePath);
    if (!await file.exists()) {
      print('File not found: $filePath');
      return;
    }

    try {
      // Read the file content
      String content = await file.readAsString();
      
      // Split into lines and process
      List<String> lines = content.split('\n');
      List<String> processedLines = [];
      
      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        
        // Skip header lines
        if (line.contains('Chapter') || 
            line.contains('Book of') || 
            line.contains('Testament') ||
            line.contains('Commonly Called')) {
          continue;
        }
        
        // Format the line
        line = formatLine(line);
        if (line.isNotEmpty) {
          processedLines.add(line);
        }
      }
      
      // Write back to file if changes were made
      if (processedLines.isNotEmpty) {
        await file.writeAsString(processedLines.join('\n'));
        print('Updated $bookName chapter $chapter');
      }
    } catch (e) {
      print('Error processing $filePath: $e');
    }
  }

  String formatLine(String line) {
    // Remove any headers or extra formatting
    line = line.trim();
    
    // Replace "Yahweh" with "LORD"
    line = line.replaceAll('Yahweh', 'LORD');
    
    // Clean up spacing
    line = line.replaceAll('  ', ' ');
    
    // If line doesn't start with a verse number, try to extract it
    if (!RegExp(r'^\d+\.').hasMatch(line)) {
      final match = RegExp(r'^(\d+)(.+)$').firstMatch(line);
      if (match != null) {
        final number = match.group(1);
        final text = match.group(2)?.trim();
        line = '$number. $text';
      }
    }
    
    return line;
  }
}

// Include the BibleBook class and allBooks list from bible_file_generator.dart
class BibleBook {
  final String name;
  final String number;
  final String abbreviation;
  final int chapters;
  final String testament;

  BibleBook({
    required this.name,
    required this.number,
    required this.abbreviation,
    required this.chapters,
    required this.testament,
  });
}

// Complete book data
final List<BibleBook> allBooks = [
  // Old Testament
  BibleBook(name: 'Genesis', number: '002', abbreviation: 'GEN', chapters: 50, testament: 'Old_Testament'),
  BibleBook(name: 'Exodus', number: '003', abbreviation: 'EXO', chapters: 40, testament: 'Old_Testament'),
  BibleBook(name: 'Leviticus', number: '004', abbreviation: 'LEV', chapters: 27, testament: 'Old_Testament'),
  BibleBook(name: 'Numbers', number: '005', abbreviation: 'NUM', chapters: 36, testament: 'Old_Testament'),
  BibleBook(name: 'Deuteronomy', number: '006', abbreviation: 'DEU', chapters: 34, testament: 'Old_Testament'),
  BibleBook(name: 'Joshua', number: '007', abbreviation: 'JOS', chapters: 24, testament: 'Old_Testament'),
  BibleBook(name: 'Judges', number: '008', abbreviation: 'JDG', chapters: 21, testament: 'Old_Testament'),
  BibleBook(name: 'Ruth', number: '009', abbreviation: 'RUT', chapters: 4, testament: 'Old_Testament'),
  BibleBook(name: '1 Samuel', number: '010', abbreviation: 'SA1', chapters: 31, testament: 'Old_Testament'),
  BibleBook(name: '2 Samuel', number: '011', abbreviation: 'SA2', chapters: 24, testament: 'Old_Testament'),
  BibleBook(name: '1 Kings', number: '012', abbreviation: 'KI1', chapters: 22, testament: 'Old_Testament'),
  BibleBook(name: '2 Kings', number: '013', abbreviation: 'KI2', chapters: 25, testament: 'Old_Testament'),
  BibleBook(name: '1 Chronicles', number: '014', abbreviation: 'CH1', chapters: 29, testament: 'Old_Testament'),
  BibleBook(name: '2 Chronicles', number: '015', abbreviation: 'CH2', chapters: 36, testament: 'Old_Testament'),
  BibleBook(name: 'Ezra', number: '016', abbreviation: 'EZR', chapters: 10, testament: 'Old_Testament'),
  BibleBook(name: 'Nehemiah', number: '017', abbreviation: 'NEH', chapters: 13, testament: 'Old_Testament'),
  BibleBook(name: 'Esther', number: '018', abbreviation: 'EST', chapters: 10, testament: 'Old_Testament'),
  BibleBook(name: 'Job', number: '019', abbreviation: 'JOB', chapters: 42, testament: 'Old_Testament'),
  BibleBook(name: 'Psalms', number: '020', abbreviation: 'PSA', chapters: 150, testament: 'Old_Testament'),
  BibleBook(name: 'Proverbs', number: '021', abbreviation: 'PRO', chapters: 31, testament: 'Old_Testament'),
  BibleBook(name: 'Ecclesiastes', number: '022', abbreviation: 'ECC', chapters: 12, testament: 'Old_Testament'),
  BibleBook(name: 'Song of Solomon', number: '023', abbreviation: 'SNG', chapters: 8, testament: 'Old_Testament'),
  BibleBook(name: 'Isaiah', number: '024', abbreviation: 'ISA', chapters: 66, testament: 'Old_Testament'),
  BibleBook(name: 'Jeremiah', number: '025', abbreviation: 'JER', chapters: 52, testament: 'Old_Testament'),
  BibleBook(name: 'Lamentations', number: '026', abbreviation: 'LAM', chapters: 5, testament: 'Old_Testament'),
  BibleBook(name: 'Ezekiel', number: '027', abbreviation: 'EZK', chapters: 48, testament: 'Old_Testament'),
  BibleBook(name: 'Daniel', number: '028', abbreviation: 'DAN', chapters: 12, testament: 'Old_Testament'),
  BibleBook(name: 'Hosea', number: '029', abbreviation: 'HOS', chapters: 14, testament: 'Old_Testament'),
  BibleBook(name: 'Joel', number: '030', abbreviation: 'JOL', chapters: 3, testament: 'Old_Testament'),
  BibleBook(name: 'Amos', number: '031', abbreviation: 'AMO', chapters: 9, testament: 'Old_Testament'),
  BibleBook(name: 'Obadiah', number: '032', abbreviation: 'OBA', chapters: 1, testament: 'Old_Testament'),
  BibleBook(name: 'Jonah', number: '033', abbreviation: 'JON', chapters: 4, testament: 'Old_Testament'),
  BibleBook(name: 'Micah', number: '034', abbreviation: 'MIC', chapters: 7, testament: 'Old_Testament'),
  BibleBook(name: 'Nahum', number: '035', abbreviation: 'NAM', chapters: 3, testament: 'Old_Testament'),
  BibleBook(name: 'Habakkuk', number: '036', abbreviation: 'HAB', chapters: 3, testament: 'Old_Testament'),
  BibleBook(name: 'Zephaniah', number: '037', abbreviation: 'ZEP', chapters: 3, testament: 'Old_Testament'),
  BibleBook(name: 'Haggai', number: '038', abbreviation: 'HAG', chapters: 2, testament: 'Old_Testament'),
  BibleBook(name: 'Zechariah', number: '039', abbreviation: 'ZEC', chapters: 14, testament: 'Old_Testament'),
  BibleBook(name: 'Malachi', number: '040', abbreviation: 'MAL', chapters: 4, testament: 'Old_Testament'),
  
  // New Testament
  BibleBook(name: 'Matthew', number: '041', abbreviation: 'MAT', chapters: 28, testament: 'New_Testament'),
  BibleBook(name: 'Mark', number: '042', abbreviation: 'MRK', chapters: 16, testament: 'New_Testament'),
  BibleBook(name: 'Luke', number: '043', abbreviation: 'LUK', chapters: 24, testament: 'New_Testament'),
  BibleBook(name: 'John', number: '044', abbreviation: 'JHN', chapters: 21, testament: 'New_Testament'),
  BibleBook(name: 'Acts', number: '045', abbreviation: 'ACT', chapters: 28, testament: 'New_Testament'),
  BibleBook(name: 'Romans', number: '046', abbreviation: 'ROM', chapters: 16, testament: 'New_Testament'),
  BibleBook(name: '1 Corinthians', number: '047', abbreviation: 'CO1', chapters: 16, testament: 'New_Testament'),
  BibleBook(name: '2 Corinthians', number: '048', abbreviation: 'CO2', chapters: 13, testament: 'New_Testament'),
  BibleBook(name: 'Galatians', number: '049', abbreviation: 'GAL', chapters: 6, testament: 'New_Testament'),
  BibleBook(name: 'Ephesians', number: '050', abbreviation: 'EPH', chapters: 6, testament: 'New_Testament'),
  BibleBook(name: 'Philippians', number: '051', abbreviation: 'PHP', chapters: 4, testament: 'New_Testament'),
  BibleBook(name: 'Colossians', number: '052', abbreviation: 'COL', chapters: 4, testament: 'New_Testament'),
  BibleBook(name: '1 Thessalonians', number: '053', abbreviation: 'TH1', chapters: 5, testament: 'New_Testament'),
  BibleBook(name: '2 Thessalonians', number: '054', abbreviation: 'TH2', chapters: 3, testament: 'New_Testament'),
  BibleBook(name: '1 Timothy', number: '055', abbreviation: 'TI1', chapters: 6, testament: 'New_Testament'),
  BibleBook(name: '2 Timothy', number: '056', abbreviation: 'TI2', chapters: 4, testament: 'New_Testament'),
  BibleBook(name: 'Titus', number: '057', abbreviation: 'TIT', chapters: 3, testament: 'New_Testament'),
  BibleBook(name: 'Philemon', number: '058', abbreviation: 'PHM', chapters: 1, testament: 'New_Testament'),
  BibleBook(name: 'Hebrews', number: '059', abbreviation: 'HEB', chapters: 13, testament: 'New_Testament'),
  BibleBook(name: 'James', number: '060', abbreviation: 'JAS', chapters: 5, testament: 'New_Testament'),
  BibleBook(name: '1 Peter', number: '061', abbreviation: 'PE1', chapters: 5, testament: 'New_Testament'),
  BibleBook(name: '2 Peter', number: '062', abbreviation: 'PE2', chapters: 3, testament: 'New_Testament'),
  BibleBook(name: '1 John', number: '063', abbreviation: 'JN1', chapters: 5, testament: 'New_Testament'),
  BibleBook(name: '2 John', number: '064', abbreviation: 'JN2', chapters: 1, testament: 'New_Testament'),
  BibleBook(name: '3 John', number: '065', abbreviation: 'JN3', chapters: 1, testament: 'New_Testament'),
  BibleBook(name: 'Jude', number: '066', abbreviation: 'JUD', chapters: 1, testament: 'New_Testament'),
  BibleBook(name: 'Revelation', number: '067', abbreviation: 'REV', chapters: 22, testament: 'New_Testament'),
]; 