import 'package:flutter/material.dart';

class VerseDisplay extends StatelessWidget {
  final List<String> verses;
  final int highlightedVerse;
  final ScrollController scrollController;

  const VerseDisplay({
    Key? key,
    required this.verses,
    required this.highlightedVerse,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(verses.length, (verseIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    fontSize: 18,
                  ),
                  children: [
                    TextSpan(
                      text: '${verseIndex + 1} ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    TextSpan(
                      text: verses[verseIndex],
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
} 