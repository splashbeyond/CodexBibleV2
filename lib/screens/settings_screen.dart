import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/audio_state_manager.dart';

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
    return Scaffold(
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Sign In'),
            subtitle: const Text('Sign in to sync your bookmarks'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon!')),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon!')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of Service'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon!')),
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