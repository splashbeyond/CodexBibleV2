import 'dart:io';

void main() async {
  final copier = BibleFileCopier();
  await copier.organizeFiles();
}

class BibleFileCopier {
  static const String sourceOldTestament = 'assets/CodexASVBible/Old Testament';
  static const String sourceNewTestament = 'assets/CodexASVBible/New Testament';
  static const String targetBase = 'assets/CodexASVBible/WEBTEXT.txt';

  final Map<String, String> bookNumbers = {
    'Genesis': '002', 'Exodus': '003', 'Leviticus': '004', 'Numbers': '005', 'Deuteronomy': '006',
    'Joshua': '007', 'Judges': '008', 'Ruth': '009', '1_Samuel': '010', '2_Samuel': '011',
    '1_Kings': '012', '2_Kings': '013', '1_Chronicles': '014', '2_Chronicles': '015', 'Ezra': '016',
    'Nehemiah': '017', 'Esther': '018', 'Job': '019', 'Psalms': '020', 'Proverbs': '021',
    'Ecclesiastes': '022', 'Song_of_Solomon': '023', 'Isaiah': '024', 'Jeremiah': '025', 'Lamentations': '026',
    'Ezekiel': '027', 'Daniel': '028', 'Hosea': '029', 'Joel': '030', 'Amos': '031',
    'Obadiah': '032', 'Jonah': '033', 'Micah': '034', 'Nahum': '035', 'Habakkuk': '036',
    'Zephaniah': '037', 'Haggai': '038', 'Zechariah': '039', 'Malachi': '040',
    'Matthew': '041', 'Mark': '042', 'Luke': '043', 'John': '044', 'Acts': '045',
    'Romans': '046', '1_Corinthians': '047', '2_Corinthians': '048', 'Galatians': '049', 'Ephesians': '050',
    'Philippians': '051', 'Colossians': '052', '1_Thessalonians': '053', '2_Thessalonians': '054', '1_Timothy': '055',
    '2_Timothy': '056', 'Titus': '057', 'Philemon': '058', 'Hebrews': '059', 'James': '060',
    '1_Peter': '061', '2_Peter': '062', '1_John': '063', '2_John': '064', '3_John': '065',
    'Jude': '066', 'Revelation': '067'
  };

  final Map<String, String> bookAbbreviations = {
    'Genesis': 'GEN', 'Exodus': 'EXO', 'Leviticus': 'LEV', 'Numbers': 'NUM', 'Deuteronomy': 'DEU',
    'Joshua': 'JOS', 'Judges': 'JDG', 'Ruth': 'RUT', '1_Samuel': 'SA1', '2_Samuel': 'SA2',
    '1_Kings': 'KI1', '2_Kings': 'KI2', '1_Chronicles': 'CH1', '2_Chronicles': 'CH2', 'Ezra': 'EZR',
    'Nehemiah': 'NEH', 'Esther': 'EST', 'Job': 'JOB', 'Psalms': 'PSA', 'Proverbs': 'PRO',
    'Ecclesiastes': 'ECC', 'Song_of_Solomon': 'SNG', 'Isaiah': 'ISA', 'Jeremiah': 'JER', 'Lamentations': 'LAM',
    'Ezekiel': 'EZK', 'Daniel': 'DAN', 'Hosea': 'HOS', 'Joel': 'JOL', 'Amos': 'AMO',
    'Obadiah': 'OBA', 'Jonah': 'JON', 'Micah': 'MIC', 'Nahum': 'NAM', 'Habakkuk': 'HAB',
    'Zephaniah': 'ZEP', 'Haggai': 'HAG', 'Zechariah': 'ZEC', 'Malachi': 'MAL',
    'Matthew': 'MAT', 'Mark': 'MRK', 'Luke': 'LUK', 'John': 'JHN', 'Acts': 'ACT',
    'Romans': 'ROM', '1_Corinthians': 'CO1', '2_Corinthians': 'CO2', 'Galatians': 'GAL', 'Ephesians': 'EPH',
    'Philippians': 'PHP', 'Colossians': 'COL', '1_Thessalonians': 'TH1', '2_Thessalonians': 'TH2', '1_Timothy': 'TI1',
    '2_Timothy': 'TI2', 'Titus': 'TIT', 'Philemon': 'PHM', 'Hebrews': 'HEB', 'James': 'JAS',
    '1_Peter': 'PE1', '2_Peter': 'PE2', '1_John': 'JN1', '2_John': 'JN2', '3_John': 'JN3',
    'Jude': 'JUD', 'Revelation': 'REV'
  };

  Future<void> organizeFiles() async {
    // Create target directories if they don't exist
    final oldTestamentDir = Directory('$targetBase/Old_Testament');
    final newTestamentDir = Directory('$targetBase/New_Testament');
    
    await oldTestamentDir.create(recursive: true);
    await newTestamentDir.create(recursive: true);

    // Get all files from both directories
    final allFiles = await Directory(targetBase).list(recursive: true).where((entity) => 
      entity is File && entity.path.endsWith('_read.txt')).toList();

    for (var entity in allFiles) {
      if (entity is File) {
        final filename = entity.path.split('/').last;
        final bookNumber = int.tryParse(filename.split('_')[1]);
        
        if (bookNumber != null) {
          final isNewTestament = bookNumber >= 41; // Matthew starts at 41
          final targetDir = isNewTestament ? newTestamentDir : oldTestamentDir;
          final targetPath = '${targetDir.path}/$filename';
          
          if (entity.path != targetPath) {
            try {
              await entity.rename(targetPath);
              print('Moved ${entity.path} to $targetPath');
            } catch (e) {
              // If rename fails (e.g., across devices), copy and delete
              await File(targetPath).writeAsBytes(await entity.readAsBytes());
              await entity.delete();
              print('Copied and deleted ${entity.path} to $targetPath');
            }
          }
        }
      }
    }
    
    print('File organization complete');
  }
} 