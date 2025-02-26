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
          children: List.generate(verses.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                '${index + 1}. ${verses[index]}',
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.4,
                  color: Colors.white,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
} 