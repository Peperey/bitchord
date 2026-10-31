import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

class Song {
  final String title, artist, album;
  final int secs;
  final Color color;
  const Song(this.title, this.artist, this.album, this.secs, this.color);
}

const songs = [
  Song('Neon Rain', 'Luna Vega', 'Midnight City', 212, Color(0xFF7C4DFF)),
  Song('Cassette Heart', 'The Fades', 'Analog', 187, Color(0xFFFF6E40)),
  Song('Golden Hour', 'Mara Sol', 'Atardecer', 241, Color(0xFFFFB300)),
  Song('Ocean Drive', 'Kilo & Mar', 'Costa', 198, Color(0xFF00B8D4)),
  Song('Polvo de Estrellas', 'Nadir', 'Cosmos', 265, Color(0xFFE040FB)),
  Song('Bosque', 'Verde Azul', 'Raíces', 174, Color(0xFF43A047)),
];

String fmt(num s) {
  final t = s.toInt();
  return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
}

class P extends ChangeNotifier {
  int i = 0;
  bool playing = false;
  double pos = 0;
  Timer? _t;
  Song get s => songs[i];
  void toggle() {
    playing = !playing;
    _t?.cancel();
    if (playing) {
      _t = Timer.periodic(const Duration(seconds: 1), (_) {
        pos += 1;
        if (pos >= s.secs) {
          next();
        } else {
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  void play(int n) {
    i = n;
    pos = 0;
    if (!playing) {
      toggle();
    } else {
      notifyListeners();
    }
  }

  void next() {
    i = (i + 1) % songs.length;
    pos = 0;
    notifyListeners();
  }

  void prev() {
    i = (i - 1 + songs.length) % songs.length;
    pos = 0;
    notifyListeners();
  }

  void seek(double v) {
    pos = v;
    notifyListeners();
  }
}

final p = P();

void main() => runApp(const App());

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
    final s = songs[i];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Art(s.color, 50, 10),
      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(s.artist, style: const TextStyle(color: Colors.white54)),
      trailing: Text(fmt(s.secs),
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
      onTap: () => p.play(i),
    );
  }
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
                          Text(s.artist,
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
          final w = MediaQuery.of(context).size.width - 64;
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
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('${s.artist} · ${s.album}',
                    style: const TextStyle(color: Colors.white70)),
              ),
              Slider(
                value: p.pos.clamp(0.0, s.secs.toDouble()).toDouble(),
                max: s.secs.toDouble(),
                onChanged: p.seek,
              ),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fmt(p.pos),
                        style: const TextStyle(color: Colors.white54)),
                    Text(fmt(s.secs),
                        style: const TextStyle(color: Colors.white54)),
                  ]),
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
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 56, 16, 220),
        children: [
          const Text('Buenas noches',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          const Text('Para ti',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
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
          const Text('Recientes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          for (var i = 0; i < songs.length; i++) Tile(i),
        ],
      );
}

class Search extends StatefulWidget {
  const Search({super.key});
  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final ids = [
      for (var i = 0; i < songs.length; i++)
        if ('${songs[i].title} ${songs[i].artist} ${songs[i].album}'
            .toLowerCase()
            .contains(q.toLowerCase()))
          i
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 220),
      children: [
        TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: InputDecoration(
            hintText: 'Canciones, artistas, álbumes',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        for (final i in ids) Tile(i),
      ],
    );
  }
}

class Library extends StatelessWidget {
  const Library({super.key});
  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 56, 16, 220),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: .85),
        itemCount: songs.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => p.play(i),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: LayoutBuilder(
                        builder: (_, c) =>
                            Art(songs[i].color, c.maxWidth, 18))),
                const SizedBox(height: 6),
                Text(songs[i].album,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(songs[i].artist,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
        ),
      );
}
