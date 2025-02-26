import 'package:flutter/material.dart';
import '../services/bookmark_service.dart';
import 'package:provider/provider.dart';
import '../services/audio_state_manager.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final BookmarkService _bookmarkService = BookmarkService();

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    await _bookmarkService.loadBookmarks();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = _bookmarkService.getBookmarks();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        backgroundColor: Colors.black.withOpacity(0.7),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.grey[900]!,
              Colors.black,
            ],
          ),
        ),
        child: bookmarks.isEmpty
            ? const Center(
                child: Text(
                  'No bookmarks yet',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : ListView.builder(
                itemCount: bookmarks.length,
                itemBuilder: (context, index) {
                  final bookmark = bookmarks[index];
                  return Dismissible(
                    key: Key('bookmark_${bookmark.book}_${bookmark.chapter}_${bookmark.verse}'),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20.0),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) async {
                      await _bookmarkService.toggleBookmark(
                        bookmark.book,
                        bookmark.chapter,
                        bookmark.verse,
                        bookmark.text,
                      );
                      setState(() {});
                    },
                    child: Card(
                      color: Colors.black.withOpacity(0.7),
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        leading: IconButton(
                          icon: const Icon(
                            Icons.bookmark,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            await _bookmarkService.toggleBookmark(
                              bookmark.book,
                              bookmark.chapter,
                              bookmark.verse,
                              bookmark.text,
                            );
                            setState(() {});
                          },
                        ),
                        title: Text(
                          '${bookmark.book} ${bookmark.chapter}:${bookmark.verse}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          bookmark.text,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        onTap: () {
                          // Navigate back to HomeScreen with the selected verse
                          final audioStateManager = Provider.of<AudioStateManager>(context, listen: false);
                          audioStateManager.navigateToPassage(bookmark.book, bookmark.chapter);
                          
                          // Pop back to HomeScreen
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
} 