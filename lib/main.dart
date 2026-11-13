import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class Topic {
  const Topic(this.title, this.subtitle, this.file);

  final String title;
  final String subtitle;
  final String file;
}

class Line {
  const Line(this.heading, this.text);

  final bool heading;
  final String text;
}

Future<List<Topic>> loadTopics() async {
  try {
    final String raw = await rootBundle.loadString('assets/texts.json');
    final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
    return ((map['topics'] ?? <dynamic>[]) as List).map((dynamic e) {
      final Map<String, dynamic> m = e as Map<String, dynamic>;
      return Topic(
        (m['title'] ?? '').toString(),
        (m['subtitle'] ?? '').toString(),
        (m['file'] ?? '').toString(),
      );
    }).toList();
  } catch (_) {
    return <Topic>[];
  }
}

Future<List<Line>> loadLines(String file) async {
  final List<Line> out = <Line>[];
  try {
    final String raw = await rootBundle.loadString(file);
    final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
    for (final dynamic s in (map['sections'] ?? <dynamic>[]) as List) {
      final Map<String, dynamic> m = s as Map<String, dynamic>;
      final String heading = (m['heading'] ?? '').toString();
      if (heading.isNotEmpty) {
        out.add(Line(true, heading));
      }
      for (final dynamic point in (m['points'] ?? <dynamic>[]) as List) {
        out.add(Line(false, point.toString()));
      }
    }
  } catch (_) {
    return <Line>[];
  }
  return out;
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
  late final Future<List<Topic>> _future = loadTopics();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Topic>>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<List<Topic>> snap) {
            if (!snap.hasData) {
              return const SizedBox.shrink();
            }
            final List<Topic> topics = snap.data!;
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: topics.length,
              separatorBuilder: (BuildContext context, int i) => const Divider(
                height: 1,
                thickness: 1,
                color: Color(0x33808080),
              ),
              itemBuilder: (BuildContext context, int i) {
                final Topic t = topics[i];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext _) => DetailPage(topic: t),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          t.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                            color: mainColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.subtitle,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            color: softColor(context),
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
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.topic});

  final Topic topic;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late final Future<List<Line>> _future = loadLines(widget.topic.file);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Line>>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<List<Line>> snap) {
            final List<Line> lines = snap.data ?? <Line>[];
            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              itemCount: lines.length + 1,
              itemBuilder: (BuildContext context, int i) {
                if (i == 0) {
                  return Text(
                    widget.topic.title,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: mainColor(context),
                    ),
                  );
                }
                final Line l = lines[i - 1];
                if (l.heading) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 22, bottom: 6),
                    child: Text(
                      l.text,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: mainColor(context),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: 22,
                          height: 1.5,
                          color: mainColor(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.text,
                          style: TextStyle(
                            fontSize: 22,
                            height: 1.5,
                            color: mainColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
