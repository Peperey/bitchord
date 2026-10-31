import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';

class Song {
  final String title, artist, path;
  final Color color;
  int secs;
  Song(this.title, this.artist, this.path, this.color, [this.secs = 0]);
}

String fmt(num s) {
  final t = s.toInt();
  return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
}

class P extends ChangeNotifier {
  final player = AudioPlayer();
  final yte = yt.YoutubeExplode();

  Future<List<Song>> ytSearch(String q) async {
    final r = await yte.search.search(q);
    return [
      for (final v in r.take(15))
        Song(
            v.title,
            v.author,
            'yt:${v.id.value}',
            HSVColor.fromAHSV(
                    1, (v.title.hashCode.abs() % 360).toDouble(), .6, .85)
                .toColor(),
            v.duration?.inSeconds ?? 0)
    ];
  }

  Future<void> addPlay(Song s) async {
    songs.add(s);
    notifyListeners();
    await play(songs.length - 1);
  }
  final songs = <Song>[];
  final pos = ValueNotifier<Duration>(Duration.zero);
  int i = -1;
  bool playing = false;
  String? error;

  P() {
    player.playerStateStream.listen((st) {
      playing = st.playing;
      if (st.processingState == ProcessingState.completed) next();
      notifyListeners();
    });
    player.positionStream.listen((d) => pos.value = d);
    player.durationStream.listen((d) {
      if (d != null && i >= 0 && i < songs.length) {
        songs[i].secs = d.inSeconds;
        notifyListeners();
      }
    });
  }

  Song? get s => (i >= 0 && i < songs.length) ? songs[i] : null;

  Future<void> add() async {
    final r = await FilePicker.platform
        .pickFiles(type: FileType.audio, allowMultiple: true);
    if (r == null) return;
    for (final f in r.files) {
      final path = f.path;
      if (path == null || songs.any((x) => x.path == path)) continue;
      var name = f.name;
      final dot = name.lastIndexOf('.');
      if (dot > 0) name = name.substring(0, dot);
      var artist = 'Desconocido';
      var title = name;
      final k = name.indexOf(' - ');
      if (k > 0) {
        artist = name.substring(0, k);
        title = name.substring(k + 3);
      }
      final c = HSVColor.fromAHSV(
              1, (name.hashCode.abs() % 360).toDouble(), .6, .85)
          .toColor();
      songs.add(Song(title, artist, path, c));
    }
    notifyListeners();
  }

  Future<void> play(int n) async {
    if (n < 0 || n >= songs.length) return;
    i = n;
    error = null;
    notifyListeners();
    try {
      final tag = MediaItem(
          id: songs[n].path, title: songs[n].title, artist: songs[n].artist);
      if (songs[n].path.startsWith('yt:')) {
        final id = songs[n].path.substring(3);
        final clients = <String, yt.YoutubeApiClient>{
          'androidVr': yt.YoutubeApiClient.androidVr,
          'androidSdkless': yt.YoutubeApiClient.androidSdkless,
          'ios': yt.YoutubeApiClient.ios,
        };
        File? file;
        var fails = '';
        for (final cl in clients.entries) {
          try {
            error = '1/3 Buscando (${cl.key})…';
            notifyListeners();
            final m = await yte.videos.streamsClient
                .getManifest(id, ytClients: [cl.value])
                .timeout(const Duration(seconds: 15));
            final info = m.audioOnly.withHighestBitrate();
            final f = File(
                '${Directory.systemTemp.path}/yt_$id.${info.container.name}');
            if (!await f.exists() || await f.length() == 0) {
              final tmp = File('${f.path}.part');
              final sink = tmp.openWrite();
              final total = info.size.totalBytes;
              final hc = http.Client();
              try {
                var got = 0;
                while (got < total) {
                  final end = got + 1048575 < total - 1
                      ? got + 1048575
                      : total - 1;
                  final r = http.Request('GET', info.url);
                  r.headers['range'] = 'bytes=$got-$end';
                  r.headers['user-agent'] = ua;
                  final resp =
                      await hc.send(r).timeout(const Duration(seconds: 20));
                  if (resp.statusCode != 200 && resp.statusCode != 206) {
                    throw 'HTTP ${resp.statusCode}';
                  }
                  var n = 0;
                  await for (final c
                      in resp.stream.timeout(const Duration(seconds: 20))) {
                    sink.add(c);
                    n += c.length;
                  }
                  if (n == 0) throw 'sin datos';
                  got += n;
                  error = 'Descargando ${got * 100 ~/ total}% (${cl.key})';
                  notifyListeners();
                }
              } finally {
                hc.close();
                await sink.close();
              }
              await tmp.rename(f.path);
            }
            file = f;
            break;
          } catch (ex) {
            fails += '${cl.key}: ${ex.toString().split("\n").first}\n';
          }
        }
        if (file == null) throw fails;
        error = null;
        notifyListeners();
        await player.setAudioSource(AudioSource.file(file.path, tag: tag));
      } else {
        await player.setAudioSource(
            AudioSource.uri(Uri.file(songs[n].path), tag: tag));
      }
      player.play();
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  void toggle() {
    if (s == null) return;
    playing ? player.pause() : player.play();
  }

  void next() {
    if (songs.isNotEmpty) play((i + 1) % songs.length);
  }

  void prev() {
    if (songs.isEmpty) return;
    if (pos.value.inSeconds > 3) {
      player.seek(Duration.zero);
    } else {
      play((i - 1 + songs.length) % songs.length);
    }
  }

  void seek(double v) => player.seek(Duration(seconds: v.toInt()));
}

class YtSource extends StreamAudioSource {
  final yt.YoutubeExplode y;
  final yt.AudioStreamInfo info;
  YtSource(this.y, this.info, Object tag) : super(tag: tag);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final total = info.size.totalBytes;
    final st = start ?? 0;
    final en = end ?? total;
    final src = y.videos.streamsClient.get(info);
    Stream<List<int>> body() async* {
      var skip = st;
      var left = en - st;
      await for (final c in src) {
        if (left <= 0) break;
        var b = c;
        if (skip > 0) {
          if (skip >= b.length) {
            skip -= b.length;
            continue;
          }
          b = b.sublist(skip);
          skip = 0;
        }
        if (b.length > left) b = b.sublist(0, left);
        left -= b.length;
        yield b;
      }
    }

    return StreamAudioResponse(
      sourceLength: total,
      contentLength: en - st,
      offset: st,
      stream: body(),
      contentType: info.codec.mimeType,
    );
  }
}

const ua =
    'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';

final p = P();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.peperey.bitchord.audio',
    androidNotificationChannelName: 'Reproducción',
    androidNotificationIcon: 'drawable/ic_notif',
  );
  await Permission.notification.request();
  await Permission.ignoreBatteryOptimizations.request();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BitChord',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.deepPurple,
          scaffoldBackgroundColor: const Color(0xFF0B0B10),
        ),
        home: const Shell(),
      );
}

class Art extends StatelessWidget {
  final Color c;
  final double size, r;
  const Art(this.c, this.size, this.r, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c, Color.lerp(c, Colors.black, .55)!],
          ),
        ),
        child: Icon(Icons.music_note_rounded,
            size: size * .4, color: Colors.white70),
      );
}

class Tile extends StatelessWidget {
  final int i;
  const Tile(this.i, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = p.songs[i];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Art(s.color, 50, 10),
      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(s.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54)),
      trailing: s.secs > 0
          ? Text(fmt(s.secs),
              style: const TextStyle(color: Colors.white38, fontSize: 12))
          : null,
      onTap: () => p.play(i),
    );
  }
}

class Empty extends StatelessWidget {
  const Empty({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(children: [
          const Icon(Icons.library_music_rounded,
              size: 72, color: Colors.white24),
          const SizedBox(height: 12),
          const Text('Aún no hay música',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: p.add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir música')),
        ]),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        IndexedStack(index: tab, children: const [Home(), Search(), Library()]),
        Positioned(
          left: 12,
          right: 12,
          bottom: 10 + MediaQuery.of(context).padding.bottom,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Mini(),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(padding: EdgeInsets.zero),
                  child: NavigationBar(
                    height: 64,
                    surfaceTintColor: Colors.transparent,
                    backgroundColor: Colors.white10,
                    selectedIndex: tab,
                    onDestinationSelected: (v) => setState(() => tab = v),
                    destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.home_rounded), label: 'Inicio'),
                      NavigationDestination(
                          icon: Icon(Icons.search_rounded), label: 'Buscar'),
                      NavigationDestination(
                          icon: Icon(Icons.library_music_rounded),
                          label: 'Biblioteca'),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class Mini extends StatelessWidget {
  const Mini({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: p,
        builder: (_, __) {
          final s = p.s;
          if (s == null) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const Full(),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: s.color.withOpacity(.35),
                  child: Row(children: [
                    Art(s.color, 46, 12),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(p.error ?? s.artist,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ])),
                    IconButton(
                        onPressed: p.toggle,
                        icon: Icon(p.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded)),
                    IconButton(
                        onPressed: p.next,
                        icon: const Icon(Icons.skip_next_rounded)),
                  ]),
                ),
              ),
            ),
          );
        },
      );
}

class Full extends StatelessWidget {
  const Full({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: p,
        builder: (_, __) {
          final s = p.s;
          if (s == null) return const SizedBox.shrink();
          final w = MediaQuery.of(context).size.width - 64;
          final max = s.secs > 0 ? s.secs.toDouble() : 1.0;
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [s.color.withOpacity(.8), const Color(0xFF0B0B10)],
              ),
            ),
            child: Column(children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2))),
              const Spacer(),
              Art(s.color, w, 28),
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(s.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(s.artist,
                    style: const TextStyle(color: Colors.white70)),
              ),
              ValueListenableBuilder<Duration>(
                valueListenable: p.pos,
                builder: (_, d, __) => Column(children: [
                  Slider(
                    value: d.inSeconds.toDouble().clamp(0.0, max).toDouble(),
                    max: max,
                    onChanged: p.seek,
                  ),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(fmt(d.inSeconds),
                            style: const TextStyle(color: Colors.white54)),
                        Text(fmt(s.secs),
                            style: const TextStyle(color: Colors.white54)),
                      ]),
                ]),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                    iconSize: 40,
                    onPressed: p.prev,
                    icon: const Icon(Icons.skip_previous_rounded)),
                const SizedBox(width: 12),
                IconButton.filled(
                    iconSize: 44,
                    onPressed: p.toggle,
                    icon: Icon(p.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded)),
                const SizedBox(width: 12),
                IconButton(
                    iconSize: 40,
                    onPressed: p.next,
                    icon: const Icon(Icons.skip_next_rounded)),
              ]),
              const Spacer(),
            ]),
          );
        },
      );
}

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: p,
        builder: (_, __) {
          final songs = p.songs;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 220),
            children: [
              Row(children: [
                const Expanded(
                    child: Text('Buenas noches',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800))),
                IconButton(
                    onPressed: p.add,
                    icon: const Icon(Icons.add_circle_outline_rounded)),
              ]),
              if (songs.isEmpty) const Empty(),
              if (songs.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Para ti',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 205,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: songs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => p.play(i),
                      child: SizedBox(
                        width: 140,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Art(songs[i].color, 140, 18),
                              const SizedBox(height: 8),
                              Text(songs[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(songs[i].artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                            ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Tu música',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                for (var i = 0; i < songs.length; i++) Tile(i),
              ],
            ],
          );
        },
      );
}

class Search extends StatefulWidget {
  const Search({super.key});
  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  String q = '';
  List<Song> yres = [];
  bool loading = false;
  String? err;

  Future<void> go() async {
    if (q.trim().isEmpty) return;
    setState(() {
      loading = true;
      err = null;
    });
    try {
      yres = await p.ytSearch(q);
    } catch (e) {
      err = 'YouTube: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: p,
        builder: (_, __) {
          final ids = [
            for (var i = 0; i < p.songs.length; i++)
              if ('${p.songs[i].title} ${p.songs[i].artist}'
                  .toLowerCase()
                  .contains(q.toLowerCase()))
                i
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 220),
            children: [
              TextField(
                onChanged: (v) => setState(() => q = v),
                onSubmitted: (_) => go(),
                decoration: InputDecoration(
                  hintText: 'Canciones o artistas',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              for (final i in ids) Tile(i),
              if (q.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FilledButton.tonalIcon(
                    onPressed: go,
                    icon: const Icon(Icons.travel_explore_rounded),
                    label: Text('Buscar "$q" en YouTube'),
                  ),
                ),
              if (loading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator())),
              if (err != null)
                Text(err!,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.redAccent)),
              for (final s in yres)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Art(s.color, 50, 10),
                  title: Text(s.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(s.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54)),
                  trailing: s.secs > 0
                      ? Text(fmt(s.secs),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12))
                      : null,
                  onTap: () => p.addPlay(s),
                ),
            ],
          );
        },
      );
}

class Library extends StatelessWidget {
  const Library({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: p,
        builder: (_, __) {
          if (p.songs.isEmpty) {
            return ListView(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 220),
                children: const [Empty()]);
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 220),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: .85),
            itemCount: p.songs.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => p.play(i),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: LayoutBuilder(
                            builder: (_, c) =>
                                Art(p.songs[i].color, c.maxWidth, 18))),
                    const SizedBox(height: 6),
                    Text(p.songs[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(p.songs[i].artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ]),
            ),
          );
        },
      );
}
