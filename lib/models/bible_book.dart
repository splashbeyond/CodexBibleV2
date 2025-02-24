class BibleBook {
  final String name;
  final int chapters;
  final List<int> versesPerChapter;

  BibleBook({
    required this.name,
    required this.chapters,
    required this.versesPerChapter,
  });
}

class BibleVerse {
  final String book;
  final int chapter;
  final int verse;
  final String text;

  BibleVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(
      book: json['book'],
      chapter: json['chapter'],
      verse: json['verse'],
      text: json['text'],
    );
  }
}