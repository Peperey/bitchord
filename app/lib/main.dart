import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Permission.notification.request();
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.peperey.bitchord.channel',
      androidNotificationChannelName: 'Bitchord',
      androidNotificationOngoing: true,
    );
    runApp(const App());
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error de audio: $e', style: const TextStyle(color: Colors.red)),
          ),
        ),
      ),
    ));
  }
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Bitchord',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.purple),
        home: const PlayerPage(),
      );
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _player = AudioPlayer();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _player.setAudioSource(AudioSource.uri(
        Uri.parse('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'),
        tag: const MediaItem(
          id: '1',
          title: 'SoundHelix Song 1',
          artist: 'SoundHelix',
        ),
      ));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bitchord')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Error: $_error',
                    style: const TextStyle(color: Colors.red)),
              ),
            StreamBuilder<Duration?>(
              stream: _player.durationStream,
              builder: (_, snap) {
                final dur = snap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (_, s2) {
                    final pos = s2.data ?? Duration.zero;
                    final maxMs = dur.inMilliseconds.toDouble();
                    final val = pos.inMilliseconds.toDouble().clamp(0.0, maxMs).toDouble();
                    return Column(children: [
                      Slider(
                        value: val,
                        max: maxMs > 0 ? maxMs : 1,
                        onChanged: maxMs > 0
                            ? (v) => _player
                                .seek(Duration(milliseconds: v.toInt()))
                            : null,
                      ),
                      Text('${pos.inSeconds}s / ${dur.inSeconds}s'),
                    ]);
                  },
                );
              },
            ),
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (_, snap) {
                final st = snap.data;
                final playing = st?.playing ?? false;
                final busy = st?.processingState == ProcessingState.loading ||
                    st?.processingState == ProcessingState.buffering;
                return IconButton(
                  iconSize: 64,
                  icon: busy
                      ? const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator())
                      : Icon(playing ? Icons.pause : Icons.play_arrow),
                  onPressed: busy
                      ? null
                      : () => playing ? _player.pause() : _player.play(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
