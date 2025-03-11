import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/audio_state_manager.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AudioStateManager _audioStateManager;
  String? _selectedSong;
  double _volume = 0.5;

  @override
  void initState() {
    super.initState();
    _audioStateManager = Provider.of<AudioStateManager>(context, listen: false);
    _selectedSong = _audioStateManager.backgroundMusicService.currentSong;
    _volume = _audioStateManager.backgroundMusicService.volume;
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    return Scaffold(
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _SectionHeader('Account'),
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                // User is signed in
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(snapshot.data?.email ?? 'Signed In'),
                      subtitle: const Text('Tap to manage account'),
                      onTap: () => _showAccountManagement(context, authService),
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Sign Out'),
                      onTap: () async {
                        try {
                          await authService.signOut();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Signed out successfully')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error signing out: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                );
              }
              // User is not signed in
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Sign In'),
                subtitle: const Text('Sign in to sync your bookmarks'),
                onTap: () => _showAuthDialog(context, authService),
              );
            },
          ),
          const Divider(),
          _SectionHeader('Appearance'),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Dark Mode'),
                value: themeProvider.isDarkMode,
                onChanged: (bool value) {
                  themeProvider.toggleTheme();
                },
              );
            },
          ),
          const Divider(),
          _SectionHeader('Background Music'),
          Consumer<AudioStateManager>(
            builder: (context, audioManager, child) {
              return SwitchListTile(
                secondary: const Icon(Icons.music_note),
                title: const Text('Enable Background Music'),
                value: audioManager.isBackgroundMusicEnabled,
                onChanged: (bool value) {
                  audioManager.toggleBackgroundMusic();
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Select Music'),
            subtitle: Text(_selectedSong ?? 'No music selected'),
            onTap: () {
              _showMusicSelector();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Consumer<AudioStateManager>(
                  builder: (context, audioManager, child) {
                    return IconButton(
                      icon: Icon(audioManager.backgroundMusicService.isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: _selectedSong == null ? null : () async {
                        if (audioManager.isBackgroundMusicEnabled) {
                          if (audioManager.backgroundMusicService.isPlaying) {
                            await audioManager.backgroundMusicService.pause();
                          } else if (_selectedSong != null) {
                            await audioManager.backgroundMusicService.resume();
                          }
                          setState(() {});
                        }
                      },
                    );
                  },
                ),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: (value) {
                      setState(() {
                        _volume = value;
                      });
                      _audioStateManager.backgroundMusicService.setVolume(value);
                    },
                  ),
                ),
                Text('${(_volume * 100).round()}%'),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppBar(
                            title: const Text('Privacy Policy'),
                            leading: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Privacy Policy for SpokenWord Bible',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Effective Date: March 11, 2025',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Introduction',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Welcome to SpokenWord Bible. This Privacy Policy explains how Ephesian28 LLC ("we," "our," or "us") collects, uses, and shares your information when you use our SpokenWord Bible application ("App"). We respect your privacy and are committed to protecting your personal information.',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Information We Collect',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Personal Information',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '\nEmail Address: When you register for an account, we collect your email address through Firebase Authentication.'
                                    '\nUser Profile: Information you choose to add to your profile.',
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Usage Information',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '\nApp Usage Data: How you interact with the App, including features used, time spent, and Bible passages accessed.'
                                    '\nDevice Information: Device type, operating system, unique device identifiers.'
                                    '\nLog Data: Information automatically recorded when you use the App, including access times and app crashes.',
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Audio Preferences',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '\nListening History: Bible passages you\'ve listened to.'
                                    '\nAudio Settings: Your preferred background sounds and playback settings.',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'How We Use Your Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'We use your information to:'
                                    '\n\n• Provide and maintain the App functionality'
                                    '\n• Authenticate your account via Firebase'
                                    '\n• Remember your preferences and settings'
                                    '\n• Improve and optimize the App experience'
                                    '\n• Send important notifications about the App',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Data Storage and Security',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Your information is stored and processed using Firebase, a secure platform provided by Google. We implement appropriate security measures to protect your personal information from unauthorized access, alteration, or disclosure.',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Third-Party Services',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Firebase',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'We use Firebase (provided by Google) for authentication, data storage, and analytics. Firebase\'s privacy policy can be found at: https://firebase.google.com/support/privacy',
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Bible Text Providers',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'We use commercially available free Bible texts. We do not share your personal information with these providers.',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Your Rights and Choices',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'You have the right to:'
                                    '\n\n• Access, correct, or delete your personal information'
                                    '\n• Opt out of marketing communications'
                                    '\n• Change your audio preferences and settings'
                                    '\n• Delete your account',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Children\'s Privacy',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'The App is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13.',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Changes to This Privacy Policy',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Effective Date."',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Contact Us',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'If you have any questions about this Privacy Policy, please contact us at:'
                                    '\n\nEphesian28 LLC'
                                    '\nEmail: ephesian28mgmt@yahoo.com'
                                    '\n\nBy using the SpokenWord Bible App, you agree to the collection and use of information in accordance with this Privacy Policy.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of Service'),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppBar(
                            title: const Text('Terms of Service'),
                            leading: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Legal Disclaimer and Terms of Service',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Attribution and Usage Rights',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'This application ("App") incorporates the following third-party content, each used in accordance with their respective licenses:',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Biblical Content',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '• World English Bible (WEB) text: The WEB is in the Public Domain. No copyright license is needed for its use, distribution, or adaptation. The WEB text may be freely used for any purpose without permission or attribution.',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Audio Content',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '• World English Bible Recording - American Male Voice (Michael Johnson): This audio recording is utilized under its free commercial use license. The recording is in the Public Domain and may be freely used, distributed, or adapted for commercial or non-commercial purposes without attribution requirements.\n\n'
                                    '• "Soft Rain Ambient" by SoundsForYou from Pixabay.com: This ambient sound is used under the Pixabay License, which allows for free commercial and non-commercial use without attribution requirements. No permission is needed to use, distribute, or adapt this content within our application.',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Disclaimer of Affiliation',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'This App is not affiliated with, endorsed by, or sponsored by the World English Bible translation project, Michael Johnson, SoundsForYou, or Pixabay. All content is used in accordance with applicable licenses and permissions.',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'General Terms',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'While the content incorporated within this App is free for commercial use, this App itself and any proprietary features, functionalities, or original content created by Ephesian28 LLC remain the intellectual property of Ephesian28 LLC.\n\n'
                                    'Users are permitted to use this App for personal Bible study, educational, and spiritual purposes, but may not extract, redistribute, or repurpose the App\'s proprietary code or design elements without express written permission.',
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Terms of Service',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Acceptance of Terms\n'
                                    'By downloading, installing, or using this App, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App.\n\n'
                                    'User Accounts\n'
                                    '• Users may be required to create an account to access certain features of the App.\n'
                                    '• You are responsible for maintaining the confidentiality of your account information.\n'
                                    '• You are responsible for all activities that occur under your account.\n'
                                    '• Ephesian28 LLC reserves the right to terminate accounts that violate these terms.\n\n'
                                    'Permitted Use\n'
                                    '• This App is provided for personal, non-transferable use.\n'
                                    '• You may not use the App for any illegal purpose or in violation of any local, state, national, or international law.\n'
                                    '• You may not copy, modify, distribute, sell, or lease any part of the App without explicit permission from Ephesian28 LLC.\n\n'
                                    'Content and Copyright\n'
                                    '• User-generated content (such as notes, bookmarks, or highlights) remains the property of the user.\n'
                                    '• By submitting content to shared features of the App, you grant Ephesian28 LLC a worldwide, non-exclusive license to use, reproduce, and display such content.\n'
                                    '• You may not upload or share content that infringes on intellectual property rights of others.\n\n'
                                    'Privacy Policy\n'
                                    '• The App collects certain information as described in our Privacy Policy.\n'
                                    '• By using the App, you consent to the collection and use of information as outlined in the Privacy Policy.\n\n'
                                    'Limitation of Liability\n'
                                    '• The App is provided "as is" without warranties of any kind.\n'
                                    '• Ephesian28 LLC shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the App.\n'
                                    '• The total liability of Ephesian28 LLC for any claims under these terms shall not exceed the amount you paid for the App.\n\n'
                                    'Modifications to the App\n'
                                    '• Ephesian28 LLC reserves the right to modify, suspend, or discontinue the App or any part thereof at any time.\n'
                                    '• Ephesian28 LLC may update these Terms of Service from time to time. Continued use of the App after such changes constitutes acceptance of the new terms.\n\n'
                                    'Governing Law\n'
                                    'These Terms of Service shall be governed by and construed in accordance with the laws of the State of Arizona, without regard to its conflict of law provisions.\n\n'
                                    'Last Updated: February 25, 2025',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showMusicSelector() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Background Music',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_audioStateManager.backgroundMusicService.availableSongs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No music files found.\nAdd .mp3 files to the assets/background_music folder.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _audioStateManager.backgroundMusicService.availableSongs.length,
                    itemBuilder: (context, index) {
                      final song = _audioStateManager.backgroundMusicService.availableSongs[index];
                      return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(song.replaceAll('.mp3', '')),
                        selected: song == _selectedSong,
                        onTap: () async {
                          setState(() {
                            _selectedSong = song;
                          });
                          await _audioStateManager.backgroundMusicService.playSong(song);
                          if (_audioStateManager.isPlaying) {
                            await _audioStateManager.resumeAll();
                          }
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
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

  void _showAccountManagement(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Account Management'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Email: ${authService.currentUser?.email ?? ""}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await authService.deleteAccount();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Account deleted successfully')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error deleting account: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete Account'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
} 