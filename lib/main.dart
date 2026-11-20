import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (FlutterErrorDetails d) {};
    PlatformDispatcher.instance.onError = (Object e, StackTrace s) => true;
    ErrorWidget.builder = (FlutterErrorDetails d) => const SizedBox.shrink();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    runApp(const AnivoreApp());
  }, (Object e, StackTrace s) {});
}

class Pal {
  const Pal({
    required this.bg,
    required this.fg,
    required this.muted,
    required this.isDark,
  });

  final Color bg;
  final Color fg;
  final Color muted;
  final bool isDark;

  static const Pal light = Pal(
    bg: Color(0xFFFFFFFF),
    fg: Color(0xFF000000),
    muted: Color(0xFF333333),
    isDark: false,
  );

  static const Pal night = Pal(
    bg: Color(0xFF000000),
    fg: Color(0xFFFFFFFF),
    muted: Color(0xFFD9D9D9),
    isDark: true,
  );

  static Pal of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? night : light;
}

ThemeData buildTheme(Pal p) {
  final scheme = ColorScheme(
    brightness: p.isDark ? Brightness.dark : Brightness.light,
    primary: p.fg,
    onPrimary: p.bg,
    secondary: p.fg,
    onSecondary: p.bg,
    error: p.fg,
    onError: p.bg,
    surface: p.bg,
    onSurface: p.fg,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    dividerColor: p.fg,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.fg,
      selectionColor:
          p.isDark ? const Color(0x66FFFFFF) : const Color(0x55000000),
      selectionHandleColor: p.fg,
    ),
  );
}

final ThemeData lightTheme = buildTheme(Pal.light);
final ThemeData darkTheme = buildTheme(Pal.night);

class NoGlowBehavior extends ScrollBehavior {
  const NoGlowBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

int _int(dynamic v, int d) {
  if (v is int) return v;
  if (v is num) return v.isFinite ? v.toInt() : d;
  if (v is String) return int.tryParse(v) ?? d;
  return d;
}

String _str(dynamic v, String d) => v is String ? v : d;

bool _bool(dynamic v, bool d) => v is bool ? v : d;

int clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

double clampD(double v, double lo, double hi) {
  if (v.isNaN) return lo;
  return v < lo ? lo : (v > hi ? hi : v);
}

String _two(int n) => n.toString().padLeft(2, '0');

String clipText(String s, int n) {
  if (s.length <= n) return s;
  var r = s.substring(0, n);
  if (r.isNotEmpty) {
    final u = r.codeUnitAt(r.length - 1);
    if (u >= 0xD800 && u <= 0xDBFF) r = r.substring(0, r.length - 1);
  }
  return r;
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

String fmtClock(int sec) {
  final t = sec < 0 ? 0 : sec;
  final h = t ~/ 3600;
  final m = (t % 3600) ~/ 60;
  final s = t % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
}

String fmtFocus(int sec) {
  final t = sec < 0 ? 0 : sec;
  final h = t ~/ 3600;
  final m = (t % 3600) ~/ 60;
  return h > 0 ? '$h घं $m मि' : '$m मि';
}

String fmtStamp(int ms) {
  if (ms <= 0 || ms > 8000000000000000) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_two(d.day)}/${_two(d.month)} ${_two(d.hour)}:${_two(d.minute)}';
}

class Mission {
  Mission({
    required this.id,
    required this.title,
    required this.prio,
    this.done = false,
    this.created = 0,
    this.doneMs = 0,
    this.doneDay = '',
  });

  final int id;
  String title;
  int prio;
  bool done;
  int created;
  int doneMs;
  String doneDay;

  Map<String, dynamic> toJson() => {
        'id': id,
        't': title,
        'p': prio,
        'd': done,
        'c': created,
        'dm': doneMs,
        'dd': doneDay,
      };

  static Mission? fromJson(dynamic j) {
    if (j is! Map) return null;
    final t = _str(j['t'], '').trim();
    if (t.isEmpty) return null;
    return Mission(
      id: _int(j['id'], 0),
      title: clipText(t, 120),
      prio: clampInt(_int(j['p'], 1), 0, 2),
      done: _bool(j['d'], false),
      created: _int(j['c'], 0),
      doneMs: _int(j['dm'], 0),
      doneDay: _str(j['dd'], ''),
    );
  }
}

class LogEntry {
  LogEntry({
    required this.id,
    required this.text,
    required this.type,
    required this.ms,
  });

  final int id;
  final String text;
  final int type;
  final int ms;

  Map<String, dynamic> toJson() =>
      {'id': id, 't': text, 'y': type, 'ms': ms};

  static LogEntry? fromJson(dynamic j) {
    if (j is! Map) return null;
    final t = _str(j['t'], '').trim();
    if (t.isEmpty) return null;
    return LogEntry(
      id: _int(j['id'], 0),
      text: clipText(t, 500),
      type: clampInt(_int(j['y'], 0), 0, 1),
      ms: _int(j['ms'], 0),
    );
  }
}

class Activity {
  Activity({required this.ms, required this.text});

  final int ms;
  final String text;

  Map<String, dynamic> toJson() => {'ms': ms, 't': text};

  static Activity? fromJson(dynamic j) {
    if (j is! Map) return null;
    final t = _str(j['t'], '').trim();
    if (t.isEmpty) return null;
    return Activity(ms: _int(j['ms'], 0), text: clipText(t, 200));
  }
}

class AppState extends ChangeNotifier {
  static const String _key = 'anivore_state_v1';
  static const int freeCap = 10;
  static const int proCap = 50;
  static const int freeMaxMinutes = 120;
  static const int proMaxMinutes = 480;
  static const List<String> rankNames = [
    'नौसिखिया',
    'सिपाही',
    'योद्धा',
    'कमांडर',
    'सेनापति',
    'महानायक',
    'अनिवोर लीजेंड',
  ];
  static const List<int> rankMins = [0, 100, 300, 700, 1500, 3000, 6000];
  static const List<String> prioNames = ['कम', 'मध्यम', 'उच्च'];

  SharedPreferences? _prefs;
  bool loaded = false;
  bool _disposed = false;

  bool dark = false;
  bool sound = true;
  bool vibrate = true;
  bool pro = false;
  String name = 'यूजर';
  int points = 0;
  int streak = 0;
  int bestStreak = 0;
  int totalCreated = 0;
  int totalCompleted = 0;
  int focusSeconds = 0;
  int sessions = 0;
  int nextId = 1;
  String lastActive = '';
  int statusFilter = 0;
  int prioFilter = -1;

  int timerTotal = 1500;
  int timerRemaining = 1500;
  int timerEndMs = 0;
  bool timerRunning = false;

  List<Mission> missions = <Mission>[];
  List<LogEntry> logs = <LogEntry>[];
  List<Activity> history = <Activity>[];

  Timer? _ticker;
  Timer? _toastTimer;
  String? toastMsg;

  int get missionCap => pro ? proCap : freeCap;
  int get maxCustom => pro ? proMaxMinutes : freeMaxMinutes;
  List<int> get presets =>
      pro ? const [15, 25, 45, 60, 90, 120] : const [15, 25, 45];

  int missionPoints(int prio) => 10 + 10 * clampInt(prio, 0, 2);

  String today() => dayKey(DateTime.now());

  String _yesterday() {
    final n = DateTime.now();
    return dayKey(DateTime(n.year, n.month, n.day - 1));
  }

  int get effectiveStreak {
    if (lastActive == today() || lastActive == _yesterday()) return streak;
    return 0;
  }

  int get topRank => pro ? rankNames.length - 1 : rankNames.length - 2;

  int get rankIndex {
    var r = 0;
    for (var i = 0; i <= topRank; i++) {
      if (points >= rankMins[i]) r = i;
    }
    return r;
  }

  String get rankName => rankNames[rankIndex];

  double get rankProgress {
    final i = rankIndex;
    if (i >= topRank) return 1.0;
    final span = rankMins[i + 1] - rankMins[i];
    if (span <= 0) return 1.0;
    return clampD((points - rankMins[i]) / span, 0.0, 1.0);
  }

  int get pointsToNext {
    final i = rankIndex;
    if (i >= topRank) return 0;
    return math.max(0, rankMins[i + 1] - points);
  }

  int get successRate {
    if (totalCreated <= 0) return 0;
    final c = math.min(totalCompleted, totalCreated);
    return (c * 100 / totalCreated).round();
  }

  List<Mission> get board {
    final t = today();
    return missions.where((m) => !m.done || m.doneDay == t).toList();
  }

  List<Mission> filtered() {
    var l = board;
    if (statusFilter == 1) l = l.where((m) => !m.done).toList();
    if (statusFilter == 2) l = l.where((m) => m.done).toList();
    if (prioFilter >= 0) l = l.where((m) => m.prio == prioFilter).toList();
    l.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      if (a.prio != b.prio) return b.prio - a.prio;
      return a.created - b.created;
    });
    return l;
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    _toastTimer?.cancel();
    _toastTimer = null;
    super.dispose();
  }

  void _defaults() {
    dark = false;
    sound = true;
    vibrate = true;
    pro = false;
    name = 'यूजर';
    points = 0;
    streak = 0;
    bestStreak = 0;
    totalCreated = 0;
    totalCompleted = 0;
    focusSeconds = 0;
    sessions = 0;
    nextId = 1;
    lastActive = '';
    statusFilter = 0;
    prioFilter = -1;
    timerTotal = 1500;
    timerRemaining = 1500;
    timerEndMs = 0;
    timerRunning = false;
    missions = <Mission>[];
    logs = <LogEntry>[];
    history = <Activity>[];
  }

  Map<String, dynamic> _toJson() => {
        'dark': dark,
        'sound': sound,
        'vibrate': vibrate,
        'pro': pro,
        'name': name,
        'points': points,
        'streak': streak,
        'best': bestStreak,
        'created': totalCreated,
        'completed': totalCompleted,
        'focus': focusSeconds,
        'sessions': sessions,
        'nextId': nextId,
        'last': lastActive,
        'sf': statusFilter,
        'pf': prioFilter,
        'tt': timerTotal,
        'tr': timerRemaining,
        'end': timerEndMs,
        'run': timerRunning,
        'missions': missions.map((e) => e.toJson()).toList(),
        'logs': logs.map((e) => e.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
      };

  void _fromJson(Map<String, dynamic> j) {
    dark = _bool(j['dark'], false);
    sound = _bool(j['sound'], true);
    vibrate = _bool(j['vibrate'], true);
    pro = _bool(j['pro'], false);
    final n = _str(j['name'], 'यूजर').trim();
    name = n.isEmpty ? 'यूजर' : clipText(n, 20);
    points = math.max(0, _int(j['points'], 0));
    streak = math.max(0, _int(j['streak'], 0));
    bestStreak = math.max(streak, _int(j['best'], 0));
    totalCreated = math.max(0, _int(j['created'], 0));
    totalCompleted = math.max(0, _int(j['completed'], 0));
    focusSeconds = math.max(0, _int(j['focus'], 0));
    sessions = math.max(0, _int(j['sessions'], 0));
    nextId = math.max(1, _int(j['nextId'], 1));
    lastActive = _str(j['last'], '');
    statusFilter = clampInt(_int(j['sf'], 0), 0, 2);
    prioFilter = clampInt(_int(j['pf'], -1), -1, 2);

    final ms = j['missions'];
    missions = <Mission>[];
    if (ms is List) {
      for (final e in ms) {
        final m = Mission.fromJson(e);
        if (m != null) missions.add(m);
      }
    }
    final ls = j['logs'];
    logs = <LogEntry>[];
    if (ls is List) {
      for (final e in ls) {
        final l = LogEntry.fromJson(e);
        if (l != null) logs.add(l);
      }
    }
    final hs = j['history'];
    history = <Activity>[];
    if (hs is List) {
      for (final e in hs) {
        final h = Activity.fromJson(e);
        if (h != null) history.add(h);
      }
    }
    if (logs.length > 500) logs = logs.sublist(0, 500);
    if (history.length > 200) history = history.sublist(0, 200);

    var maxId = 0;
    for (final m in missions) {
      maxId = math.max(maxId, m.id);
    }
    for (final l in logs) {
      maxId = math.max(maxId, l.id);
    }
    nextId = math.max(nextId, maxId + 1);

    final cap = (pro ? proMaxMinutes : freeMaxMinutes) * 60;
    timerTotal = clampInt(_int(j['tt'], 1500), 60, cap);
    timerRemaining = clampInt(_int(j['tr'], timerTotal), 0, timerTotal);
    timerRunning = _bool(j['run'], false);
    timerEndMs = _int(j['end'], 0);
    if (timerRunning && timerEndMs <= 0) timerRunning = false;
    if (!timerRunning && timerRemaining <= 0) timerRemaining = timerTotal;
  }

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw);
        if (j is Map) _fromJson(Map<String, dynamic>.from(j));
      }
    } catch (_) {
      _defaults();
    }
    _prune();
    loaded = true;
    if (timerRunning) {
      _startTicker();
      _tick();
    }
    notifyListeners();
  }

  Future<void> persist() async {
    try {
      await _prefs?.setString(_key, jsonEncode(_toJson()));
    } catch (_) {}
  }

  void _changed() {
    notifyListeners();
    persist();
  }

  void onResume() {
    _prune();
    if (timerRunning) {
      _startTicker();
      _tick();
    }
    notifyListeners();
  }

  void _prune() {
    final t = today();
    missions.removeWhere((m) => m.done && m.doneDay != t);
  }

  int _nextId() {
    final v = nextId;
    nextId = nextId + 1;
    return v;
  }

  void toast(String m) {
    toastMsg = m;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      toastMsg = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void _feedback({bool alert = false}) {
    try {
      if (sound) {
        SystemSound.play(alert ? SystemSoundType.alert : SystemSoundType.click)
            .catchError((_) {});
      }
    } catch (_) {}
    try {
      if (vibrate) {
        (alert ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact())
            .catchError((_) {});
      }
    } catch (_) {}
  }

  void _addHistory(String text) {
    history.insert(
      0,
      Activity(ms: DateTime.now().millisecondsSinceEpoch, text: clipText(text, 200)),
    );
    if (history.length > 200) history = history.sublist(0, 200);
  }

  void _touchStreak() {
    final t = today();
    if (lastActive == t) return;
    streak = lastActive == _yesterday() ? streak + 1 : 1;
    lastActive = t;
    if (streak > bestStreak) bestStreak = streak;
  }

  void setDark(bool v) {
    dark = v;
    _changed();
  }

  void setSound(bool v) {
    sound = v;
    _changed();
  }

  void setVibrate(bool v) {
    vibrate = v;
    _changed();
  }

  void setStatusFilter(int v) {
    statusFilter = clampInt(v, 0, 2);
    _changed();
  }

  void setPrioFilter(int v) {
    prioFilter = clampInt(v, -1, 2);
    _changed();
  }

  void setName(String v) {
    final t = v.trim();
    name = t.isEmpty ? 'यूजर' : clipText(t, 20);
    _changed();
  }

  void unlockPro() {
    if (pro) return;
    pro = true;
    _addHistory('प्रो अनलॉक किया गया');
    toast('प्रो सक्रिय हो गया');
    _changed();
  }

  Future<void> resetAll() async {
    _ticker?.cancel();
    _ticker = null;
    _defaults();
    try {
      await _prefs?.remove(_key);
    } catch (_) {}
    toast('सारा लोकल डेटा रीसेट हो गया');
    notifyListeners();
  }

  bool addMission(String raw, int prio) {
    final t = clipText(raw.trim(), 120);
    if (t.isEmpty) {
      toast('मिशन का नाम लिखें');
      return false;
    }
    _prune();
    final active = missions.where((m) => !m.done).length;
    if (active >= missionCap) {
      toast(pro
          ? 'अधिकतम $missionCap सक्रिय मिशन की सीमा पूरी हुई'
          : 'मुफ्त सीमा $missionCap मिशन है, प्रो में 50');
      return false;
    }
    missions.add(Mission(
      id: _nextId(),
      title: t,
      prio: clampInt(prio, 0, 2),
      created: DateTime.now().millisecondsSinceEpoch,
    ));
    totalCreated++;
    _addHistory('मिशन जोड़ा: $t');
    _feedback();
    _changed();
    return true;
  }

  void toggleMission(int id) {
    final i = missions.indexWhere((m) => m.id == id);
    if (i < 0) return;
    final m = missions[i];
    final pts = missionPoints(m.prio);
    if (!m.done) {
      m.done = true;
      m.doneMs = DateTime.now().millisecondsSinceEpoch;
      m.doneDay = today();
      points += pts;
      totalCompleted++;
      _touchStreak();
      _addHistory('मिशन पूरा: ${m.title} (+$pts)');
      toast('+$pts पॉइंट्स');
      _feedback();
    } else {
      m.done = false;
      m.doneMs = 0;
      m.doneDay = '';
      points = math.max(0, points - pts);
      totalCompleted = math.max(0, totalCompleted - 1);
      _addHistory('मिशन फिर खोला: ${m.title}');
    }
    _changed();
  }

  void cyclePrio(int id) {
    final i = missions.indexWhere((m) => m.id == id);
    if (i < 0) return;
    final m = missions[i];
    if (m.done) return;
    m.prio = (m.prio + 1) % 3;
    _changed();
  }

  void deleteMission(int id) {
    final before = missions.length;
    missions.removeWhere((m) => m.id == id);
    if (missions.length != before) {
      _addHistory('मिशन हटाया');
      _changed();
    }
  }

  void clearCompleted() {
    final before = missions.length;
    missions.removeWhere((m) => m.done);
    final n = before - missions.length;
    if (n == 0) {
      toast('कोई पूरा मिशन नहीं है');
      return;
    }
    _addHistory('$n पूरे मिशन हटाए');
    toast('$n पूरे मिशन हटाए');
    _changed();
  }

  bool addLog(String raw, int type) {
    final t = clipText(raw.trim(), 500);
    if (t.isEmpty) {
      toast('पहले कुछ लिखें');
      return false;
    }
    logs.insert(
      0,
      LogEntry(
        id: _nextId(),
        text: t,
        type: clampInt(type, 0, 1),
        ms: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (logs.length > 500) logs = logs.sublist(0, 500);
    _feedback();
    _changed();
    return true;
  }

  void deleteLog(int id) {
    final before = logs.length;
    logs.removeWhere((l) => l.id == id);
    if (logs.length != before) _changed();
  }

  bool setDuration(int minutes) {
    if (timerRunning) {
      toast('पहले टाइमर रोकें या रीसेट करें');
      return false;
    }
    if (minutes < 1 || minutes > maxCustom) {
      toast('1 से $maxCustom के बीच मिनट लिखें');
      return false;
    }
    timerTotal = minutes * 60;
    timerRemaining = timerTotal;
    _changed();
    return true;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void startTimer() {
    if (timerRunning) return;
    if (timerRemaining <= 0 || timerRemaining > timerTotal) {
      timerRemaining = timerTotal;
    }
    timerEndMs =
        DateTime.now().millisecondsSinceEpoch + timerRemaining * 1000;
    timerRunning = true;
    _startTicker();
    _feedback();
    _changed();
  }

  void pauseTimer() {
    if (!timerRunning) return;
    final ms = timerEndMs - DateTime.now().millisecondsSinceEpoch;
    final rem = (ms / 1000).ceil();
    if (rem <= 0) {
      _completeTimer();
      return;
    }
    timerRemaining = clampInt(rem, 1, timerTotal);
    timerRunning = false;
    _stopTicker();
    _changed();
  }

  void resetTimer() {
    _stopTicker();
    timerRunning = false;
    timerRemaining = timerTotal;
    _changed();
  }

  void _tick() {
    if (!timerRunning) {
      _stopTicker();
      return;
    }
    final ms = timerEndMs - DateTime.now().millisecondsSinceEpoch;
    var rem = (ms / 1000).ceil();
    if (rem <= 0) {
      _completeTimer();
      return;
    }
    if (rem > timerTotal) rem = timerTotal;
    timerRemaining = rem;
    notifyListeners();
  }

  void _completeTimer() {
    _stopTicker();
    timerRunning = false;
    final mins = math.max(1, timerTotal ~/ 60);
    final gained = mins * 2;
    points += gained;
    focusSeconds += timerTotal;
    sessions++;
    _touchStreak();
    _addHistory('फोकस सत्र पूरा: $mins मिनट (+$gained)');
    timerRemaining = timerTotal;
    _feedback(alert: true);
    toast('फोकस पूरा: +$gained पॉइंट्स');
    _changed();
  }

  bool runCommand(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      toast('कमांड लिखें');
      return false;
    }
    final i = s.indexOf(RegExp(r'\s'));
    final head = (i < 0 ? s : s.substring(0, i)).toLowerCase();
    final rest = i < 0 ? '' : s.substring(i + 1).trim();
    switch (head) {
      case 'm':
      case 'मिशन':
        return addMission(rest, 1);
      case 'h':
      case 'उच्च':
        return addMission(rest, 2);
      case 'l':
      case 'लॉग':
        return addLog(rest, 0);
      case 'n':
      case 'नोट':
        return addLog(rest, 1);
      case 't':
      case 'टाइमर':
        final m = int.tryParse(rest);
        if (m == null) {
          toast('समय मिनट में लिखें, जैसे t 30');
          return false;
        }
        if (!setDuration(m)) return false;
        startTimer();
        return true;
      case 'c':
      case 'साफ':
        clearCompleted();
        return true;
      default:
        toast('अमान्य कमांड, गाइड देखें');
        return false;
    }
  }
}

class AnivoreApp extends StatefulWidget {
  const AnivoreApp({super.key});

  @override
  State<AnivoreApp> createState() => _AnivoreAppState();
}

class _AnivoreAppState extends State<AnivoreApp> with WidgetsBindingObserver {
  final AppState _s = AppState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _s.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _s.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _s.onResume();
    } else {
      _s.persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _s,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Anivore',
          theme: _s.dark ? darkTheme : lightTheme,
          themeAnimationDuration: Duration.zero,
          scrollBehavior: const NoGlowBehavior(),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler
                    .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: Shell(s: _s),
        );
      },
    );
  }
}

class Press extends StatefulWidget {
  const Press({
    super.key,
    required this.onTap,
    required this.builder,
    this.label,
  });

  final VoidCallback? onTap;
  final Widget Function(bool down) builder;
  final String? label;

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;

  void _set(bool v) {
    if (!mounted || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: widget.builder(_down),
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Press(
      onTap: onTap,
      label: label,
      builder: (down) {
        final inv = filled != down;
        final bgc = inv ? p.fg : p.bg;
        final fgc = inv ? p.bg : p.fg;
        return Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgc,
            border: Border.all(color: p.fg, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: fgc),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fgc,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

class IconBtn extends StatelessWidget {
  const IconBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 44,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Press(
      onTap: onTap,
      label: label,
      builder: (down) {
        final bgc = down ? p.fg : p.bg;
        final fgc = down ? p.bg : p.fg;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgc,
            border: Border.all(color: p.fg, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: fgc),
        );
      },
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Press(
      onTap: onTap,
      label: label,
      builder: (down) {
        final on = selected != down;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: on ? p.fg : p.bg,
            border: Border.all(color: p.fg, width: 1.5),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: on ? p.bg : p.fg,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

class AppCheck extends StatelessWidget {
  const AppCheck({super.key, required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Press(
      onTap: onTap,
      label: value ? 'पूरा' : 'बाकी',
      builder: (down) {
        return SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: value ? p.fg : p.bg,
                border: Border.all(color: p.fg, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: value ? Icon(Icons.check, size: 22, color: p.bg) : null,
            ),
          ),
        );
      },
    );
  }
}

class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Press(
      onTap: () => onChanged(!value),
      label: value ? 'चालू' : 'बंद',
      builder: (down) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Container(
            width: 58,
            height: 34,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: value ? p.fg : p.bg,
              border: Border.all(color: p.fg, width: 2),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? p.bg : p.fg,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppProgress extends StatelessWidget {
  const AppProgress({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final v = clampD(value, 0.0, 1.0);
    return Container(
      height: 16,
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.bg,
        border: Border.all(color: p.fg, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1.0,
            child: Container(color: p.fg),
          ),
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.bottom = 12});

  final Widget child;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.bg,
        border: Border.all(color: p.fg, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.maxLength = 120,
    this.maxLines = 1,
    this.keyboard = TextInputType.text,
    this.digitsOnly = false,
    this.autofocus = false,
    this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final int maxLength;
  final int maxLines;
  final TextInputType keyboard;
  final bool digitsOnly;
  final bool autofocus;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    OutlineInputBorder border(double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.fg, width: w),
        );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: 1,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboard,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
      onSubmitted: (_) => onSubmit?.call(),
      cursorColor: p.fg,
      inputFormatters: [
        LengthLimitingTextInputFormatter(maxLength),
        if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
      ],
      style: TextStyle(color: p.fg, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.muted, fontSize: 15),
        isDense: true,
        filled: true,
        fillColor: p.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: border(1.5),
        enabledBorder: border(1.5),
        focusedBorder: border(2.5),
      ),
    );
  }
}

Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String yes,
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (ctx) {
      final p = Pal.of(ctx);
      return Dialog(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.fg, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    style: TextStyle(
                        color: p.fg, fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(message,
                    style: TextStyle(color: p.fg, fontSize: 15, height: 1.4)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'रद्द करें',
                        onTap: () => Navigator.of(ctx).pop(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: yes,
                        filled: true,
                        onTap: () => Navigator.of(ctx).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return r == true;
}

Future<String?> showInputDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String initial,
  required String confirm,
  TextInputType keyboard = TextInputType.text,
  int maxLength = 40,
  bool digitsOnly = false,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (ctx) => _InputDialog(
      title: title,
      hint: hint,
      initial: initial,
      confirm: confirm,
      keyboard: keyboard,
      maxLength: maxLength,
      digitsOnly: digitsOnly,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.confirm,
    required this.keyboard,
    required this.maxLength,
    required this.digitsOnly,
  });

  final String title;
  final String hint;
  final String initial;
  final String confirm;
  final TextInputType keyboard;
  final int maxLength;
  final bool digitsOnly;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() => Navigator.of(context).pop(_c.text);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Dialog(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.fg, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title,
                  style: TextStyle(
                      color: p.fg, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              AppField(
                controller: _c,
                hint: widget.hint,
                maxLength: widget.maxLength,
                keyboard: widget.keyboard,
                digitsOnly: widget.digitsOnly,
                autofocus: true,
                onSubmit: _ok,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'रद्द करें',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: widget.confirm,
                      filled: true,
                      onTap: _ok,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum Screen { home, account, guide, history, pro }

class Shell extends StatefulWidget {
  const Shell({super.key, required this.s});

  final AppState s;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final List<Screen> _stack = <Screen>[Screen.home];
  DateTime? _lastBack;

  Screen get _cur => _stack.isEmpty ? Screen.home : _stack.last;

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  void _goHome() {
    _unfocus();
    setState(() {
      _stack
        ..clear()
        ..add(Screen.home);
    });
  }

  void _goAccount() {
    _unfocus();
    setState(() {
      _stack
        ..clear()
        ..addAll([Screen.home, Screen.account]);
    });
  }

  void _push(Screen s) {
    _unfocus();
    setState(() => _stack.add(s));
  }

  void _back() {
    if (_stack.length > 1) {
      _unfocus();
      setState(() => _stack.removeLast());
      return;
    }
    final now = DateTime.now();
    final lb = _lastBack;
    if (lb != null && now.difference(lb).inMilliseconds < 2000) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    widget.s.toast('बाहर निकलने के लिए एक बार और वापस दबाएं');
  }

  String _title(Screen s) {
    switch (s) {
      case Screen.home:
        return 'अनिवोर';
      case Screen.account:
        return 'अकाउंट';
      case Screen.guide:
        return 'कमांड गाइड';
      case Screen.history:
        return 'गतिविधि हिस्ट्री';
      case Screen.pro:
        return 'प्रो अपग्रेड';
    }
  }

  String _status(AppState s) {
    final parts = <String>[
      'स्ट्रीक ${s.effectiveStreak}',
      'पॉइंट्स ${s.points}',
    ];
    if (s.timerRunning) parts.add('टाइमर ${fmtClock(s.timerRemaining)}');
    return parts.join('  |  ');
  }

  Widget _topBar(AppState s, Pal p, double topPad) {
    final sub = _stack.length > 1;
    return Container(
      padding: EdgeInsets.fromLTRB(10, topPad + 8, 10, 8),
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(bottom: BorderSide(color: p.fg, width: 2)),
      ),
      child: Row(
        children: [
          if (sub) ...[
            IconBtn(icon: Icons.arrow_back, label: 'वापस', onTap: _back),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: sub ? 0 : 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(_cur),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.fg,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _status(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconBtn(
            icon: s.sound ? Icons.volume_up : Icons.volume_off,
            label: 'साउंड',
            onTap: () => s.setSound(!s.sound),
          ),
          const SizedBox(width: 8),
          IconBtn(
            icon: p.isDark ? Icons.light_mode : Icons.dark_mode,
            label: 'डार्क मोड',
            onTap: () => s.setDark(!s.dark),
          ),
        ],
      ),
    );
  }

  Widget _navItem(Pal p, IconData on, IconData off, bool selected,
      String label, VoidCallback onTap) {
    return Press(
      onTap: onTap,
      label: label,
      builder: (down) {
        final active = selected != down;
        return Container(
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? p.fg : p.bg,
            border: Border.all(color: p.fg, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            selected ? on : off,
            size: 28,
            color: active ? p.bg : p.fg,
          ),
        );
      },
    );
  }

  Widget _bottomNav(Pal p, double bottomPad) {
    final onHome = _stack.length == 1;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPad),
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.fg, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _navItem(p, Icons.home, Icons.home_outlined, onHome,
                'होम', _goHome),
          ),
          Expanded(
            child: _navItem(p, Icons.person, Icons.person_outline, !onHome,
                'अकाउंट', _goAccount),
          ),
        ],
      ),
    );
  }

  Widget _body(AppState s) {
    return switch (_cur) {
      Screen.home => HomeView(key: const ValueKey('home'), s: s),
      Screen.account =>
        AccountView(key: const ValueKey('account'), s: s, onOpen: _push),
      Screen.guide => const GuideView(key: ValueKey('guide')),
      Screen.history => HistoryView(key: const ValueKey('history'), s: s),
      Screen.pro => ProView(key: const ValueKey('pro'), s: s),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.s,
      builder: (ctx, _) {
        final s = widget.s;
        final p = Pal.of(ctx);
        final mq = MediaQuery.of(ctx);
        final kb = mq.viewInsets.bottom;
        final iconB = p.isDark ? Brightness.light : Brightness.dark;
        final overlay = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
          statusBarIconBrightness: iconB,
          systemNavigationBarIconBrightness: iconB,
          statusBarBrightness: p.isDark ? Brightness.dark : Brightness.light,
        );

        if (!s.loaded) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlay,
            child: Scaffold(
              backgroundColor: p.bg,
              body: const SizedBox.expand(),
            ),
          );
        }

        final toastBottom = kb > 0 ? 12.0 : 70.0 + mq.padding.bottom + 12.0;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _back();
            },
            child: Scaffold(
              backgroundColor: p.bg,
              resizeToAvoidBottomInset: true,
              body: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                        left: mq.padding.left, right: mq.padding.right),
                    child: Column(
                      children: [
                        _topBar(s, p, mq.padding.top),
                        Expanded(child: _body(s)),
                        if (kb == 0) _bottomNav(p, mq.padding.bottom),
                      ],
                    ),
                  ),
                  if (s.toastMsg != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: toastBottom,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: p.fg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              s.toastMsg ?? '',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: p.bg,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _heading(String t, Pal p) => Text(
      t,
      style: TextStyle(color: p.fg, fontSize: 17, fontWeight: FontWeight.w800),
    );

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.s});

  final AppState s;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final TextEditingController _cmd = TextEditingController();
  final TextEditingController _mission = TextEditingController();
  final TextEditingController _log = TextEditingController();
  final FocusNode _missionFocus = FocusNode();
  final FocusNode _logFocus = FocusNode();
  int _newPrio = 1;
  int _logType = 0;

  @override
  void dispose() {
    _cmd.dispose();
    _mission.dispose();
    _log.dispose();
    _missionFocus.dispose();
    _logFocus.dispose();
    super.dispose();
  }

  void _runCmd() {
    if (widget.s.runCommand(_cmd.text)) _cmd.clear();
  }

  void _addMission() {
    if (widget.s.addMission(_mission.text, _newPrio)) _mission.clear();
  }

  void _addLog() {
    if (widget.s.addLog(_log.text, _logType)) _log.clear();
  }

  void _quickFocus() {
    final s = widget.s;
    if (s.timerRunning) {
      s.toast('टाइमर पहले से चल रहा है');
      return;
    }
    if (s.setDuration(25)) s.startTimer();
  }

  Future<void> _custom() async {
    final s = widget.s;
    if (s.timerRunning) {
      s.toast('पहले टाइमर रोकें या रीसेट करें');
      return;
    }
    final r = await showInputDialog(
      context,
      title: 'कस्टम समय (मिनट)',
      hint: '1 से ${s.maxCustom}',
      initial: '',
      confirm: 'सेट करें',
      keyboard: TextInputType.number,
      maxLength: 3,
      digitsOnly: true,
    );
    if (!mounted || r == null) return;
    final m = int.tryParse(r.trim());
    if (m == null || m < 1 || m > s.maxCustom) {
      s.toast('1 से ${s.maxCustom} के बीच मिनट लिखें');
      return;
    }
    s.setDuration(m);
  }

  Widget _progressRow(AppState s, Pal p, int pct, int doneN, int total) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('आज की प्रगति',
                      style: TextStyle(color: p.muted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('$pct%',
                      style: TextStyle(
                          color: p.fg,
                          fontSize: 34,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  AppProgress(value: pct / 100),
                  const SizedBox(height: 6),
                  Text('$doneN / $total मिशन',
                      style: TextStyle(color: p.fg, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('स्ट्रीक',
                      style: TextStyle(color: p.muted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${s.effectiveStreak}',
                      style: TextStyle(
                          color: p.fg,
                          fontSize: 34,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('दिन',
                      style: TextStyle(color: p.fg, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('सर्वश्रेष्ठ ${s.bestStreak}',
                      style: TextStyle(color: p.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commandCard(Pal p) {
    final s = widget.s;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('क्विक कमांड पैनल', p),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppField(
                  controller: _cmd,
                  hint: 'उदा: m रिपोर्ट लिखें  |  t 30',
                  maxLength: 140,
                  onSubmit: _runCmd,
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                  label: 'चलाएं',
                  icon: Icons.bolt,
                  filled: true,
                  onTap: _runCmd),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton(
                    label: 'फोकस 25 मि',
                    icon: Icons.play_arrow,
                    onTap: _quickFocus),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                    label: 'नया मिशन',
                    icon: Icons.add,
                    onTap: () => _missionFocus.requestFocus()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton(
                    label: 'नया लॉग',
                    icon: Icons.edit,
                    onTap: () => _logFocus.requestFocus()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                    label: 'पूरे हुए हटाएं',
                    icon: Icons.delete_outline,
                    onTap: s.clearCompleted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timerCard(Pal p) {
    final s = widget.s;
    final total = s.timerTotal <= 0 ? 1 : s.timerTotal;
    final frac = clampD((total - s.timerRemaining) / total, 0.0, 1.0);
    final paused = !s.timerRunning &&
        s.timerRemaining < s.timerTotal &&
        s.timerRemaining > 0;
    final mins = s.timerTotal ~/ 60;
    final isPreset = s.timerTotal % 60 == 0 && s.presets.contains(mins);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('फोकस और एग्ज़ीक्यूशन टाइमर', p),
          const SizedBox(height: 12),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                fmtClock(s.timerRemaining),
                style: TextStyle(
                  color: p.fg,
                  fontSize: 60,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppProgress(value: frac),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in s.presets)
                AppChip(
                  label: '$m मि',
                  selected: s.timerTotal == m * 60,
                  onTap: () => s.setDuration(m),
                ),
              AppChip(label: 'कस्टम', selected: !isPreset, onTap: _custom),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: s.timerRunning
                      ? 'रोकें'
                      : (paused ? 'जारी रखें' : 'शुरू करें'),
                  icon: s.timerRunning ? Icons.pause : Icons.play_arrow,
                  filled: true,
                  onTap: s.timerRunning ? s.pauseTimer : s.startTimer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                    label: 'रीसेट',
                    icon: Icons.restart_alt,
                    onTap: s.resetTimer),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('पूर्ण होने पर +${mins * 2} पॉइंट्स',
              style: TextStyle(color: p.fg, fontSize: 13.5)),
          if (!s.pro) ...[
            const SizedBox(height: 4),
            Text('प्रो में 60, 90, 120 मिनट प्रीसेट और 480 मिनट तक कस्टम समय',
                style: TextStyle(color: p.muted, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  Widget _tile(Mission m, AppState s, Pal p) {
    final high = m.prio == 2;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: p.fg, width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          AppCheck(value: m.done, onTap: () => s.toggleMission(m.id)),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              m.title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.fg,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                decoration:
                    m.done ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor: p.fg,
                decorationThickness: 2,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Press(
            onTap: () => s.cyclePrio(m.id),
            label: 'प्राथमिकता बदलें',
            builder: (down) {
              final on = high != down;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? p.fg : p.bg,
                  border: Border.all(color: p.fg, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppState.prioNames[clampInt(m.prio, 0, 2)],
                  style: TextStyle(
                    color: on ? p.bg : p.fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          IconBtn(
            icon: Icons.delete_outline,
            label: 'हटाएं',
            size: 40,
            onTap: () => s.deleteMission(m.id),
          ),
        ],
      ),
    );
  }

  Widget _missionCard(Pal p) {
    final s = widget.s;
    final list = s.filtered();
    final total = s.board.length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('डेली मिशन और प्रायोरिटी लिस्ट', p),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppField(
                  controller: _mission,
                  focusNode: _missionFocus,
                  hint: 'नया मिशन लिखें',
                  onSubmit: _addMission,
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                  label: 'जोड़ें',
                  icon: Icons.add,
                  filled: true,
                  onTap: _addMission),
            ],
          ),
          const SizedBox(height: 10),
          Text('नए मिशन की प्राथमिकता',
              style: TextStyle(color: p.muted, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                AppChip(
                  label: AppState.prioNames[i],
                  selected: _newPrio == i,
                  onTap: () => setState(() => _newPrio = i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('फ़िल्टर', style: TextStyle(color: p.muted, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                AppChip(
                  label: const ['सभी', 'बाकी', 'पूरे'][i],
                  selected: s.statusFilter == i,
                  onTap: () => s.setStatusFilter(i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppChip(
                  label: 'कोई भी',
                  selected: s.prioFilter == -1,
                  onTap: () => s.setPrioFilter(-1)),
              AppChip(
                  label: 'उच्च',
                  selected: s.prioFilter == 2,
                  onTap: () => s.setPrioFilter(2)),
              AppChip(
                  label: 'मध्यम',
                  selected: s.prioFilter == 1,
                  onTap: () => s.setPrioFilter(1)),
              AppChip(
                  label: 'कम',
                  selected: s.prioFilter == 0,
                  onTap: () => s.setPrioFilter(0)),
            ],
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                total == 0
                    ? 'आज के लिए कोई मिशन नहीं। पहला मिशन जोड़ें।'
                    : 'इस फ़िल्टर में कोई मिशन नहीं।',
                style: TextStyle(color: p.muted, fontSize: 14),
              ),
            )
          else
            for (final m in list) _tile(m, s, p),
        ],
      ),
    );
  }

  Widget _logCard(Pal p) {
    final s = widget.s;
    final shown = s.logs.take(20).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('इंस्टेंट डेली लॉग और नोट्स', p),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppChip(
                  label: 'लॉग',
                  selected: _logType == 0,
                  onTap: () => setState(() => _logType = 0)),
              AppChip(
                  label: 'नोट',
                  selected: _logType == 1,
                  onTap: () => setState(() => _logType = 1)),
            ],
          ),
          const SizedBox(height: 10),
          AppField(
            controller: _log,
            focusNode: _logFocus,
            hint: _logType == 0 ? 'आज क्या किया, लिखें' : 'नोट लिखें',
            maxLength: 500,
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton(
                    label: 'सेव करें',
                    icon: Icons.add,
                    filled: true,
                    onTap: _addLog),
              ),
            ],
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text('अभी कोई प्रविष्टि नहीं।',
                  style: TextStyle(color: p.muted, fontSize: 14)),
            )
          else
            for (final l in shown)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                decoration: BoxDecoration(
                  border: Border.all(color: p.fg, width: 1.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l.type == 0 ? 'लॉग' : 'नोट'}  |  ${fmtStamp(l.ms)}',
                            style: TextStyle(
                                color: p.muted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(l.text,
                              style: TextStyle(
                                  color: p.fg, fontSize: 15, height: 1.35)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconBtn(
                      icon: Icons.delete_outline,
                      label: 'हटाएं',
                      size: 40,
                      onTap: () => s.deleteLog(l.id),
                    ),
                  ],
                ),
              ),
          if (s.logs.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('कुल ${s.logs.length} प्रविष्टियां, नवीनतम 20 दिखाई गईं',
                  style: TextStyle(color: p.muted, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final p = Pal.of(context);
    final board = s.board;
    final total = board.length;
    final doneN = board.where((m) => m.done).length;
    final pct = total == 0 ? 0 : (doneN * 100 / total).round();
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _progressRow(s, p, pct, doneN, total),
        _commandCard(p),
        _timerCard(p),
        _missionCard(p),
        _logCard(p),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.muted, fontSize: 13)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    color: p.fg, fontSize: 24, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Press(
      onTap: onTap,
      label: label,
      builder: (down) {
        final bgc = down ? p.fg : p.bg;
        final fgc = down ? p.bg : p.fg;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: bgc,
            border: Border.all(color: p.fg, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: fgc, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Icon(Icons.chevron_right, color: fgc),
            ],
          ),
        );
      },
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow(
      {required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: p.fg, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        AppSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(width: 6, height: 6, color: p.fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: p.fg, fontSize: 15, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class AccountView extends StatelessWidget {
  const AccountView({super.key, required this.s, required this.onOpen});

  final AppState s;
  final void Function(Screen) onOpen;

  Widget _pair(Widget a, Widget b) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final r = await showInputDialog(
      context,
      title: 'नाम बदलें',
      hint: 'आपका नाम',
      initial: s.name,
      confirm: 'सेव करें',
      maxLength: 20,
    );
    if (r == null) return;
    s.setName(r);
  }

  Future<void> _reset(BuildContext context) async {
    final ok = await showConfirm(
      context,
      title: 'सारा डेटा रीसेट',
      message:
          'सभी मिशन, पॉइंट्स, स्ट्रीक, लॉग, हिस्ट्री और सेटिंग्स हमेशा के लिए हट जाएंगी। क्या आप निश्चित हैं?',
      yes: 'रीसेट करें',
    );
    if (!ok) return;
    await s.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final initial = s.name.isEmpty
        ? '?'
        : String.fromCharCode(s.name.runes.first).toUpperCase();
    final nextText = s.rankIndex >= s.topRank
        ? (s.pro ? 'सर्वोच्च रैंक प्राप्त' : 'अगला रैंक प्रो में उपलब्ध')
        : 'अगला रैंक: ${AppState.rankNames[s.rankIndex + 1]}  |  ${s.pointsToNext} पॉइंट्स बाकी';
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: p.fg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(initial,
                          style: TextStyle(
                              color: p.bg,
                              fontSize: 30,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: p.fg,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(s.rankName,
                                style: TextStyle(
                                    color: p.fg,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            if (s.pro)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: p.fg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('PRO',
                                    style: TextStyle(
                                        color: p.bg,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                        label: 'नाम बदलें',
                        icon: Icons.edit,
                        onTap: () => _rename(context)),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('रैंक टियर',
                  style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 4),
              Text(s.rankName,
                  style: TextStyle(
                      color: p.fg, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              AppProgress(value: s.rankProgress),
              const SizedBox(height: 8),
              Text(nextText, style: TextStyle(color: p.fg, fontSize: 14)),
            ],
          ),
        ),
        _pair(
          _StatBox(label: 'कुल पॉइंट्स', value: '${s.points}'),
          _StatBox(label: 'वर्तमान स्ट्रीक', value: '${s.effectiveStreak} दिन'),
        ),
        _pair(
          _StatBox(label: 'सर्वश्रेष्ठ स्ट्रीक', value: '${s.bestStreak} दिन'),
          _StatBox(label: 'पूर्ण मिशन', value: '${s.totalCompleted}'),
        ),
        _pair(
          _StatBox(label: 'कुल फोकस समय', value: fmtFocus(s.focusSeconds)),
          _StatBox(label: 'सफलता दर', value: '${s.successRate}%'),
        ),
        _pair(
          _StatBox(label: 'फोकस सत्र', value: '${s.sessions}'),
          _StatBox(label: 'बनाए गए मिशन', value: '${s.totalCreated}'),
        ),
        _MenuRow(label: 'गतिविधि हिस्ट्री', onTap: () => onOpen(Screen.history)),
        _MenuRow(
            label: 'कमांड गाइड और नियम', onTap: () => onOpen(Screen.guide)),
        _MenuRow(
            label: s.pro ? 'प्रो सक्रिय' : 'प्रो अपग्रेड',
            onTap: () => onOpen(Screen.pro)),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading('सेटिंग्स', p),
              const SizedBox(height: 6),
              _SwitchRow(
                  label: 'डार्क मोड', value: s.dark, onChanged: s.setDark),
              _SwitchRow(label: 'साउंड', value: s.sound, onChanged: s.setSound),
              _SwitchRow(
                  label: 'वाइब्रेशन',
                  value: s.vibrate,
                  onChanged: s.setVibrate),
              const SizedBox(height: 10),
              AppButton(
                label: 'सारा लोकल डेटा रीसेट करें',
                icon: Icons.delete_forever,
                onTap: () => _reset(context),
              ),
            ],
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Anivore 1.0.0  |  com.anivore.com',
                style: TextStyle(color: p.muted, fontSize: 12.5)),
          ),
        ),
      ],
    );
  }
}

class HistoryView extends StatelessWidget {
  const HistoryView({super.key, required this.s});

  final AppState s;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final list = s.history;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('अभी कोई गतिविधि दर्ज नहीं है।',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 16)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final a = list[i];
        return AppCard(
          bottom: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(fmtStamp(a.ms),
                  style: TextStyle(
                      color: p.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(a.text,
                  style: TextStyle(color: p.fg, fontSize: 15, height: 1.35)),
            ],
          ),
        );
      },
    );
  }
}

class GuideView extends StatelessWidget {
  const GuideView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget section(String title, List<String> items) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(title, p),
            for (final t in items) _Bullet(t),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        section('कमांड सूची', const [
          'm नाम : सामान्य प्राथमिकता का मिशन जोड़ें',
          'h नाम : उच्च प्राथमिकता का मिशन जोड़ें',
          'l टेक्स्ट : डेली लॉग जोड़ें',
          'n टेक्स्ट : नोट जोड़ें',
          't मिनट : उतने मिनट का फोकस टाइमर शुरू करें',
          'c : पूरे हुए मिशन हटाएं',
          'हिंदी नाम भी चलते हैं: मिशन, उच्च, लॉग, नोट, टाइमर, साफ',
        ]),
        section('पॉइंट्स प्रणाली', const [
          'कम प्राथमिकता का मिशन पूरा करने पर 10 पॉइंट्स',
          'मध्यम प्राथमिकता का मिशन पूरा करने पर 20 पॉइंट्स',
          'उच्च प्राथमिकता का मिशन पूरा करने पर 30 पॉइंट्स',
          'फोकस टाइमर पूरा होने पर हर मिनट के 2 पॉइंट्स',
          'टाइमर बीच में रोकने या रीसेट करने पर पॉइंट्स नहीं मिलते',
        ]),
        section('स्ट्रीक नियम', const [
          'किसी दिन कम से कम एक मिशन या एक फोकस सत्र पूरा करें',
          'लगातार दिनों पर स्ट्रीक बढ़ती है',
          'एक दिन चूकने पर स्ट्रीक फिर 1 से शुरू होती है',
        ]),
        section('रैंक टियर', [
          for (var i = 0; i < AppState.rankNames.length; i++)
            '${AppState.rankNames[i]} : ${AppState.rankMins[i]} पॉइंट्स'
                '${i == AppState.rankNames.length - 1 ? ' (केवल प्रो)' : ''}',
        ]),
        section('सीमाएं', const [
          'मुफ्त: 10 सक्रिय मिशन और अधिकतम 120 मिनट का टाइमर',
          'प्रो: 50 सक्रिय मिशन और अधिकतम 480 मिनट का टाइमर',
          'आज पूरे किए मिशन अगले दिन बोर्ड से हट जाते हैं',
          'अधूरे मिशन अगले दिनों में भी बने रहते हैं',
        ]),
        section('नेविगेशन', const [
          'वापस बटन एक बार में एक स्तर पीछे ले जाता है',
          'होम स्क्रीन पर बाहर निकलने के लिए दो बार वापस दबाएं',
          'सारा डेटा केवल इसी फोन में सुरक्षित रहता है',
        ]),
      ],
    );
  }
}

class ProView extends StatelessWidget {
  const ProView({super.key, required this.s});

  final AppState s;

  Future<void> _unlock(BuildContext context) async {
    final ok = await showConfirm(
      context,
      title: 'प्रो अनलॉक',
      message: 'यह एक बार का अनलॉक है और इस डिवाइस पर सुरक्षित रहेगा।',
      yes: 'अनलॉक करें',
    );
    if (!ok) return;
    s.unlockPro();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.pro ? 'प्रो सक्रिय है' : 'मुफ्त संस्करण',
                  style: TextStyle(
                      color: p.fg, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                  s.pro
                      ? 'सभी प्रो सुविधाएं अनलॉक हैं।'
                      : 'एक बार अनलॉक करें और सभी प्रो सुविधाएं पाएं।',
                  style: TextStyle(color: p.fg, fontSize: 15)),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading('प्रो में क्या मिलता है', p),
              const _Bullet('मिशन क्षमता 10 से बढ़कर 50 सक्रिय मिशन'),
              const _Bullet(
                  'एडवांस टाइमर: 60, 90, 120 मिनट प्रीसेट और 480 मिनट तक कस्टम समय'),
              const _Bullet('विशेष PRO रैंक बैज'),
              const _Bullet('सर्वोच्च रैंक: अनिवोर लीजेंड'),
            ],
          ),
        ),
        if (!s.pro)
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'प्रो अनलॉक करें',
                  icon: Icons.lock_open,
                  filled: true,
                  onTap: () => _unlock(context),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
