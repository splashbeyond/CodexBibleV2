import 'package:flutter/material.dart';
import '../services/bookmark_service.dart';
import 'package:provider/provider.dart';
import '../services/audio_state_manager.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final BookmarkService _bookmarkService = BookmarkService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _bookmarkService.setupAuthListener();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      print('BookmarksScreen: Loading bookmarks...');
      await _bookmarkService.loadBookmarks();
      if (mounted) {
        setState(() {});
      }
      print('BookmarksScreen: Loaded ${_bookmarkService.getBookmarks().length} bookmarks');
    } catch (e) {
      print('BookmarksScreen: Error loading bookmarks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bookmarks: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildAuthenticationRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Sign in to view your bookmarks',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Show auth dialog directly instead of navigating
              _showAuthDialog(context, Provider.of<AuthService>(context, listen: false));
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showAuthDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final emailController = TextEditingController();
        final passwordController = TextEditingController();
        bool isLogin = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLogin ? 'Sign In' : 'Create Account',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isLogin = !isLogin;
                            });
                          },
                          child: Text(isLogin ? 'Create Account' : 'Sign In Instead'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              if (isLogin) {
                                await authService.signInWithEmailAndPassword(
                                  emailController.text,
                                  passwordController.text,
                                );
                              } else {
                                await authService.createUserWithEmailAndPassword(
                                  emailController.text,
                                  passwordController.text,
                                );
                              }
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(isLogin ? 'Signed in successfully' : 'Account created successfully')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          child: Text(isLogin ? 'Sign In' : 'Create Account'),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () async {
                        if (emailController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter your email')),
                          );
                          return;
                        }
                        try {
                          await authService.resetPassword(emailController.text);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password reset email sent')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Forgot Password?'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? Colors.black.withOpacity(0.7)
          : Colors.white,
        foregroundColor: Theme.of(context).brightness == Brightness.dark 
          ? Colors.white 
          : Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookmarks,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.grey[900]!,
                  Colors.black,
                ],
              )
            : null,
          color: Theme.of(context).brightness == Brightness.dark 
            ? null 
            : Colors.white,
        ),
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) {
              return _buildAuthenticationRequired();
            }

            return RefreshIndicator(
              onRefresh: _loadBookmarks,
              child: Stack(
                children: [
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_bookmarkService.getBookmarks().isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 64,
                            color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.grey 
                              : Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No bookmarks yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white 
                                : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the bookmark icon while reading to save verses',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey[400] 
                                : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      itemCount: _bookmarkService.getBookmarks().length,
                      itemBuilder: (context, index) {
                        final bookmark = _bookmarkService.getBookmarks()[index];
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
                            try {
                              await _bookmarkService.toggleBookmark(
                                bookmark.book,
                                bookmark.chapter,
                                bookmark.verse,
                                bookmark.text,
                              );
                              setState(() {});
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error removing bookmark: $e')),
                                );
                              }
                            }
                          },
                          child: Card(
                            color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.black.withOpacity(0.7)
                              : Colors.white,
                            elevation: Theme.of(context).brightness == Brightness.dark 
                              ? 0 
                              : 1,
                            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: ListTile(
                              leading: Container(
                                width: 48,
                                height: 48,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.bookmark,
                                    color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white 
                                      : Colors.black,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                  onPressed: () async {
                                    try {
                                      await _bookmarkService.toggleBookmark(
                                        bookmark.book,
                                        bookmark.chapter,
                                        bookmark.verse,
                                        bookmark.text,
                                      );
                                      setState(() {});
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error removing bookmark: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                              title: Text(
                                '${bookmark.book} ${bookmark.chapter}:${bookmark.verse}',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white 
                                    : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                bookmark.text,
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white70 
                                    : Colors.black87,
                                ),
                              ),
                              onTap: null,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
} 