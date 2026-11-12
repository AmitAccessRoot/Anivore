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

class Section {
  const Section(this.heading, this.points);

  final String heading;
  final List<String> points;

  factory Section.fromJson(Map<String, dynamic> j) {
    return Section(
      (j['heading'] ?? '').toString(),
      ((j['points'] ?? []) as List).map((e) => e.toString()).toList(),
    );
  }
}

class Topic {
  const Topic(this.title, this.subtitle, this.sections);

  final String title;
  final String subtitle;
  final List<Section> sections;

  factory Topic.fromJson(Map<String, dynamic> j) {
    return Topic(
      (j['title'] ?? '').toString(),
      (j['subtitle'] ?? '').toString(),
      ((j['sections'] ?? []) as List)
          .map((e) => Section.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

Future<List<Topic>> loadTopics() async {
  try {
    final String raw = await rootBundle.loadString('assets/texts.json');
    final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
    return ((map['topics'] ?? []) as List)
        .map((e) => Topic.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return <Topic>[];
  }
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

class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final List<Widget> lines = <Widget>[];

    for (final Section s in topic.sections) {
      lines.add(
        Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 6),
          child: Text(
            s.heading,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: mainColor(context),
            ),
          ),
        ),
      );
      for (final String point in s.points) {
        lines.add(
          Padding(
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
                    point,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.5,
                      color: mainColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                topic.title,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: mainColor(context),
                ),
              ),
              ...lines,
            ],
          ),
        ),
      ),
    );
  }
}
