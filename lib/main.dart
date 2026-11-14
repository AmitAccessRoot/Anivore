import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

// Increase this number every time you replace assets/database.db,
// so the app copies the new database on the next launch.
const int kDbVersion = 1;

const String kDbAsset = 'assets/database.db';
const String kDbName = 'anivore_book.db';
const int kPageSize = 50;

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
    };
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    runApp(const AnivoreApp());
  }, (Object error, StackTrace stack) {});
}

class Chapter {
  const Chapter(this.id, this.title);

  final int id;
  final String title;
}

Future<Database?> openBook() async {
  try {
    final String dir = await getDatabasesPath();
    final String dbPath = '$dir/$kDbName';
    final File verFile = File('$dbPath.ver');

    bool ready = false;
    if (await File(dbPath).exists() && await verFile.exists()) {
      final String saved = (await verFile.readAsString()).trim();
      ready = saved == kDbVersion.toString();
    }

    if (!ready) {
      await Directory(dir).create(recursive: true);
      final ByteData data = await rootBundle.load(kDbAsset);
      final File tmp = File('$dbPath.tmp');
      await tmp.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await deleteDatabase(dbPath);
      await tmp.rename(dbPath);
      await verFile.writeAsString(kDbVersion.toString(), flush: true);
    }

    return await openDatabase(dbPath, readOnly: true, singleInstance: true);
  } catch (_) {
    return null;
  }
}

Future<List<Chapter>> fetchChapters(Database db, int afterId, int limit) async {
  final List<Map<String, Object?>> rows = await db.query(
    'chapters',
    columns: <String>['id', 'title'],
    where: 'id > ?',
    whereArgs: <Object>[afterId],
    orderBy: 'id ASC',
    limit: limit,
  );
  return rows
      .map(
        (Map<String, Object?> r) =>
            Chapter((r['id'] as num).toInt(), (r['title'] ?? '').toString()),
      )
      .toList();
}

Future<List<String>> fetchContent(Database db, int id) async {
  final List<Map<String, Object?>> rows = await db.query(
    'chapters',
    columns: <String>['content'],
    where: 'id = ?',
    whereArgs: <Object>[id],
    limit: 1,
  );
  if (rows.isEmpty) {
    return <String>[];
  }
  final String content = (rows.first['content'] ?? '').toString();
  return content
      .split('\n')
      .map((String s) => s.trimRight())
      .where((String s) => s.trim().isNotEmpty)
      .toList();
}

bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color mainColor(BuildContext context) =>
    isDark(context) ? Colors.white : Colors.black;

Color softColor(BuildContext context) =>
    isDark(context) ? const Color(0xFFD1D5DB) : const Color(0xFF374151);

ThemeData buildTheme(Brightness b) {
  final bool dark = b == Brightness.dark;
  final Color bg = dark ? Colors.black : Colors.white;
  final Color fg = dark ? Colors.white : Colors.black;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    colorScheme: ColorScheme(
      brightness: b,
      primary: fg,
      onPrimary: bg,
      secondary: fg,
      onSecondary: bg,
      error: const Color(0xFFB91C1C),
      onError: Colors.white,
      surface: bg,
      onSurface: fg,
      surfaceTint: Colors.transparent,
    ),
  );
}

class AnivoreApp extends StatelessWidget {
  const AnivoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anivore',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      builder: (BuildContext context, Widget? child) {
        final bool dark = isDark(context);
        final Brightness icons = dark ? Brightness.light : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: icons,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: icons,
            systemNavigationBarContrastEnforced: false,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _controller = ScrollController();
  final List<Chapter> _items = <Chapter>[];
  Database? _db;
  bool _failed = false;
  bool _loaded = false;
  bool _loading = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final Database? db = await openBook();
    if (!mounted) {
      return;
    }
    if (db == null) {
      setState(() => _failed = true);
      return;
    }
    _db = db;
    await _more();
  }

  void _onScroll() {
    if (_controller.hasClients &&
        _controller.position.pixels >
            _controller.position.maxScrollExtent - 800) {
      _more();
    }
  }

  Future<void> _more() async {
    final Database? db = _db;
    if (db == null || _loading || _done) {
      return;
    }
    _loading = true;
    try {
      final int after = _items.isEmpty ? 0 : _items.last.id;
      final List<Chapter> page = await fetchChapters(db, after, kPageSize);
      if (mounted) {
        setState(() {
          _items.addAll(page);
          _loaded = true;
          if (page.length < kPageSize) {
            _done = true;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _done = true;
        });
      }
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || (_loaded && _items.isEmpty)) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Text(
              'No chapters found',
              style: TextStyle(fontSize: 16, color: softColor(context)),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: ListView.separated(
          controller: _controller,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          itemCount: _items.length,
          separatorBuilder: (BuildContext context, int i) => const Divider(
            height: 1,
            thickness: 1,
            color: Color(0x33808080),
          ),
          itemBuilder: (BuildContext context, int i) {
            final Chapter c = _items[i];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final Database? db = _db;
                if (db == null) {
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext _) =>
                        ChapterPage(db: db, chapter: c),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  c.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                    color: mainColor(context),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ChapterPage extends StatefulWidget {
  const ChapterPage({super.key, required this.db, required this.chapter});

  final Database db;
  final Chapter chapter;

  @override
  State<ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  List<String> _lines = <String>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<String> lines = <String>[];
    try {
      lines = await fetchContent(widget.db, widget.chapter.id);
    } catch (_) {}
    if (mounted) {
      setState(() => _lines = lines);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          itemCount: _lines.length + 1,
          itemBuilder: (BuildContext context, int i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  widget.chapter.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                    color: mainColor(context),
                  ),
                ),
              );
            }
            final String line = _lines[i - 1];
            if (line.startsWith('# ')) {
              return Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 6),
                child: Text(
                  line.substring(2),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                    color: mainColor(context),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.7,
                  color: mainColor(context),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
