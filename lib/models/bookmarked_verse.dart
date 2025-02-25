class BookmarkedVerse {
  final String book;
  final int chapter;
  final int verse;
  final String text;

  BookmarkedVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  Map<String, dynamic> toJson() {
    return {
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'text': text,
    };
  }

  factory BookmarkedVerse.fromJson(Map<String, dynamic> json) {
    return BookmarkedVerse(
      book: json['book'] as String,
      chapter: json['chapter'] as int,
      verse: json['verse'] as int,
      text: json['text'] as String,
    );
  }
} 