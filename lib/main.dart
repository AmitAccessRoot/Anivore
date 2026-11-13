import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
    };
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await model.load();
    runApp(const AnivoreApp());
  }, (Object error, StackTrace stack) {});
}

const int kSize = 4;

const List<int> kLevels = <int>[
  2,
  4,
  8,
  16,
  32,
  64,
  128,
  256,
  512,
  1024,
  2048,
];

enum Dir { left, right, up, down }

class Store {
  static const MethodChannel _channel = MethodChannel('anivore/store');
  static final Map<String, String> _memory = <String, String>{};

  static Future<String?> get(String key) async {
    try {
      final String? v = await _channel.invokeMethod<String>(
        'get',
        <String, dynamic>{'key': key},
      );
      if (v != null) {
        return v;
      }
    } catch (_) {}
    return _memory[key];
  }

  static Future<void> set(String key, String value) async {
    _memory[key] = value;
    try {
      await _channel.invokeMethod<bool>(
        'set',
        <String, dynamic>{'key': key, 'value': value},
      );
    } catch (_) {}
  }
}

class AppModel extends ChangeNotifier {
  bool sound = true;
  bool haptic = true;
  int themeMode = 0;
  double sensitivity = 0.6;
  bool fast = false;
  bool autosave = true;
  String lang = 'hi';
  int best = 0;
  List<int> scores = <int>[];
  Set<int> unlocked = <int>{};
  String? savedGame;

  Future<void> load() async {
    try {
      final String? s = await Store.get('settings');
      if (s != null && s.isNotEmpty) {
        final Map<String, dynamic> m = jsonDecode(s) as Map<String, dynamic>;
        sound = m['sound'] != false;
        haptic = m['haptic'] != false;
        themeMode = math.max(
          0,
          math.min(2, ((m['theme'] as num?) ?? 0).toInt()),
        );
        sensitivity = math.max(
          0.0,
          math.min(1.0, ((m['sens'] as num?) ?? 0.6).toDouble()),
        );
        fast = m['fast'] == true;
        autosave = m['autosave'] != false;
        lang = m['lang'] == 'en' ? 'en' : 'hi';
      }
    } catch (_) {}
    try {
      final String? r = await Store.get('records');
      if (r != null && r.isNotEmpty) {
        final Map<String, dynamic> m = jsonDecode(r) as Map<String, dynamic>;
        best = ((m['best'] as num?) ?? 0).toInt();
        scores = ((m['scores'] ?? <dynamic>[]) as List)
            .map((dynamic e) => (e as num).toInt())
            .toList();
        unlocked = ((m['unlocked'] ?? <dynamic>[]) as List)
            .map((dynamic e) => (e as num).toInt())
            .toSet();
      }
    } catch (_) {}
    try {
      final String? g = await Store.get('game');
      if (g != null && g.isNotEmpty) {
        savedGame = g;
      }
    } catch (_) {}
  }

  void _persistSettings() {
    Store.set(
      'settings',
      jsonEncode(<String, dynamic>{
        'sound': sound,
        'haptic': haptic,
        'theme': themeMode,
        'sens': sensitivity,
        'fast': fast,
        'autosave': autosave,
        'lang': lang,
      }),
    );
  }

  void _persistRecords() {
    Store.set(
      'records',
      jsonEncode(<String, dynamic>{
        'best': best,
        'scores': scores,
        'unlocked': unlocked.toList(),
      }),
    );
  }

  void update(VoidCallback change) {
    change();
    _persistSettings();
    notifyListeners();
  }

  void previewSensitivity(double v) {
    sensitivity = v;
    notifyListeners();
  }

  void saveSettings() {
    _persistSettings();
  }

  void updateBest(int s) {
    if (s > best) {
      best = s;
      _persistRecords();
      notifyListeners();
    }
  }

  void addScore(int s) {
    if (s <= 0) {
      return;
    }
    scores.add(s);
    scores.sort((int a, int b) => b.compareTo(a));
    if (scores.length > 10) {
      scores = scores.sublist(0, 10);
    }
    _persistRecords();
    notifyListeners();
  }

  void removeScore(int s) {
    if (scores.remove(s)) {
      _persistRecords();
      notifyListeners();
    }
  }

  void markUnlocked(int v) {
    if (v < 2 || unlocked.contains(v)) {
      return;
    }
    unlocked.add(v);
    _persistRecords();
    notifyListeners();
  }

  void setSavedGame(String? g) {
    final bool nullChanged = (savedGame == null) != (g == null);
    savedGame = g;
    Store.set('game', g ?? '');
    if (nullChanged) {
      notifyListeners();
    }
  }

  void commitSavedScore() {
    final String? g = savedGame;
    if (g == null) {
      return;
    }
    try {
      final Map<String, dynamic> m = jsonDecode(g) as Map<String, dynamic>;
      addScore(((m['s'] as num?) ?? 0).toInt());
    } catch (_) {}
  }

  void resetData() {
    best = 0;
    scores = <int>[];
    unlocked = <int>{};
    savedGame = null;
    _persistRecords();
    Store.set('game', '');
    notifyListeners();
  }
}

final AppModel model = AppModel();

const Map<String, String> _hi = <String, String>{
  'welcome': 'Welcome To Anivore',
  'start': 'गेम शुरू करें',
  'resume': 'खेल जारी रखें',
  'records': 'रिकॉर्ड',
  'achievements': 'उपलब्धियाँ',
  'how': 'कैसे खेलें',
  'about': 'ऐप के बारे में',
  'exit': 'बाहर निकलें',
  'settings': 'सेटिंग्स',
  'sound': 'ध्वनि प्रभाव',
  'haptic': 'कंपन',
  'theme': 'थीम',
  'theme_auto': 'ऑटो',
  'theme_light': 'लाइट',
  'theme_dark': 'डार्क',
  'sensitivity': 'स्वाइप संवेदनशीलता',
  'anim': 'एनिमेशन की गति',
  'anim_fast': 'तेज़',
  'anim_normal': 'सामान्य',
  'autosave': 'अपने आप सहेजें',
  'reset': 'डेटा रीसेट करें',
  'reset_q': 'सारे स्कोर और प्रगति मिट जाएँगे। क्या आप रीसेट करना चाहते हैं?',
  'reset_yes': 'रीसेट करें',
  'cancel': 'रद्द करें',
  'language': 'भाषा',
  'version': 'संस्करण 1.0.0',
  'score': 'स्कोर',
  'best': 'सर्वश्रेष्ठ',
  'hint': 'स्वाइप करके टाइल मिलाइए और 2048 बनाइए।',
  'new_game': 'नया खेल',
  'undo': 'पीछे जाएँ',
  'win': 'आप जीत गए!',
  'over': 'खेल खत्म',
  'keep': 'खेलते रहें',
  'again': 'फिर से खेलें',
  'progress': '2048 तक की प्रगति',
  'unlocked': 'अनलॉक की गई टाइलें',
  'no_records': 'अभी कोई रिकॉर्ड नहीं है।',
  'top_scores': 'सबसे अच्छे स्कोर',
  'app_name': 'Anivore',
};

const Map<String, String> _en = <String, String>{
  'welcome': 'Welcome To Anivore',
  'start': 'Start Game',
  'resume': 'Resume Game',
  'records': 'Records',
  'achievements': 'Achievements',
  'how': 'How to Play',
  'about': 'About',
  'exit': 'Exit',
  'settings': 'Settings',
  'sound': 'Sound effects',
  'haptic': 'Vibration',
  'theme': 'Theme',
  'theme_auto': 'Auto',
  'theme_light': 'Light',
  'theme_dark': 'Dark',
  'sensitivity': 'Swipe sensitivity',
  'anim': 'Animation speed',
  'anim_fast': 'Fast',
  'anim_normal': 'Normal',
  'autosave': 'Auto-save progress',
  'reset': 'Reset game data',
  'reset_q': 'All scores and progress will be erased. Do you want to reset?',
  'reset_yes': 'Reset',
  'cancel': 'Cancel',
  'language': 'Language',
  'version': 'Version 1.0.0',
  'score': 'Score',
  'best': 'Best',
  'hint': 'Swipe to join the tiles and make 2048.',
  'new_game': 'New Game',
  'undo': 'Undo',
  'win': 'You win!',
  'over': 'Game over',
  'keep': 'Keep playing',
  'again': 'Play again',
  'progress': 'Progress to 2048',
  'unlocked': 'Unlocked tiles',
  'no_records': 'No records yet.',
  'top_scores': 'Top scores',
  'app_name': 'Anivore',
};

const List<String> _howHi = <String>[
  'ऊपर, नीचे, बाएँ या दाएँ स्वाइप करके सारी टाइलों को उसी दिशा में खिसकाइए।',
  'एक जैसे नंबर की दो टाइलें टकराएँ तो वे जुड़कर दुगुने नंबर की एक टाइल बन जाती हैं।',
  'हर चाल के बाद बोर्ड पर एक नई टाइल (2 या 4) आ जाती है।',
  'लक्ष्य 2048 की टाइल बनाना है। उसके बाद आप चाहें तो आगे खेलते रह सकते हैं।',
  'जब बोर्ड भर जाए और कोई चाल न बचे, तब खेल खत्म हो जाता है।',
  '"पीछे जाएँ" बटन से आख़िरी चाल वापस ली जा सकती है।',
];

const List<String> _howEn = <String>[
  'Swipe up, down, left or right to slide all tiles in that direction.',
  'When two tiles with the same number touch, they merge into one tile with double the number.',
  'After every move a new tile (2 or 4) appears on the board.',
  'The goal is to make the 2048 tile. After that you can keep playing if you like.',
  'When the board is full and no move is left, the game is over.',
  'The Undo button takes back your last move.',
];

const List<String> _aboutHi = <String>[
  'Anivore एक पूरी तरह ऑफ़लाइन 2048 गेम है।',
  'इसमें इंटरनेट, सर्वर या API की की ज़रूरत नहीं पड़ती।',
  'आपका स्कोर और प्रगति आपके फ़ोन में ही सुरक्षित रहती है।',
];

const List<String> _aboutEn = <String>[
  'Anivore is a fully offline 2048 game.',
  'It needs no internet, server or API key.',
  'Your score and progress stay safely on your phone.',
];

String tr(String key) => (model.lang == 'en' ? _en : _hi)[key] ?? key;

List<String> trHow() => model.lang == 'en' ? _howEn : _howHi;

List<String> trAbout() => model.lang == 'en' ? _aboutEn : _aboutHi;

class Tile {
  Tile(this.id, this.value, this.r, this.c);

  final int id;
  int value;
  int r;
  int c;
  bool pop = false;
  bool dying = false;
  int gen = 0;

  Tile copy() {
    final Tile t = Tile(id, value, r, c);
    t.gen = gen;
    return t;
  }
}

List<List<int>> emptyGrid() => List<List<int>>.generate(
      kSize,
      (int _) => List<int>.filled(kSize, 0),
    );

List<List<int>> coordsFor(Dir d, int i) {
  final List<List<int>> out = <List<int>>[];
  for (int k = 0; k < kSize; k++) {
    if (d == Dir.left) {
      out.add(<int>[i, k]);
    } else if (d == Dir.right) {
      out.add(<int>[i, kSize - 1 - k]);
    } else if (d == Dir.up) {
      out.add(<int>[k, i]);
    } else {
      out.add(<int>[kSize - 1 - k, i]);
    }
  }
  return out;
}

bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color mainColor(BuildContext context) =>
    isDark(context) ? Colors.white : Colors.black;

Color softColor(BuildContext context) =>
    isDark(context) ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);

Color panelColor(BuildContext context) =>
    isDark(context) ? const Color(0xFF1F1F1F) : const Color(0xFFEFEFEF);

Color tileColor(int v) {
  switch (v) {
    case 2:
      return const Color(0xFFEEE4DA);
    case 4:
      return const Color(0xFFEDE0C8);
    case 8:
      return const Color(0xFFF2B179);
    case 16:
      return const Color(0xFFF59563);
    case 32:
      return const Color(0xFFF67C5F);
    case 64:
      return const Color(0xFFF65E3B);
    case 128:
      return const Color(0xFFEDCF72);
    case 256:
      return const Color(0xFFEDCC61);
    case 512:
      return const Color(0xFFEDC850);
    case 1024:
      return const Color(0xFFEDC53F);
    case 2048:
      return const Color(0xFFEDC22E);
    default:
      return const Color(0xFF3C3A32);
  }
}

Color tileTextColor(int v) =>
    v <= 4 ? const Color(0xFF776E65) : const Color(0xFFF9F6F2);

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
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? _) {
        return MaterialApp(
          title: 'Anivore',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: model.themeMode == 1
              ? ThemeMode.light
              : model.themeMode == 2
                  ? ThemeMode.dark
                  : ThemeMode.system,
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
      },
    );
  }
}

Widget appButton(
  BuildContext context,
  String label,
  VoidCallback? onTap, {
  bool filled = true,
  double fontSize = 16,
}) {
  final bool dark = isDark(context);
  final Color fg = dark ? Colors.white : Colors.black;
  final Color bg = dark ? Colors.black : Colors.white;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null ? 0.35 : 1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? fg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fg, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: filled ? bg : fg,
          ),
        ),
      ),
    ),
  );
}

Widget topBar(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
    child: Row(
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).maybePop(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.arrow_back, size: 26, color: mainColor(context)),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: mainColor(context),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget pageShell(BuildContext context, String title, List<Widget> children) {
  return Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: <Widget>[
              topBar(context, title),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget sectionLabel(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: softColor(context),
      ),
    ),
  );
}

Widget bulletLine(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '•',
          style: TextStyle(fontSize: 16, height: 1.5, color: mainColor(context)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: mainColor(context),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget toggleRow(
  BuildContext context,
  String label,
  bool value,
  VoidCallback onTap,
) {
  final bool dark = isDark(context);
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: mainColor(context)),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 28,
            padding: const EdgeInsets.all(3),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value
                  ? (dark ? Colors.white : Colors.black)
                  : const Color(0xFF9CA3AF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value && dark ? Colors.black : Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget segmented(
  BuildContext context,
  List<String> labels,
  int selected,
  ValueChanged<int> onChanged,
) {
  final bool dark = isDark(context);
  return Row(
    children: <Widget>[
      for (int i = 0; i < labels.length; i++)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(i),
            child: Container(
              margin: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == selected
                    ? (dark ? Colors.white : Colors.black)
                    : panelColor(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: i == selected
                      ? (dark ? Colors.black : Colors.white)
                      : mainColor(context),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

Widget scoreBox(BuildContext context, String label, int value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: panelColor(context),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: TextStyle(fontSize: 12, color: softColor(context))),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: mainColor(context),
          ),
        ),
      ],
    ),
  );
}

double progressFraction() {
  int count = 0;
  for (final int v in kLevels) {
    if (model.unlocked.contains(v)) {
      count++;
    }
  }
  return count / kLevels.length;
}

Widget progressPanel(BuildContext context, {bool big = false}) {
  final double f = progressFraction();
  final double chip = big ? 52 : 34;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              tr('unlocked'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: softColor(context),
              ),
            ),
          ),
          Text(
            '${(f * 100).round()}%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: softColor(context),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final int v in kLevels)
            Container(
              width: chip,
              height: chip,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: model.unlocked.contains(v)
                    ? tileColor(v)
                    : panelColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    v.toString(),
                    style: TextStyle(
                      fontSize: big ? 16 : 11,
                      fontWeight: FontWeight.bold,
                      color: model.unlocked.contains(v)
                          ? tileTextColor(v)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        tr('progress'),
        style: TextStyle(fontSize: 12, color: softColor(context)),
      ),
      const SizedBox(height: 4),
      Container(
        height: 8,
        decoration: BoxDecoration(
          color: panelColor(context),
          borderRadius: BorderRadius.circular(4),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: f,
          child: Container(
            decoration: BoxDecoration(
              color: mainColor(context),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget logoTile(int v) {
  return Container(
    width: 56,
    height: 56,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: tileColor(v),
      borderRadius: BorderRadius.circular(10),
    ),
    child: FittedBox(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          v.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: tileTextColor(v),
          ),
        ),
      ),
    ),
  );
}

void openPage(BuildContext context, Widget page) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (BuildContext _) => page),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? _) {
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 64, 28, 28),
                      child: Column(
                        children: <Widget>[
                          Text(
                            tr('welcome'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                              color: mainColor(context),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              logoTile(2),
                              const SizedBox(width: 8),
                              logoTile(4),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              logoTile(8),
                              const SizedBox(width: 8),
                              logoTile(2048),
                            ],
                          ),
                          const SizedBox(height: 32),
                          appButton(context, tr('start'), () {
                            model.commitSavedScore();
                            model.setSavedGame(null);
                            openPage(context, const GamePage(resume: false));
                          }),
                          const SizedBox(height: 12),
                          appButton(
                            context,
                            tr('resume'),
                            model.savedGame == null
                                ? null
                                : () => openPage(
                                      context,
                                      const GamePage(resume: true),
                                    ),
                            filled: false,
                          ),
                          const SizedBox(height: 12),
                          appButton(
                            context,
                            tr('records'),
                            () => openPage(context, const RecordsPage()),
                            filled: false,
                          ),
                          const SizedBox(height: 12),
                          appButton(
                            context,
                            tr('achievements'),
                            () => openPage(context, const AchievementsPage()),
                            filled: false,
                          ),
                          const SizedBox(height: 12),
                          appButton(
                            context,
                            tr('how'),
                            () => openPage(context, const HowPage()),
                            filled: false,
                          ),
                          const SizedBox(height: 12),
                          appButton(
                            context,
                            tr('about'),
                            () => openPage(context, const AboutPage()),
                            filled: false,
                          ),
                          const SizedBox(height: 12),
                          appButton(
                            context,
                            tr('exit'),
                            () => SystemNavigator.pop(),
                            filled: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => openPage(context, const SettingsPage()),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.settings_outlined,
                        size: 28,
                        color: mainColor(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? _) {
        return pageShell(context, tr('records'), <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: scoreBox(context, tr('best'), model.best),
          ),
          sectionLabel(context, tr('top_scores')),
          if (model.scores.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                tr('no_records'),
                style: TextStyle(fontSize: 16, color: softColor(context)),
              ),
            ),
          for (int i = 0; i < model.scores.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: panelColor(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    '${i + 1}.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: softColor(context),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    model.scores[i].toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: mainColor(context),
                    ),
                  ),
                ],
              ),
            ),
        ]);
      },
    );
  }
}

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? _) {
        return pageShell(context, tr('achievements'), <Widget>[
          const SizedBox(height: 8),
          progressPanel(context, big: true),
        ]);
      },
    );
  }
}

class HowPage extends StatelessWidget {
  const HowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? _) {
        return pageShell(context, tr('how'), <Widget>[
          for (final String line in trHow()) bulletLine(context, line),
        ]);
      },
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? _) {
        return pageShell(context, tr('about'), <Widget>[
          Text(
            tr('app_name'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: mainColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr('version'),
            style: TextStyle(fontSize: 14, color: softColor(context)),
          ),
          const SizedBox(height: 12),
          for (final String line in trAbout()) bulletLine(context, line),
        ]);
      },
    );
  }
}

Future<void> confirmReset(BuildContext context) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        content: Text(tr('reset_q')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('reset_yes')),
          ),
        ],
      );
    },
  );
  if (ok == true) {
    model.resetData();
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? _) {
        final bool dark = isDark(context);
        return pageShell(context, tr('settings'), <Widget>[
          toggleRow(
            context,
            tr('sound'),
            model.sound,
            () => model.update(() => model.sound = !model.sound),
          ),
          toggleRow(
            context,
            tr('haptic'),
            model.haptic,
            () => model.update(() => model.haptic = !model.haptic),
          ),
          toggleRow(
            context,
            tr('autosave'),
            model.autosave,
            () => model.update(() => model.autosave = !model.autosave),
          ),
          sectionLabel(context, tr('theme')),
          segmented(
            context,
            <String>[tr('theme_auto'), tr('theme_light'), tr('theme_dark')],
            model.themeMode,
            (int i) => model.update(() => model.themeMode = i),
          ),
          sectionLabel(context, tr('sensitivity')),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: dark ? Colors.white : Colors.black,
              inactiveTrackColor: const Color(0xFF9CA3AF),
              thumbColor: dark ? Colors.white : Colors.black,
              overlayColor: Colors.transparent,
              trackHeight: 3,
            ),
            child: Slider(
              value: model.sensitivity,
              onChanged: model.previewSensitivity,
              onChangeEnd: (double v) => model.saveSettings(),
            ),
          ),
          sectionLabel(context, tr('anim')),
          segmented(
            context,
            <String>[tr('anim_normal'), tr('anim_fast')],
            model.fast ? 1 : 0,
            (int i) => model.update(() => model.fast = i == 1),
          ),
          sectionLabel(context, tr('language')),
          segmented(
            context,
            const <String>['हिंदी', 'English'],
            model.lang == 'en' ? 1 : 0,
            (int i) => model.update(() => model.lang = i == 1 ? 'en' : 'hi'),
          ),
          const SizedBox(height: 28),
          appButton(
            context,
            tr('reset'),
            () => confirmReset(context),
            filled: false,
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              tr('version'),
              style: TextStyle(fontSize: 13, color: softColor(context)),
            ),
          ),
        ]);
      },
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.resume});

  final bool resume;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final math.Random _rng = math.Random();
  List<Tile> _tiles = <Tile>[];
  List<Tile>? _prevTiles;
  int _prevScore = 0;
  int _nextId = 1;
  int _score = 0;
  int? _committed;
  bool _busy = false;
  bool _over = false;
  bool _won = false;
  bool _continued = false;
  Offset _drag = Offset.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final String? saved = widget.resume ? model.savedGame : null;
    if (saved == null || !_loadSaved(saved)) {
      _startNew();
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _unlockAll();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!model.autosave && !_over && _score > 0) {
      model.addScore(_score);
    }
    super.dispose();
  }

  bool _loadSaved(String raw) {
    try {
      final Map<String, dynamic> m = jsonDecode(raw) as Map<String, dynamic>;
      final List<dynamic> g = m['g'] as List<dynamic>;
      if (g.length != kSize * kSize) {
        return false;
      }
      final List<Tile> tiles = <Tile>[];
      int id = 1;
      for (int i = 0; i < g.length; i++) {
        final int v = (g[i] as num).toInt();
        if (v > 0) {
          tiles.add(Tile(id, v, i ~/ kSize, i % kSize));
          id++;
        }
      }
      if (tiles.isEmpty) {
        return false;
      }
      _tiles = tiles;
      _nextId = id;
      _score = ((m['s'] as num?) ?? 0).toInt();
      _continued = m['c'] == true;
      _prevTiles = null;
      _committed = null;
      _busy = false;
      _won = !_continued && tiles.any((Tile t) => t.value >= 2048);
      _over = !_canMove();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _startNew() {
    _timer?.cancel();
    _tiles = <Tile>[];
    _prevTiles = null;
    _prevScore = 0;
    _nextId = 1;
    _score = 0;
    _committed = null;
    _busy = false;
    _over = false;
    _won = false;
    _continued = false;
    _spawn();
    _spawn();
  }

  void _newGamePressed() {
    if (!_over && _score > 0) {
      model.addScore(_score);
    }
    model.setSavedGame(null);
    setState(_startNew);
    _unlockAll();
  }

  void _unlockAll() {
    for (final Tile t in _tiles) {
      model.markUnlocked(t.value);
    }
  }

  List<List<int>> _grid() {
    final List<List<int>> g = emptyGrid();
    for (final Tile t in _tiles) {
      if (!t.dying) {
        g[t.r][t.c] = t.value;
      }
    }
    return g;
  }

  List<int> _flat() {
    final List<int> out = <int>[];
    for (final List<int> row in _grid()) {
      out.addAll(row);
    }
    return out;
  }

  bool _canMove() {
    final List<List<int>> g = _grid();
    for (int r = 0; r < kSize; r++) {
      for (int c = 0; c < kSize; c++) {
        if (g[r][c] == 0) {
          return true;
        }
        if (c + 1 < kSize && g[r][c] == g[r][c + 1]) {
          return true;
        }
        if (r + 1 < kSize && g[r][c] == g[r + 1][c]) {
          return true;
        }
      }
    }
    return false;
  }

  void _spawn() {
    final Set<int> used = <int>{};
    for (final Tile t in _tiles) {
      if (!t.dying) {
        used.add(t.r * kSize + t.c);
      }
    }
    final List<int> empty = <int>[];
    for (int i = 0; i < kSize * kSize; i++) {
      if (!used.contains(i)) {
        empty.add(i);
      }
    }
    if (empty.isEmpty) {
      return;
    }
    final int pick = empty[_rng.nextInt(empty.length)];
    final Tile t = Tile(
      _nextId,
      _rng.nextInt(10) == 0 ? 4 : 2,
      pick ~/ kSize,
      pick % kSize,
    );
    _nextId++;
    t.pop = true;
    t.gen = 1;
    _tiles.add(t);
  }

  void _move(Dir d) {
    if (_busy || _over || _won) {
      return;
    }
    final List<Tile> snapshot = <Tile>[
      for (final Tile t in _tiles)
        if (!t.dying) t.copy(),
    ];
    final List<Tile> work = <Tile>[
      for (final Tile t in _tiles)
        if (!t.dying) t.copy(),
    ];
    int gained = 0;
    bool changed = false;
    for (int i = 0; i < kSize; i++) {
      final List<List<int>> cells = coordsFor(d, i);
      final List<Tile> line = <Tile>[];
      for (final List<int> p in cells) {
        for (final Tile t in work) {
          if (!t.dying && t.r == p[0] && t.c == p[1]) {
            line.add(t);
            break;
          }
        }
      }
      int slot = 0;
      int idx = 0;
      while (idx < line.length) {
        final Tile t = line[idx];
        final List<int> target = cells[slot];
        if (idx + 1 < line.length && line[idx + 1].value == t.value) {
          final Tile u = line[idx + 1];
          t.r = target[0];
          t.c = target[1];
          u.r = target[0];
          u.c = target[1];
          u.dying = true;
          t.value = t.value * 2;
          t.pop = true;
          t.gen = t.gen + 1;
          gained += t.value;
          changed = true;
          idx += 2;
        } else {
          if (t.r != target[0] || t.c != target[1]) {
            changed = true;
          }
          t.r = target[0];
          t.c = target[1];
          idx += 1;
        }
        slot += 1;
      }
    }
    if (!changed) {
      return;
    }
    if (model.haptic) {
      HapticFeedback.selectionClick();
    }
    if (model.sound) {
      SystemSound.play(SystemSoundType.click);
    }
    final int before = _score;
    setState(() {
      _prevTiles = snapshot;
      _prevScore = before;
      _tiles = work;
      _score = before + gained;
      _busy = true;
    });
    model.updateBest(_score);
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: model.fast ? 90 : 150), _finishMove);
  }

  void _finishMove() {
    if (!mounted) {
      return;
    }
    setState(() {
      _tiles = _tiles.where((Tile t) => !t.dying).toList();
      _spawn();
      _busy = false;
      if (!_continued && _tiles.any((Tile t) => t.value >= 2048)) {
        _won = true;
      }
      if (!_canMove()) {
        _over = true;
      }
    });
    _unlockAll();
    if (_over) {
      model.addScore(_score);
      _committed = _score;
      model.setSavedGame(null);
    } else {
      _autoSave();
    }
  }

  void _autoSave() {
    if (!model.autosave) {
      return;
    }
    model.setSavedGame(
      jsonEncode(<String, dynamic>{'g': _flat(), 's': _score, 'c': _continued}),
    );
  }

  void _undo() {
    final List<Tile>? p = _prevTiles;
    if (_busy || p == null) {
      return;
    }
    _timer?.cancel();
    final int? committed = _committed;
    if (committed != null) {
      model.removeScore(committed);
      _committed = null;
    }
    setState(() {
      _tiles = p.map((Tile t) => t.copy()).toList();
      _score = _prevScore;
      _prevTiles = null;
      _over = false;
      _won = false;
    });
    _autoSave();
  }

  void _onDragEnd() {
    final double dx = _drag.dx;
    final double dy = _drag.dy;
    final double threshold = 60 - 50 * model.sensitivity;
    if (math.max(dx.abs(), dy.abs()) < threshold) {
      return;
    }
    if (dx.abs() > dy.abs()) {
      _move(dx > 0 ? Dir.right : Dir.left);
    } else {
      _move(dy > 0 ? Dir.down : Dir.up);
    }
  }

  Widget _tileBody(Tile t, double cell) {
    final Widget body = Container(
      decoration: BoxDecoration(
        color: tileColor(t.value),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          child: Text(
            t.value.toString(),
            style: TextStyle(
              fontSize: cell * 0.42,
              fontWeight: FontWeight.bold,
              color: tileTextColor(t.value),
            ),
          ),
        ),
      ),
    );
    if (!t.pop) {
      return body;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('pop-${t.id}-${t.gen}'),
      tween: Tween<double>(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double scale, Widget? child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: body,
    );
  }

  Widget _board(double side, bool dark) {
    const double gap = 8;
    final double cell = (side - gap * (kSize + 1)) / kSize;
    final int ms = model.fast ? 90 : 150;
    final List<Widget> children = <Widget>[];
    for (int r = 0; r < kSize; r++) {
      for (int c = 0; c < kSize; c++) {
        children.add(
          Positioned(
            key: ValueKey<String>('bg-$r-$c'),
            left: gap + c * (cell + gap),
            top: gap + r * (cell + gap),
            width: cell,
            height: cell,
            child: Container(
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF2C2C2C) : const Color(0xFFCDC1B4),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      }
    }
    final List<Tile> ordered = <Tile>[
      ..._tiles.where((Tile t) => t.dying),
      ..._tiles.where((Tile t) => !t.dying),
    ];
    for (final Tile t in ordered) {
      children.add(
        AnimatedPositioned(
          key: ValueKey<int>(t.id),
          duration: Duration(milliseconds: ms),
          curve: Curves.easeOut,
          left: gap + t.c * (cell + gap),
          top: gap + t.r * (cell + gap),
          width: cell,
          height: cell,
          child: _tileBody(t, cell),
        ),
      );
    }
    if (_over || _won) {
      children.add(
        Positioned.fill(
          key: const ValueKey<String>('overlay'),
          child: Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xCC000000) : const Color(0xCCFFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _over ? tr('over') : tr('win'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: mainColor(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    appButton(
                      context,
                      _over ? tr('again') : tr('keep'),
                      _over
                          ? _newGamePressed
                          : () {
                              setState(() {
                                _won = false;
                                _continued = true;
                              });
                              _autoSave();
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1F1F1F) : const Color(0xFFBBADA0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? _) {
        final bool dark = isDark(context);
        return Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (DragStartDetails d) {
              _drag = Offset.zero;
            },
            onPanUpdate: (DragUpdateDetails d) {
              _drag += d.delta;
            },
            onPanEnd: (DragEndDetails d) {
              _onDragEnd();
            },
            child: SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final double side = math.max(
                    160.0,
                    math.min(
                      math.min(c.maxWidth - 40, c.maxHeight - 380),
                      520.0,
                    ),
                  );
                  return Center(
                    child: SizedBox(
                      width: side,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: FittedBox(
                                  alignment: Alignment.centerLeft,
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '2048',
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: mainColor(context),
                                    ),
                                  ),
                                ),
                              ),
                              scoreBox(context, tr('score'), _score),
                              const SizedBox(width: 8),
                              scoreBox(context, tr('best'), model.best),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr('hint'),
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: softColor(context),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _board(side, dark),
                          const SizedBox(height: 16),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: appButton(
                                  context,
                                  tr('new_game'),
                                  _newGamePressed,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: appButton(
                                  context,
                                  tr('undo'),
                                  _prevTiles == null ? null : _undo,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: appButton(
                                  context,
                                  tr('settings'),
                                  () => openPage(context, const SettingsPage()),
                                  filled: false,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          progressPanel(context),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
