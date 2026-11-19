import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

int _i(Map m, String k, int d) {
  final v = m[k];
  return v is num ? v.toInt() : d;
}

bool _b(Map m, String k, bool d) {
  final v = m[k];
  return v is bool ? v : d;
}

String _s(Map m, String k, String d) {
  final v = m[k];
  return v is String ? v : d;
}

List<int> _li(dynamic v, List<int> d) {
  if (v is List) {
    return v.map<int>((e) => (e as num).toInt()).toList();
  }
  return d;
}

class Pal {
  final Color bg, ink, dim, faint;
  const Pal(this.bg, this.ink, this.dim, this.faint);
  static const l = Pal(Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFF444444), Color(0xFFE6E6E6));
  static const d = Pal(Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFFD0D0D0), Color(0xFF2A2A2A));
}

Pal get pal => app.dark ? Pal.d : Pal.l;

const kVersion = '1.0.0';
const kSectors = 300;
const kFreeSectors = 60;
const kTierNames = ['ब्रॉन्ज़', 'सिल्वर', 'गोल्ड', 'प्लैटिनम', 'डायमंड', 'मास्टर', 'ग्रैंडमास्टर'];
const kTierMin = [0, 300, 1000, 2500, 5000, 9000, 15000];
const kProf = ['आक्रामक', 'रक्षक', 'संतुलित'];
const kProfD = [
  'लाइन बनाने पर पूरा ज़ोर देता है',
  'आपकी लाइनें रोकने को प्राथमिकता देता है',
  'आक्रमण और रक्षा में संतुलित रहता है'
];
const kRivals = [
  'वज्र', 'अग्नि', 'नेत्र', 'कवच', 'शौर्य', 'ध्रुव', 'रुद्र', 'आर्य', 'वीर', 'सिंह', 'अर्जुन', 'भीम',
  'तक्षक', 'गरुड़', 'नाग', 'व्योम', 'अश्व', 'मेघ', 'कृष', 'इंद्र', 'विक्रम', 'सागर', 'अंश', 'यश'
];
const kAv = ['', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'K', 'M', 'R', 'S'];
const kStages = ['क्वार्टरफाइनल', 'सेमीफाइनल', 'फाइनल'];
const kTags = ['शानदार चाल', 'सावधान', 'दबाव बनाएँ', 'रक्षा करें', 'अच्छा खेल'];

final kBoardNames = List<String>.generate(30, (i) => i < 24 ? kRivals[i] : '${kRivals[i - 24]}_$i');
final kBoardPts = List<int>.generate(30, (i) => (22000 * pow(0.86, i)).round() + (i * 37 % 91));

class Md {
  final String n, d;
  const Md(this.n, this.d);
}

const kModes = [
  Md('सेक्टर कमांड', 'सेक्टर चुनें और राइवल को हराएँ'),
  Md('टैक्टिकल कमांड', 'एआई प्रतिद्वंद्वी के विरुद्ध सिंगल प्लेयर'),
  Md('दो खिलाड़ी बैटल', 'एक ही फोन पर आमने-सामने'),
  Md('तीन खिलाड़ी राउंड', 'तीन खिलाड़ी बारी-बारी से'),
  Md('राइवल स्कोर मुकाबला', 'सिम्युलेटेड राइवल का स्कोर पार करें'),
  Md('टूर्नामेंट', 'तीन राउंड की नॉकआउट सीरीज़'),
  Md('टाइम अटैक', 'काउंटडाउन खत्म होने तक अधिकतम स्कोर'),
  Md('मूव लिमिट', 'सीमित चालों में बढ़त बनाएँ'),
  Md('टारगेट स्कोर', 'पहले लक्ष्य स्कोर तक पहुँचें'),
  Md('एंडलेस सर्वाइवल', 'बोर्ड बढ़ता रहता है, जीवन सीमित'),
  Md('सडन डेथ', 'पहली लाइन बनाने वाला जीतता है'),
  Md('रैपिड ब्लिट्ज', 'हर चाल के लिए केवल 5 सेकंड'),
];

final app = AppState();
final nav = Nav();
final navKey = GlobalKey<NavigatorState>();
final msgKey = GlobalKey<ScaffoldMessengerState>();

class Cfg {
  final int mode, n, players, profile, target, moveLimit, timeLimit, turnSecs, blocked, sector, diff, round, seed;
  final bool ai;
  final String rival;
  const Cfg({
    this.mode = 1,
    this.n = 4,
    this.players = 2,
    this.ai = true,
    this.profile = 2,
    this.rival = '',
    this.target = 0,
    this.moveLimit = 0,
    this.timeLimit = 0,
    this.turnSecs = 20,
    this.blocked = 0,
    this.sector = 0,
    this.diff = 3,
    this.round = -1,
    this.seed = 1,
  });
  bool get rivalSim => mode == 4;
  Cfg copy({int? mode, int? n, String? rival, int? seed, int? moveLimit, int? target, int? timeLimit, int? blocked}) => Cfg(
        mode: mode ?? this.mode,
        n: n ?? this.n,
        players: players,
        ai: ai,
        profile: profile,
        rival: rival ?? this.rival,
        target: target ?? this.target,
        moveLimit: moveLimit ?? this.moveLimit,
        timeLimit: timeLimit ?? this.timeLimit,
        turnSecs: turnSecs,
        blocked: blocked ?? this.blocked,
        sector: sector,
        diff: diff,
        round: round,
        seed: seed ?? this.seed,
      );
  Map<String, dynamic> toJson() => {
        'mode': mode, 'n': n, 'players': players, 'ai': ai, 'profile': profile, 'rival': rival,
        'target': target, 'mv': moveLimit, 'tl': timeLimit, 'ts': turnSecs, 'blocked': blocked,
        'sector': sector, 'diff': diff, 'round': round, 'seed': seed,
      };
  factory Cfg.fromJson(Map m) => Cfg(
        mode: min(11, max(0, _i(m, 'mode', 1))),
        n: min(9, max(3, _i(m, 'n', 4))),
        players: min(3, max(1, _i(m, 'players', 2))),
        ai: _b(m, 'ai', true),
        profile: min(2, max(0, _i(m, 'profile', 2))),
        rival: _s(m, 'rival', ''),
        target: _i(m, 'target', 0),
        moveLimit: _i(m, 'mv', 0),
        timeLimit: _i(m, 'tl', 0),
        turnSecs: max(3, _i(m, 'ts', 20)),
        blocked: _i(m, 'blocked', 0),
        sector: _i(m, 'sector', 0),
        diff: _i(m, 'diff', 3),
        round: _i(m, 'round', -1),
        seed: _i(m, 'seed', 1),
      );
}

Cfg makeCfg(int mode, int n, int prof, String rival, {int sector = 0, int diff = 3, int round = -1, int blocked = 0}) {
  final base = app.speed == 0 ? 30 : (app.speed == 1 ? 20 : 12);
  int players = 2, target = 0, mv = 0, tl = 0, ts = base;
  bool ai = true;
  if (mode == 2) {
    ai = false;
  } else if (mode == 3) {
    ai = false;
    players = 3;
  } else if (mode == 4 || mode == 9) {
    ai = false;
    players = 1;
  }
  if (mode == 6) tl = 60 + n * 15;
  if (mode == 7) mv = ((n * n - blocked) * 0.4).ceil() + 1;
  if (mode == 8) target = n * n * 2 + 4;
  if (mode == 11) ts = 5;
  return Cfg(
    mode: mode, n: n, players: players, ai: ai, profile: prof, rival: rival, target: target,
    moveLimit: mv, timeLimit: tl, turnSecs: ts, blocked: blocked, sector: sector, diff: diff,
    round: round, seed: Random().nextInt(1 << 30),
  );
}

Cfg sectorCfg(int s) {
  final tier = (s - 1) ~/ 6;
  final n = s <= kFreeSectors ? 3 + tier % 3 : 3 + tier % 5;
  final diff = min(10, (s - 1) % 6 + tier ~/ 5);
  final blocked = ((n * n) * (diff % 4) * 0.05).floor();
  final prof = (s + tier) % 3;
  return makeCfg(0, n, prof, kRivals[(s * 7) % kRivals.length], sector: s, diff: diff, blocked: blocked);
}

bool unlocked(int s) {
  if (s > kFreeSectors && !app.pro) return false;
  if (s <= 1) return true;
  final b = app.sec['${s - 1}'];
  return b != null && b[1] > 0;
}

class Scan {
  int bonus = 0, lines = 0, run = 1;
  List<int> cells = [];
}

class Snap {
  final List<int> cells, scores, combo, left, moves, acc;
  final int turn, n, rival, tc;
  Snap(this.cells, this.scores, this.combo, this.left, this.moves, this.acc, this.turn, this.n, this.rival, this.tc);
}

class Game {
  Cfg cfg;
  int n;
  bool boost, unlimited;
  List<int> cells = [], scores = [], combo = [], maxCombo = [], moves = [], acc = [], left = [];
  int turn = 0, turnLeft = 0, timeLeft = 0, rivalScore = 0, lives = 3, frozen = 0, undo = 3;
  int hints = 3, freeze = 2, extend = 2, extra = 2, expand = 2, clearLeft = 1, revive = 1;
  int turnCount = 0, winner = -2, hint = -1, last = -1, lastBonus = 0;
  bool finished = false, extraTurn = false;
  List<int> flash = [];
  List<String> log = [];
  List<Snap> snaps = [];
  final Random rnd = Random();

  Game(this.cfg, {this.boost = false, this.unlimited = false}) : n = cfg.n {
    cells = List<int>.filled(n * n, -1);
    final k = cfg.players;
    scores = List<int>.filled(k, 0);
    combo = List<int>.filled(k, 0);
    maxCombo = List<int>.filled(k, 0);
    moves = List<int>.filled(k, 0);
    acc = List<int>.filled(k, 0);
    left = List<int>.filled(k, cfg.moveLimit);
    turnLeft = cfg.turnSecs;
    timeLeft = cfg.timeLimit;
    undo = unlimited ? 99 : 3;
    final idx = List<int>.generate(n * n, (i) => i)..shuffle(Random(cfg.seed));
    final bl = min(cfg.blocked, n * n - 3);
    for (int i = 0; i < bl; i++) {
      cells[idx[i]] = -2;
    }
  }

  factory Game.fromJson(Map m) {
    final c = Cfg.fromJson(m['cfg'] as Map);
    final g = Game(c, boost: _b(m, 'boost', false), unlimited: _b(m, 'unl', false));
    g.n = _i(m, 'n', c.n);
    g.cells = _li(m['cells'], g.cells);
    final k = c.players;
    g.scores = _li(m['scores'], g.scores);
    g.combo = _li(m['combo'], g.combo);
    g.maxCombo = _li(m['maxCombo'], g.maxCombo);
    g.moves = _li(m['moves'], g.moves);
    g.acc = _li(m['acc'], g.acc);
    g.left = _li(m['left'], g.left);
    if (g.cells.length != g.n * g.n || g.scores.length != k || g.combo.length != k || g.maxCombo.length != k ||
        g.moves.length != k || g.acc.length != k || g.left.length != k) {
      throw const FormatException('state');
    }
    g.turn = min(k - 1, max(0, _i(m, 'turn', 0)));
    g.turnLeft = _i(m, 'turnLeft', c.turnSecs);
    g.timeLeft = _i(m, 'timeLeft', c.timeLimit);
    g.rivalScore = _i(m, 'rival', 0);
    g.lives = _i(m, 'lives', 3);
    g.undo = _i(m, 'undo', 3);
    g.hints = _i(m, 'hints', 3);
    g.freeze = _i(m, 'freeze', 2);
    g.extend = _i(m, 'extend', 2);
    g.extra = _i(m, 'extra', 2);
    g.expand = _i(m, 'expand', 2);
    g.clearLeft = _i(m, 'clearLeft', 1);
    g.revive = _i(m, 'revive', 1);
    g.turnCount = _i(m, 'tc', 0);
    final lg = m['log'];
    if (lg is List) g.log = lg.map((e) => e.toString()).toList();
    return g;
  }

  Map<String, dynamic> toJson() => {
        'cfg': cfg.toJson(), 'n': n, 'cells': cells, 'scores': scores, 'combo': combo, 'maxCombo': maxCombo,
        'moves': moves, 'acc': acc, 'left': left, 'turn': turn, 'turnLeft': turnLeft, 'timeLeft': timeLeft,
        'rival': rivalScore, 'lives': lives, 'undo': undo, 'hints': hints, 'freeze': freeze, 'extend': extend,
        'extra': extra, 'expand': expand, 'clearLeft': clearLeft, 'revive': revive, 'tc': turnCount,
        'log': log.take(60).toList(), 'boost': boost, 'unl': unlimited,
      };

  int get empties => cells.where((e) => e == -1).length;
  int get result => winner == 0 ? 1 : (winner == -1 ? 0 : -1);

  String pn(int p) {
    if (cfg.ai) return p == 0 ? app.name : cfg.rival;
    if (cfg.players == 1) return app.name;
    return 'खिलाड़ी ${p + 1}';
  }

  String coord(int i) => String.fromCharCode(65 + i % n) + '${i ~/ n + 1}';

  Scan scan(int idx, int p) {
    final s = Scan();
    final r = idx ~/ n, c = idx % n;
    const ds = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (final d in ds) {
      final line = <int>[idx];
      for (final sg in const [1, -1]) {
        int rr = r + d[0] * sg, cc = c + d[1] * sg;
        while (rr >= 0 && rr < n && cc >= 0 && cc < n && cells[rr * n + cc] == p) {
          line.add(rr * n + cc);
          rr += d[0] * sg;
          cc += d[1] * sg;
        }
      }
      if (line.length > s.run) s.run = line.length;
      if (line.length >= 3) {
        s.bonus += (line.length - 2) * 3;
        s.lines++;
        s.cells.addAll(line);
      }
    }
    return s;
  }

  Scan probe(int idx, int p) {
    cells[idx] = p;
    final s = scan(idx, p);
    cells[idx] = -1;
    return s;
  }

  double _val(Scan s) => 1 + s.bonus + (s.lines > 1 ? s.lines * 2 : 0) + (s.run - 1) * 0.7;

  int pick(int p, int prof, double noise) {
    double best = -1e9;
    int bi = -1;
    final cn = (n - 1) / 2.0;
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] != -1) continue;
      final a = _val(probe(i, p));
      double o = 0;
      for (int q = 0; q < cfg.players; q++) {
        if (q == p) continue;
        final v = _val(probe(i, q));
        if (v > o) o = v;
      }
      final wa = prof == 0 ? 1.0 : (prof == 1 ? 0.5 : 0.8);
      final wd = prof == 0 ? 0.3 : (prof == 1 ? 1.0 : 0.8);
      final dist = ((i ~/ n) - cn).abs() + ((i % n) - cn).abs();
      final v = a * wa + o * wd - dist * 0.05 + rnd.nextDouble() * noise;
      if (v > best) {
        best = v;
        bi = i;
      }
    }
    return bi;
  }

  Snap _snap() => Snap(List.of(cells), List.of(scores), List.of(combo), List.of(left), List.of(moves), List.of(acc),
      turn, n, rivalScore, turnCount);

  void _restore(Snap s) {
    cells = List.of(s.cells);
    scores = List.of(s.scores);
    combo = List.of(s.combo);
    left = List.of(s.left);
    moves = List.of(s.moves);
    acc = List.of(s.acc);
    turn = s.turn;
    n = s.n;
    rivalScore = s.rival;
    turnCount = s.tc;
    flash = [];
    hint = -1;
    last = -1;
    turnLeft = cfg.turnSecs;
    finished = false;
    winner = -2;
  }

  int _rivalStep() {
    final f = cfg.profile == 0 ? 1.15 : (cfg.profile == 1 ? 0.9 : 1.0);
    final avg = (2.0 + cfg.n * 0.5 + cfg.diff * 0.2) * f;
    return max(0, (avg * (0.5 + rnd.nextDouble())).round());
  }

  int play(int idx) {
    if (finished || idx < 0 || idx >= cells.length || cells[idx] != -1) return 0;
    snaps.add(_snap());
    if (snaps.length > 200) snaps.removeAt(0);
    final p = turn;
    cells[idx] = p;
    final s = scan(idx, p);
    int g = 1 + s.bonus + (s.lines > 1 ? s.lines * 2 : 0);
    if (s.bonus > 0) {
      combo[p]++;
      if (combo[p] > maxCombo[p]) maxCombo[p] = combo[p];
    } else {
      combo[p] = 0;
    }
    if (combo[p] > 1) g = (g * (10 + min(combo[p] - 1, 4) * 5) / 10).round();
    if (boost && p == 0 && (cfg.ai || cfg.players == 1)) g *= 2;
    scores[p] += g;
    moves[p]++;
    if (s.run >= 2) acc[p]++;
    flash = s.bonus > 0 ? s.cells : [];
    last = idx;
    hint = -1;
    turnCount++;
    lastBonus = s.bonus;
    if (cfg.moveLimit > 0) left[p]--;
    if (cfg.rivalSim) rivalScore += _rivalStep();
    log.insert(0, '#$turnCount ${pn(p)} ${coord(idx)} +$g');
    if (log.length > 200) log.removeRange(200, log.length);
    _after(p);
    return g;
  }

  void _after(int p) {
    if (cfg.mode == 10 && lastBonus > 0) {
      finished = true;
      winner = p;
      return;
    }
    if (cfg.target > 0) {
      for (int q = 0; q < cfg.players; q++) {
        if (scores[q] >= cfg.target) {
          finished = true;
          winner = q;
          return;
        }
      }
    }
    if (cfg.timeLimit > 0 && timeLeft <= 0) {
      byScore();
      return;
    }
    if (cfg.moveLimit > 0 && left.every((e) => e <= 0)) {
      byScore();
      return;
    }
    if (empties == 0) {
      if (cfg.mode == 9 && n < 9) {
        expandBoard();
      } else {
        byScore();
        return;
      }
    }
    _advance();
  }

  void _advance() {
    if (extraTurn) {
      extraTurn = false;
      turnLeft = cfg.turnSecs;
      return;
    }
    for (int k = 1; k <= cfg.players; k++) {
      final q = (turn + k) % cfg.players;
      if (cfg.moveLimit > 0 && left[q] <= 0) continue;
      turn = q;
      break;
    }
    turnLeft = cfg.turnSecs;
    if (cfg.mode == 9 && turnCount % 6 == 0 && empties > 3) {
      final e = [for (int i = 0; i < cells.length; i++) if (cells[i] == -1) i];
      cells[e[rnd.nextInt(e.length)]] = -2;
    }
  }

  void byScore() {
    finished = true;
    if (cfg.rivalSim) {
      winner = scores[0] > rivalScore ? 0 : (scores[0] == rivalScore ? -1 : 1);
      return;
    }
    if (cfg.players == 1) {
      winner = scores[0] >= 40 ? 0 : 1;
      return;
    }
    int best = -1, w = -1;
    bool tie = false;
    for (int q = 0; q < cfg.players; q++) {
      if (scores[q] > best) {
        best = scores[q];
        w = q;
        tie = false;
      } else if (scores[q] == best) {
        tie = true;
      }
    }
    winner = tie ? -1 : w;
  }

  void tick() {
    if (finished) return;
    if (frozen > 0) {
      frozen--;
      return;
    }
    turnLeft--;
    if (cfg.timeLimit > 0) {
      timeLeft--;
      if (timeLeft <= 0) {
        byScore();
        return;
      }
    }
    if (turnLeft <= 0) {
      if (cfg.ai && turn != 0) {
        turnLeft = cfg.turnSecs;
      } else {
        timeout();
      }
    }
  }

  void timeout() {
    if (finished) return;
    final p = turn;
    final e = [for (int i = 0; i < cells.length; i++) if (cells[i] == -1) i];
    if (e.isEmpty) return;
    scores[p] = max(0, scores[p] - 2);
    if (cfg.mode == 9) lives--;
    log.insert(0, 'समय समाप्त: ${pn(p)} -2');
    play(e[rnd.nextInt(e.length)]);
    if (cfg.mode == 9 && lives <= 0 && !finished) byScore();
  }

  bool undoMove() {
    if (snaps.isEmpty || undo <= 0 || finished) return false;
    while (snaps.isNotEmpty) {
      final s = snaps.removeLast();
      _restore(s);
      if (!cfg.ai || s.turn == 0) break;
    }
    if (!unlimited) undo--;
    log.insert(0, 'अनडू');
    return true;
  }

  void expandBoard() {
    final m = n + 1;
    final nc = List<int>.filled(m * m, -1);
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        nc[r * m + c] = cells[r * n + c];
      }
    }
    cells = nc;
    n = m;
    hint = -1;
    flash = [];
    last = -1;
    snaps.clear();
    log.insert(0, 'बोर्ड विस्तार ${n}x$n');
  }

  void clearBoard() {
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] >= 0) cells[i] = -1;
    }
    for (int i = 0; i < combo.length; i++) {
      combo[i] = 0;
    }
    flash = [];
    hint = -1;
    last = -1;
    snaps.clear();
    clearLeft--;
    log.insert(0, 'बोर्ड क्लियर');
  }

  void reviveNow() {
    revive--;
    finished = false;
    winner = -2;
    if (cfg.timeLimit > 0) timeLeft += 30;
    if (cfg.moveLimit > 0) {
      for (int i = 0; i < left.length; i++) {
        left[i] += 4;
      }
    }
    if (cfg.mode == 9) lives = 1;
    turnLeft = cfg.turnSecs;
    if (cfg.ai) turn = 0;
    log.insert(0, 'रिवाइव');
  }
}

Game newGame(Cfg c) => Game(c, boost: app.pro && app.boost, unlimited: app.pro);

class Ach {
  final String n;
  final int c, g;
  Ach(this.n, this.c, this.g);
}

class AppState extends ChangeNotifier {
  SharedPreferences? _sp;
  bool dark = false, sound = true, haptic = true, saver = false, coords = false, pro = false, boost = true;
  int thick = 2, lineStyle = 0, mark = 0, speed = 1, avatar = 0, lastN = 4;
  String name = 'कमांडर';
  int points = 0, totalScore = 0, wins = 0, losses = 0, draws = 0, streak = 0, bestStreak = 0, dailyStreak = 0;
  int bestScore = 0, bestCombo = 0, bestAcc = 0, endlessBest = 0, trophies = 0, matches = 0, seasonPoints = 0, accSum = 0;
  int lastSave = 0;
  String lastDay = '', season = '';
  Map<String, List<int>> sec = {};
  Map<String, List<int>> h2h = {};
  List<Map<String, dynamic>> history = [];
  List<String> log = [];
  Map<String, dynamic>? checkpoint;
  Map<String, dynamic>? tour;

  bool get hasStore => _sp != null;
  int get tier {
    int t = 0;
    for (int i = 0; i < kTierMin.length; i++) {
      if (points >= kTierMin[i]) t = i;
    }
    return t;
  }

  int get rank {
    int r = 1;
    for (final x in kBoardPts) {
      if (x > points) r++;
    }
    return r;
  }

  double get tierFrac {
    final t = tier;
    if (t >= kTierMin.length - 1) return 1;
    return (points - kTierMin[t]) / (kTierMin[t + 1] - kTierMin[t]);
  }

  Future<void> load() async {
    try {
      _sp = await SharedPreferences.getInstance();
      final s = _sp!.getString('anivore_state');
      if (s != null) {
        final m = jsonDecode(s);
        if (m is Map) _from(m);
      }
    } catch (_) {}
    _daily();
  }

  void _from(Map m) {
    dark = _b(m, 'dark', dark);
    sound = _b(m, 'sound', sound);
    haptic = _b(m, 'haptic', haptic);
    saver = _b(m, 'saver', saver);
    coords = _b(m, 'coords', coords);
    pro = _b(m, 'pro', pro);
    boost = _b(m, 'boost', boost);
    thick = min(4, max(1, _i(m, 'thick', thick)));
    lineStyle = min(2, max(0, _i(m, 'ls', lineStyle)));
    mark = min(4, max(0, _i(m, 'mark', mark)));
    speed = min(2, max(0, _i(m, 'speed', speed)));
    avatar = min(kAv.length - 1, max(0, _i(m, 'avatar', avatar)));
    lastN = min(9, max(3, _i(m, 'lastN', lastN)));
    name = _s(m, 'name', name);
    points = _i(m, 'points', 0);
    totalScore = _i(m, 'total', 0);
    wins = _i(m, 'wins', 0);
    losses = _i(m, 'losses', 0);
    draws = _i(m, 'draws', 0);
    streak = _i(m, 'streak', 0);
    bestStreak = _i(m, 'bestStreak', 0);
    dailyStreak = _i(m, 'daily', 0);
    bestScore = _i(m, 'bestScore', 0);
    bestCombo = _i(m, 'bestCombo', 0);
    bestAcc = _i(m, 'bestAcc', 0);
    endlessBest = _i(m, 'endless', 0);
    trophies = _i(m, 'trophies', 0);
    matches = _i(m, 'matches', 0);
    seasonPoints = _i(m, 'sp', 0);
    accSum = _i(m, 'accSum', 0);
    lastSave = _i(m, 'saved', 0);
    lastDay = _s(m, 'lastDay', '');
    season = _s(m, 'season', '');
    final s = m['sec'];
    if (s is Map) {
      s.forEach((k, v) {
        sec[k.toString()] = _li(v, [0, 0]);
      });
    }
    final h = m['h2h'];
    if (h is Map) {
      h.forEach((k, v) {
        h2h[k.toString()] = _li(v, [0, 0, 0]);
      });
    }
    final hs = m['history'];
    if (hs is List) {
      for (final e in hs) {
        if (e is Map) history.add(Map<String, dynamic>.from(e));
      }
    }
    final lg = m['log'];
    if (lg is List) log = lg.map((e) => e.toString()).toList();
    final cp = m['cp'];
    if (cp is Map) checkpoint = Map<String, dynamic>.from(cp);
    final tr = m['tour'];
    if (tr is Map) tour = Map<String, dynamic>.from(tr);
  }

  Map<String, dynamic> toJson() => {
        'dark': dark, 'sound': sound, 'haptic': haptic, 'saver': saver, 'coords': coords, 'pro': pro, 'boost': boost,
        'thick': thick, 'ls': lineStyle, 'mark': mark, 'speed': speed, 'avatar': avatar, 'lastN': lastN, 'name': name,
        'points': points, 'total': totalScore, 'wins': wins, 'losses': losses, 'draws': draws, 'streak': streak,
        'bestStreak': bestStreak, 'daily': dailyStreak, 'bestScore': bestScore, 'bestCombo': bestCombo,
        'bestAcc': bestAcc, 'endless': endlessBest, 'trophies': trophies, 'matches': matches, 'sp': seasonPoints,
        'accSum': accSum, 'lastDay': lastDay, 'season': season, 'sec': sec, 'h2h': h2h, 'history': history,
        'log': log, 'cp': checkpoint, 'tour': tour, 'saved': lastSave,
      };

  void save() {
    lastSave = DateTime.now().millisecondsSinceEpoch;
    try {
      _sp?.setString('anivore_state', jsonEncode(toJson()));
    } catch (_) {}
  }

  void commit() {
    save();
    notifyListeners();
  }

  String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  String stamp() {
    final n = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    return '${t(n.day)}/${t(n.month)} ${t(n.hour)}:${t(n.minute)}';
  }

  void addLog(String s) {
    log.insert(0, '${stamp()}  $s');
    if (log.length > 100) log.removeRange(100, log.length);
  }

  void _daily() {
    final now = DateTime.now();
    final t = _day(now);
    if (lastDay != t) {
      final y = _day(now.subtract(const Duration(days: 1)));
      dailyStreak = lastDay == y ? dailyStreak + 1 : 1;
      lastDay = t;
      addLog('दैनिक गतिविधि शुरू');
    }
    final se = '${now.year}-${now.month}';
    if (season != se) {
      season = se;
      seasonPoints = 0;
    }
    save();
  }

  int record(Cfg c, int res, int my, int opp, int acc, int combo, String on, bool ranked) {
    matches++;
    int gain = 0;
    if (ranked) {
      gain = my + (res == 1 ? 25 : (res == 0 ? 8 : 3)) + (res == 1 ? acc ~/ 10 : 0);
      points += gain;
      seasonPoints += gain;
    }
    totalScore += my;
    accSum += acc;
    if (res == 1) {
      wins++;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
    } else if (res == 0) {
      draws++;
    } else {
      losses++;
      streak = 0;
    }
    if (my > bestScore) bestScore = my;
    if (combo > bestCombo) bestCombo = combo;
    if (acc > bestAcc) bestAcc = acc;
    if (c.mode == 9 && my > endlessBest) endlessBest = my;
    if (c.sector > 0 && res == 1) {
      final k = '${c.sector}';
      final old = sec[k] ?? [0, 0];
      final st = 1 + (acc >= 50 ? 1 : 0) + (my - opp >= 8 ? 1 : 0);
      sec[k] = [max(old[0], my), max(old[1], st)];
    }
    if (c.ai || c.rivalSim) {
      final h = h2h.putIfAbsent(on, () => [0, 0, 0]);
      if (res == 1) {
        h[0]++;
      } else if (res == 0) {
        h[2]++;
      } else {
        h[1]++;
      }
    }
    history.insert(0, {
      'm': c.mode, 'n': c.n, 'r': res, 'a': my, 'b': opp, 'o': on, 't': DateTime.now().millisecondsSinceEpoch,
    });
    if (history.length > 100) history.removeRange(100, history.length);
    addLog('${kModes[c.mode].n}: ${res == 1 ? 'जीत' : (res == 0 ? 'ड्रा' : 'हार')} $my-$opp');
    commit();
    return gain;
  }

  void tourDone(bool win) {
    final t = tour;
    if (t == null) return;
    if (win) {
      final r = (t['round'] as num).toInt() + 1;
      t['round'] = r;
      if (r >= 3) {
        trophies++;
        points += 200;
        seasonPoints += 200;
        addLog('टूर्नामेंट विजेता');
        tour = null;
      }
    } else {
      addLog('टूर्नामेंट से बाहर');
      tour = null;
    }
  }

  void cleanup() {
    checkpoint = null;
    if (log.length > 20) log.removeRange(20, log.length);
    if (history.length > 50) history.removeRange(50, history.length);
    commit();
  }

  void resetProgress() {
    points = 0;
    totalScore = 0;
    wins = 0;
    losses = 0;
    draws = 0;
    streak = 0;
    bestStreak = 0;
    bestScore = 0;
    bestCombo = 0;
    bestAcc = 0;
    endlessBest = 0;
    trophies = 0;
    matches = 0;
    seasonPoints = 0;
    accSum = 0;
    sec.clear();
    h2h.clear();
    history.clear();
    log.clear();
    checkpoint = null;
    tour = null;
    commit();
  }

  List<Ach> achs() {
    final cl = sec.values.where((e) => e[1] > 0).length;
    return [
      Ach('पहली जीत', wins, 1),
      Ach('10 जीत', wins, 10),
      Ach('50 जीत', wins, 50),
      Ach('जीत स्ट्रीक 5', bestStreak, 5),
      Ach('एक मैच में 50 अंक', bestScore, 50),
      Ach('कॉम्बो 5', bestCombo, 5),
      Ach('10 सेक्टर क्लियर', cl, 10),
      Ach('25 सेक्टर क्लियर', cl, 25),
      Ach('100 मैच', matches, 100),
      Ach('गोल्ड रैंक', points, 1000),
      Ach('7 दिन की स्ट्रीक', dailyStreak, 7),
      Ach('टूर्नामेंट चैंपियन', trophies, 1),
      Ach('प्रो सदस्य', pro ? 1 : 0, 1),
    ];
  }
}

class Pn {
  final String id;
  final Map<String, dynamic> a;
  Pn(this.id, [this.a = const {}]);
}

class Nav extends ChangeNotifier {
  int tab = 0;
  List<List<Pn>> st = [
    [Pn('home')],
    [Pn('account')]
  ];
  Pn get top => st[tab].last;
  void push(String id, [Map<String, dynamic> a = const {}]) {
    st[tab].add(Pn(id, a));
    notifyListeners();
  }

  void replace(String id, [Map<String, dynamic> a = const {}]) {
    st[tab].removeLast();
    st[tab].add(Pn(id, a));
    notifyListeners();
  }

  void pop() {
    if (st[tab].length > 1) {
      st[tab].removeLast();
      notifyListeners();
    }
  }

  void toRoot() {
    st[tab] = [st[tab].first];
    notifyListeners();
  }

  void setTab(int t) {
    tab = t;
    notifyListeners();
  }
}

void fx(int k) {
  if (app.haptic) {
    if (k == 0) {
      HapticFeedback.selectionClick();
    } else if (k == 1) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }
  if (app.sound) SystemSound.play(SystemSoundType.click);
}

void toast(String s) {
  final m = msgKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(s, style: TextStyle(color: pal.bg, fontWeight: FontWeight.w700)),
    backgroundColor: pal.ink,
    duration: const Duration(milliseconds: 1600),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(side: BorderSide(color: pal.bg, width: 2)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
  ));
}

Widget tx(String s, {double z = 14, bool b = false, Color? c, TextAlign? a, int? ml}) => Text(
      s,
      textAlign: a,
      maxLines: ml,
      overflow: ml == null ? null : TextOverflow.ellipsis,
      style: TextStyle(color: c ?? pal.ink, fontSize: z, fontWeight: b ? FontWeight.w700 : FontWeight.w500, height: 1.3),
    );

Widget box(Widget child, {EdgeInsets? m}) => Container(
      margin: m ?? const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: pal.bg, border: Border.all(color: pal.ink, width: 2)),
      child: child,
    );

Widget kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [Expanded(child: tx(k)), tx(v, b: true)]),
    );

Widget sec(String s) => Padding(padding: const EdgeInsets.fromLTRB(0, 10, 0, 8), child: tx(s, z: 16, b: true));

Widget pg(List<Widget> c) => ListView(padding: const EdgeInsets.all(16), children: c);

Widget bar(double f, {double h = 10}) => Container(
      height: h,
      decoration: BoxDecoration(border: Border.all(color: pal.ink, width: 2)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(widthFactor: f.clamp(0.0, 1.0).toDouble(), heightFactor: 1, child: Container(color: pal.ink)),
      ),
    );

Widget stepper(String v, VoidCallback m, VoidCallback p) => Row(children: [
      SizedBox(width: 60, child: Btn('-', m)),
      Expanded(child: Center(child: tx(v, z: 18, b: true))),
      SizedBox(width: 60, child: Btn('+', p)),
    ]);

InputDecoration deco(String hint) {
  final bd = OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: pal.ink, width: 2));
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: pal.dim),
    isDense: true,
    contentPadding: const EdgeInsets.all(12),
    enabledBorder: bd,
    focusedBorder: bd,
    border: bd,
    counterStyle: TextStyle(color: pal.dim),
  );
}

String avChar(int i) {
  if (i == 0) {
    return app.name.isEmpty ? 'A' : String.fromCharCode(app.name.runes.first);
  }
  return kAv[i % kAv.length];
}

Widget avatarW(int i, double sz, {bool sel = false}) => Container(
      width: sz,
      height: sz,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: sel ? pal.bg : pal.ink, border: Border.all(color: pal.ink, width: sel ? 4 : 2)),
      child: Text(avChar(i), style: TextStyle(color: sel ? pal.ink : pal.bg, fontSize: sz * 0.5, fontWeight: FontWeight.w800)),
    );

Widget tierBadge(int t) => Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(border: Border.all(color: pal.ink, width: 2)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: app.pro ? BoxDecoration(border: Border.all(color: pal.ink, width: 1)) : null,
        child: tx(kTierNames[t] + (app.pro ? ' प्रो' : ''), z: 12, b: true),
      ),
    );

Future<bool> askYes(String t, String b, {String yes = 'हाँ', String no = 'नहीं'}) async {
  final r = await showDialog<bool>(
    context: navKey.currentContext!,
    builder: (c) => Dialog(
      backgroundColor: pal.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: pal.ink, width: 2)),
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          tx(t, z: 18, b: true),
          const SizedBox(height: 10),
          tx(b),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Btn(no, () => Navigator.pop(c, false))),
            const SizedBox(width: 10),
            Expanded(child: Btn(yes, () => Navigator.pop(c, true), fill: true)),
          ]),
        ]),
      ),
    ),
  );
  return r == true;
}

class Tap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget Function(bool) builder;
  const Tap({super.key, this.onTap, required this.builder});
  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool d = false;
  void _s(bool v) {
    if (mounted) setState(() => d = v);
  }

  @override
  Widget build(BuildContext c) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => _s(true),
        onTapCancel: () => _s(false),
        onTapUp: (_) => _s(false),
        onTap: widget.onTap == null
            ? null
            : () {
                fx(0);
                widget.onTap!();
              },
        child: widget.builder(d),
      );
}

class Btn extends StatelessWidget {
  final String t;
  final IconData? ic;
  final VoidCallback? f;
  final bool fill, sm;
  const Btn(this.t, this.f, {super.key, this.ic, this.fill = false, this.sm = false});
  @override
  Widget build(BuildContext c) {
    return Opacity(
      opacity: f == null ? 0.4 : 1,
      child: Tap(
        onTap: f,
        builder: (d) {
          final inv = fill != d;
          final bg = inv ? pal.ink : pal.bg;
          final fg = inv ? pal.bg : pal.ink;
          final label = Text(t, textAlign: TextAlign.center, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: sm ? 12 : 15));
          return Container(
            padding: EdgeInsets.symmetric(horizontal: sm ? 10 : 14, vertical: sm ? 8 : 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, border: Border.all(color: pal.ink, width: 2)),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (ic != null) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(ic, size: sm ? 16 : 20, color: fg)),
              if (sm) label else Flexible(child: label),
            ]),
          );
        },
      ),
    );
  }
}

class Seg extends StatelessWidget {
  final List<String> o;
  final int i;
  final ValueChanged<int> f;
  const Seg(this.o, this.i, this.f, {super.key});
  @override
  Widget build(BuildContext c) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (int k = 0; k < o.length; k++)
          Tap(
            onTap: () => f(k),
            builder: (d) {
              final sel = (k == i) != d;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: sel ? pal.ink : pal.bg, border: Border.all(color: pal.ink, width: 2)),
                child: Text(o[k], style: TextStyle(color: sel ? pal.bg : pal.ink, fontWeight: FontWeight.w700, fontSize: 13)),
              );
            },
          ),
      ]);
}

class Tog extends StatelessWidget {
  final String t;
  final bool v;
  final ValueChanged<bool> f;
  const Tog(this.t, this.v, this.f, {super.key});
  @override
  Widget build(BuildContext c) => Tap(
        onTap: () => f(!v),
        builder: (d) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(child: tx(t, z: 15, b: true)),
            Container(
              width: 54,
              height: 28,
              padding: const EdgeInsets.all(3),
              alignment: v ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(color: v ? pal.ink : pal.bg, border: Border.all(color: pal.ink, width: 2)),
              child: Container(width: 18, height: 18, color: v ? pal.bg : pal.ink),
            ),
          ]),
        ),
      );
}

class Hatch extends CustomPainter {
  final Color c;
  Hatch(this.c);
  @override
  void paint(Canvas cv, Size s) {
    final p = Paint()
      ..color = c
      ..strokeWidth = 2;
    for (double x = -s.height; x < s.width; x += 8) {
      cv.drawLine(Offset(x, s.height), Offset(x + s.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(Hatch o) => o.c != c;
}

class MarkPainter extends CustomPainter {
  final int shape;
  final Color c;
  MarkPainter(this.shape, this.c);
  @override
  void paint(Canvas cv, Size s) {
    final r = Rect.fromLTWH(0, 0, s.width, s.height).deflate(s.shortestSide * 0.22);
    final p = Paint()
      ..color = c
      ..strokeWidth = max(2.0, s.shortestSide * 0.09)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (shape == 0) {
      cv.drawLine(r.topLeft, r.bottomRight, p);
      cv.drawLine(r.topRight, r.bottomLeft, p);
    } else if (shape == 1) {
      cv.drawCircle(r.center, r.shortestSide / 2, p);
    } else if (shape == 2) {
      p.style = PaintingStyle.fill;
      cv.drawRect(r, p);
    } else {
      p.style = PaintingStyle.fill;
      cv.drawCircle(r.center, r.shortestSide * 0.28, p);
    }
  }

  @override
  bool shouldRepaint(MarkPainter o) => o.shape != shape || o.c != c;
}

class Mark extends StatelessWidget {
  final int shape, p;
  final Color col;
  const Mark(this.shape, this.p, this.col, {super.key});
  @override
  Widget build(BuildContext c) {
    if (shape == 4) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: FittedBox(child: Text('${p + 1}', style: TextStyle(color: col, fontWeight: FontWeight.w800))),
      );
    }
    return CustomPaint(painter: MarkPainter(shape, col), size: Size.infinite);
  }
}

class Board extends StatelessWidget {
  final Game g;
  final ValueChanged<int>? onTap;
  const Board(this.g, {super.key, this.onTap});

  Widget _cell(int i, double bw) {
    final v = g.cells[i];
    final fl = g.flash.contains(i);
    final hi = g.hint == i;
    final ls = g.last == i;
    Widget? inner;
    if (v == -2) {
      inner = ClipRect(child: CustomPaint(painter: Hatch(pal.ink), size: Size.infinite));
    } else if (v >= 0) {
      inner = Mark((app.mark + v) % 5, v, fl ? pal.bg : pal.ink);
    } else if (app.coords) {
      inner = Center(child: tx(g.coord(i), z: 9, c: pal.dim));
    }
    return Tap(
      onTap: onTap == null ? null : () => onTap!(i),
      builder: (d) => Container(
        margin: EdgeInsets.all(app.lineStyle == 1 ? 2 : 0),
        decoration: BoxDecoration(
          color: fl ? pal.ink : ((hi || (d && v == -1)) ? pal.faint : pal.bg),
          borderRadius: app.lineStyle == 1 ? BorderRadius.circular(8) : null,
          border: Border.all(color: pal.ink, width: hi ? bw + 2 : (ls ? bw + 1.5 : bw)),
        ),
        child: inner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = g.n;
    final bw = app.lineStyle == 0 ? app.thick / 2 : app.thick.toDouble();
    return LayoutBuilder(builder: (c, bc) {
      final s = min(bc.maxWidth, bc.maxHeight);
      return Center(
        child: SizedBox(
          width: s,
          height: s,
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: pal.ink, width: (app.lineStyle == 2 ? app.thick + 3 : app.thick).toDouble())),
            child: Column(children: [
              for (int r = 0; r < n; r++)
                Expanded(child: Row(children: [for (int q = 0; q < n; q++) Expanded(child: _cell(r * n + q, bw))])),
            ]),
          ),
        ),
      );
    });
  }
}

class NoGlow extends ScrollBehavior {
  const NoGlow();
  @override
  Widget buildOverscrollIndicator(BuildContext c, Widget child, ScrollableDetails d) => child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext c) => const ClampingScrollPhysics();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await app.load();
  runApp(const AnivoreApp());
}

class AnivoreApp extends StatelessWidget {
  const AnivoreApp({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (c, _) {
        final p = pal;
        final br = app.dark ? Brightness.dark : Brightness.light;
        final theme = ThemeData(useMaterial3: false, brightness: br).copyWith(
          scaffoldBackgroundColor: p.bg,
          canvasColor: p.bg,
          cardColor: p.bg,
          dividerColor: p.ink,
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          colorScheme: ColorScheme(
            brightness: br,
            primary: p.ink,
            onPrimary: p.bg,
            secondary: p.ink,
            onSecondary: p.bg,
            error: p.ink,
            onError: p.bg,
            surface: p.bg,
            onSurface: p.ink,
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: p.ink,
            selectionColor: const Color(0x66808080),
            selectionHandleColor: p.ink,
          ),
        );
        return MaterialApp(
          title: 'Anivore',
          debugShowCheckedModeBanner: false,
          navigatorKey: navKey,
          scaffoldMessengerKey: msgKey,
          scrollBehavior: const NoGlow(),
          theme: theme,
          home: const Shell(),
        );
      },
    );
  }
}

String pageTitle(Pn p) {
  switch (p.id) {
    case 'setup':
      return kModes[(p.a['mode'] as int?) ?? 1].n;
    case 'sectors':
      return 'सेक्टर';
    case 'prematch':
      return 'मैचमेकिंग';
    case 'game':
      return 'बैटल';
    case 'tour':
      return 'टूर्नामेंट';
    case 'account':
      return 'अकाउंट';
    case 'profile':
      return 'प्रोफाइल';
    case 'stats':
      return 'आँकड़े';
    case 'history':
      return 'मैच हिस्ट्री';
    case 'ach':
      return 'अचीवमेंट';
    case 'board':
      return 'लीडरबोर्ड';
    case 'season':
      return 'सीज़न ट्रैक';
    case 'records':
      return 'रिकॉर्ड';
    case 'activity':
      return 'गतिविधि लॉग';
    case 'pro':
      return 'प्रो अपग्रेड';
    case 'settings':
      return 'सेटिंग';
    case 'rules':
      return 'रूल बुक';
    case 'status':
      return 'सिस्टम स्थिति';
    default:
      return 'ANIVORE';
  }
}

Widget buildPage(Pn p) {
  switch (p.id) {
    case 'setup':
      return SetupPage(p.a);
    case 'sectors':
      return const SectorsPage();
    case 'prematch':
      return PrematchPage(p.a);
    case 'game':
      return GamePage(p.a);
    case 'tour':
      return TourPage(p.a);
    case 'account':
      return const AccountPage();
    case 'profile':
      return const ProfilePage();
    case 'stats':
      return const StatsPage();
    case 'history':
      return const HistoryPage();
    case 'ach':
      return const AchPage();
    case 'board':
      return const LeaderPage();
    case 'season':
      return const SeasonPage();
    case 'records':
      return const RecordsPage();
    case 'activity':
      return const ActivityPage();
    case 'pro':
      return const ProPage();
    case 'settings':
      return const SettingsPage();
    case 'rules':
      return const RulesPage();
    case 'status':
      return const StatusPage();
    default:
      return const HomePage();
  }
}

class Shell extends StatelessWidget {
  const Shell({super.key});

  Future<void> _back() async {
    final pn = nav.top;
    if (pn.id == 'game') {
      final ok = await askYes('मैच छोड़ें', 'प्रगति चेकपॉइंट में सुरक्षित रहेगी।');
      if (ok) nav.pop();
      return;
    }
    if (nav.st[nav.tab].length > 1) {
      nav.pop();
      return;
    }
    if (nav.tab == 1) {
      nav.setTab(0);
      return;
    }
    final ok = await askYes('बाहर निकलें', 'क्या आप ऐप बंद करना चाहते हैं?');
    if (ok) SystemNavigator.pop();
  }

  Widget _tab(int i, IconData ic) {
    final sel = nav.tab == i;
    return Expanded(
      child: Tap(
        onTap: () {
          if (nav.tab == i) {
            nav.toRoot();
          } else {
            nav.setTab(i);
          }
        },
        builder: (d) {
          final inv = sel != d;
          return Container(
            color: inv ? pal.ink : pal.bg,
            alignment: Alignment.center,
            child: Icon(ic, size: 28, color: inv ? pal.bg : pal.ink),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([app, nav]),
      builder: (c, _) {
        final mq = MediaQuery.of(c);
        final p = pal;
        final pn = nav.top;
        final can = nav.st[nav.tab].length > 1;
        final ib = app.dark ? Brightness.light : Brightness.dark;
        final kb = mq.viewInsets.bottom > 0;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            statusBarIconBrightness: ib,
            systemNavigationBarIconBrightness: ib,
            statusBarBrightness: app.dark ? Brightness.dark : Brightness.light,
          ),
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (d, r) {
              if (!d) _back();
            },
            child: Scaffold(
              backgroundColor: p.bg,
              body: Column(children: [
                Container(
                  padding: EdgeInsets.only(top: mq.padding.top),
                  decoration: BoxDecoration(color: p.bg, border: Border(bottom: BorderSide(color: p.ink, width: 2))),
                  child: SizedBox(
                    height: 54,
                    child: Row(children: [
                      Tap(
                        onTap: can ? _back : null,
                        builder: (d) => Container(
                          width: 52,
                          height: 54,
                          color: d ? p.faint : p.bg,
                          child: Icon(can ? Icons.arrow_back : Icons.grid_view, color: p.ink),
                        ),
                      ),
                      Expanded(child: tx(pageTitle(pn), z: 18, b: true, ml: 1)),
                      Tap(
                        onTap: () {
                          app.dark = !app.dark;
                          app.commit();
                        },
                        builder: (d) => Container(
                          width: 52,
                          height: 54,
                          color: d ? p.faint : p.bg,
                          child: Icon(app.dark ? Icons.light_mode : Icons.dark_mode, color: p.ink),
                        ),
                      ),
                    ]),
                  ),
                ),
                Expanded(child: KeyedSubtree(key: ObjectKey(pn), child: buildPage(pn))),
                Container(
                  padding: EdgeInsets.only(bottom: kb ? 0 : mq.padding.bottom),
                  decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.ink, width: 2))),
                  child: SizedBox(height: 56, child: Row(children: [_tab(0, Icons.home), _tab(1, Icons.person)])),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _quick() {
    final r = Random();
    final cfg = makeCfg(1, 3 + r.nextInt(3), r.nextInt(3), kRivals[r.nextInt(kRivals.length)], diff: r.nextInt(6));
    nav.push('game', {'cfg': cfg.toJson()});
  }

  @override
  Widget build(BuildContext c) {
    final cards = <Widget>[];
    for (int i = 0; i < kModes.length; i++) {
      cards.add(Tap(
        onTap: () => nav.push('setup', {'mode': i}),
        builder: (d) => Container(
          height: 112,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: d ? pal.faint : pal.bg, border: Border.all(color: pal.ink, width: 2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            tx((i + 1).toString().padLeft(2, '0'), z: 12, c: pal.dim),
            const SizedBox(height: 4),
            tx(kModes[i].n, z: 15, b: true, ml: 2),
            const SizedBox(height: 4),
            Expanded(child: tx(kModes[i].d, z: 11, c: pal.dim, ml: 3)),
          ]),
        ),
      ));
    }
    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: cards[i]),
          const SizedBox(width: 10),
          Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
        ]),
      ));
    }
    return pg([
      box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ANIVORE', style: TextStyle(color: pal.ink, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 4)),
        tx('टैक्टिकल ग्रिड कमांड और मैट्रिक्स बैटल', z: 13, c: pal.dim),
        const SizedBox(height: 10),
        Row(children: [
          tierBadge(app.tier),
          const SizedBox(width: 10),
          Expanded(child: tx('${app.points} अंक  |  रैंक #${app.rank}', b: true)),
        ]),
        const SizedBox(height: 8),
        bar(app.tierFrac),
        const SizedBox(height: 6),
        tx('दैनिक स्ट्रीक: ${app.dailyStreak} दिन', z: 12, c: pal.dim),
      ])),
      if (app.checkpoint != null)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Btn('जारी रखें (चेकपॉइंट)', () => nav.push('game', {'resume': true}), ic: Icons.play_arrow, fill: true)),
      Padding(padding: const EdgeInsets.only(bottom: 10), child: Btn('क्विक मैच', _quick, ic: Icons.bolt, fill: app.checkpoint == null)),
      Row(children: [
        Expanded(child: Btn('सेक्टर', () => nav.push('sectors'), ic: Icons.grid_on)),
        const SizedBox(width: 10),
        Expanded(child: Btn('टूर्नामेंट', () => nav.push('tour', {'n': app.lastN}), ic: Icons.emoji_events)),
      ]),
      sec('गेम मोड'),
      ...rows,
    ]);
  }
}

class SetupPage extends StatefulWidget {
  final Map<String, dynamic> a;
  const SetupPage(this.a, {super.key});
  @override
  State<SetupPage> createState() => _SetupState();
}

class _SetupState extends State<SetupPage> {
  late int mode = (widget.a['mode'] as int?) ?? 1;
  late int n = min(app.lastN, app.pro ? 9 : 5);
  int prof = 2, blocked = 0;

  void _setN(int v) {
    if (v < 3 || v > 9) return;
    if (v > 5 && !app.pro) {
      toast('6x6 और उससे बड़े ग्रिड के लिए प्रो आवश्यक है');
      return;
    }
    setState(() {
      n = v;
      blocked = min(blocked, n * n ~/ 4);
    });
  }

  void _go(bool match) {
    app.lastN = n;
    app.commit();
    final r = Random();
    final hasName = mode != 2 && mode != 3 && mode != 9;
    final cfg = makeCfg(mode, n, prof, hasName ? kRivals[r.nextInt(kRivals.length)] : '', blocked: blocked);
    nav.push(match ? 'prematch' : 'game', {'cfg': cfg.toJson()});
  }

  @override
  Widget build(BuildContext c) {
    final hasRival = const [1, 4, 6, 7, 8, 10, 11].contains(mode);
    final cf = makeCfg(mode, n, prof, '', blocked: blocked);
    return pg([
      tx(kModes[mode].n, z: 22, b: true),
      const SizedBox(height: 4),
      tx(kModes[mode].d, c: pal.dim),
      sec('ग्रिड आकार'),
      Seg(['3x3', '4x4', '5x5', '6x6', '7x7'], n >= 3 && n <= 7 ? n - 3 : -1, (k) => _setN(k + 3)),
      const SizedBox(height: 10),
      stepper('कस्टम ${n}x$n', () => _setN(n - 1), () => _setN(n + 1)),
      if (hasRival) ...[
        sec('राइवल प्रोफाइल'),
        Seg(kProf, prof, (k) => setState(() => prof = k)),
        const SizedBox(height: 6),
        tx(kProfD[prof], z: 12, c: pal.dim),
      ],
      sec('ब्लॉक्ड ज़ोन'),
      stepper('$blocked सेल', () => setState(() => blocked = max(0, blocked - 1)), () => setState(() => blocked = min(n * n ~/ 4, blocked + 1))),
      sec('राउंड स्पीड'),
      Seg(const ['धीमा', 'सामान्य', 'तेज़'], app.speed, (k) {
        app.speed = k;
        app.commit();
      }),
      sec('सारांश'),
      box(Column(children: [
        kv('खिलाड़ी', cf.rivalSim ? '1 + राइवल' : '${cf.players}${cf.ai ? ' (एआई)' : ''}'),
        kv('प्रति चाल समय', '${cf.turnSecs} सेकंड'),
        if (cf.timeLimit > 0) kv('कुल समय', '${cf.timeLimit} सेकंड'),
        if (cf.moveLimit > 0) kv('चाल सीमा', '${cf.moveLimit} प्रति खिलाड़ी'),
        if (cf.target > 0) kv('लक्ष्य स्कोर', '${cf.target}'),
      ])),
      if (mode == 5)
        Btn('सीरीज़ खोलें', () => nav.push('tour', {'n': n}), fill: true)
      else if (hasRival) ...[
        Btn('मैचमेकिंग और रणनीति', () => _go(true), fill: true, ic: Icons.search),
        const SizedBox(height: 10),
        Btn('सीधे शुरू करें', () => _go(false), ic: Icons.play_arrow),
      ] else
        Btn('शुरू करें', () => _go(false), fill: true, ic: Icons.play_arrow),
    ]);
  }
}

class SectorsPage extends StatefulWidget {
  const SectorsPage({super.key});
  @override
  State<SectorsPage> createState() => _SectorsState();
}

class _SectorsState extends State<SectorsPage> {
  int f = 0;
  final sc = ScrollController();
  final tc = TextEditingController();

  @override
  void dispose() {
    sc.dispose();
    tc.dispose();
    super.dispose();
  }

  List<int> _list() {
    final o = <int>[];
    for (int s = 1; s <= kSectors; s++) {
      final u = unlocked(s);
      final b = app.sec['$s'];
      bool ok;
      switch (f) {
        case 1:
          ok = u;
          break;
        case 2:
          ok = !u;
          break;
        case 3:
          ok = b != null && b[1] >= 2;
          break;
        case 4:
          ok = sectorCfg(s).profile == 0;
          break;
        default:
          ok = true;
      }
      if (ok) o.add(s);
    }
    return o;
  }

  void _jump() {
    final v = int.tryParse(tc.text.trim());
    if (v == null || v < 1 || v > kSectors) {
      toast('1 से $kSectors के बीच संख्या दें');
      return;
    }
    setState(() => f = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (sc.hasClients) sc.jumpTo(min((v - 1) * 78.0, sc.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext c) {
    final l = _list();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(children: [
          Seg(const ['सभी', 'अनलॉक्ड', 'लॉक्ड', 'हाई स्कोर', 'बैटल'], f, (k) => setState(() => f = k)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: tc,
                keyboardType: TextInputType.number,
                cursorColor: pal.ink,
                style: TextStyle(color: pal.ink, fontSize: 16),
                decoration: deco('सेक्टर नंबर'),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 100, child: Btn('जाएँ', _jump)),
          ]),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          controller: sc,
          itemExtent: 78,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: l.length,
          itemBuilder: (c, idx) {
            final s = l[idx];
            final cfg = sectorCfg(s);
            final b = app.sec['$s'];
            final u = unlocked(s);
            final proLock = s > kFreeSectors && !app.pro;
            return Tap(
              onTap: () {
                if (proLock) {
                  toast('यह सेक्टर प्रो में उपलब्ध है');
                  return;
                }
                if (!u) {
                  toast('पिछला सेक्टर जीतकर अनलॉक करें');
                  return;
                }
                nav.push('prematch', {'cfg': cfg.toJson()});
              },
              builder: (d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: d ? pal.faint : pal.bg, border: Border.all(color: pal.ink, width: 2)),
                child: Row(children: [
                  SizedBox(width: 56, child: tx(s.toString().padLeft(2, '0'), z: 22, b: true)),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      tx('सेक्टर $s', b: true),
                      tx('ग्रिड ${cfg.n}x${cfg.n} | ब्लॉक ${cfg.blocked} | ${kProf[cfg.profile]}', z: 11, c: pal.dim, ml: 1),
                    ]),
                  ),
                  if (u)
                    Row(children: [for (int k = 0; k < 3; k++) Icon(k < (b == null ? 0 : b[1]) ? Icons.star : Icons.star_border, size: 16, color: pal.ink)])
                  else
                    Row(children: [if (proLock) tx('प्रो ', z: 11, b: true), Icon(Icons.lock, size: 20, color: pal.ink)]),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class PrematchPage extends StatefulWidget {
  final Map<String, dynamic> a;
  const PrematchPage(this.a, {super.key});
  @override
  State<PrematchPage> createState() => _PrematchState();
}

class _PrematchState extends State<PrematchPage> {
  late Cfg cfg;
  Timer? t;
  bool searching = false;
  String shown = '';
  int el = 0;
  final r = Random();

  @override
  void initState() {
    super.initState();
    cfg = Cfg.fromJson(widget.a['cfg'] as Map);
    shown = cfg.rival;
    if (!(cfg.sector > 0 || cfg.round >= 0)) _search();
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  void _search() {
    t?.cancel();
    searching = true;
    el = 0;
    final total = app.saver ? 700 : 2400;
    t = Timer.periodic(const Duration(milliseconds: 70), (tm) {
      if (!mounted) {
        tm.cancel();
        return;
      }
      el += 70;
      if (el >= total) {
        tm.cancel();
        final nm = kRivals[r.nextInt(kRivals.length)];
        setState(() {
          searching = false;
          shown = nm;
          cfg = cfg.copy(rival: nm, seed: r.nextInt(1 << 30));
        });
        fx(2);
      } else {
        setState(() => shown = kRivals[r.nextInt(kRivals.length)]);
      }
    });
  }

  List<String> _tips() {
    final o = <String>[];
    o.add(cfg.profile == 0
        ? 'राइवल तीन की कतार के लिए तेज़ी से बढ़ेगा; उसकी दो की कतार को बीच में रोकें।'
        : (cfg.profile == 1 ? 'राइवल आपकी कतारें रोकेगा; दो दिशाओं में एक साथ खतरा बनाएँ।' : 'राइवल संतुलित खेलेगा; केंद्र के सेल पहले लें।'));
    if (cfg.blocked > 0) o.add('${cfg.blocked} ब्लॉक्ड सेल हैं; खुली दिशाओं की कतारों पर ध्यान दें।');
    o.add('लगातार लाइन बनाकर कॉम्बो गुणक बढ़ाएँ।');
    if (cfg.timeLimit > 0) o.add('कुल समय ${cfg.timeLimit} सेकंड है; तेज़ निर्णय लें।');
    if (cfg.moveLimit > 0) o.add('हर खिलाड़ी के पास ${cfg.moveLimit} चालें हैं।');
    if (cfg.target > 0) o.add('${cfg.target} अंक तक पहले पहुँचने वाला जीतेगा।');
    return o;
  }

  @override
  Widget build(BuildContext c) {
    final h = app.h2h[shown];
    final fixed = cfg.sector > 0 || cfg.round >= 0;
    return pg([
      Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: pal.ink, width: 2)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          tx(searching ? 'प्रतिद्वंद्वी खोजा जा रहा है' : 'प्रतिद्वंद्वी मिला', z: 12, c: pal.dim),
          const SizedBox(height: 6),
          tx(shown.isEmpty ? '-' : shown, z: 34, b: true),
        ]),
      ),
      const SizedBox(height: 12),
      if (!searching) ...[
        box(Column(children: [
          kv('प्रोफाइल', kProf[cfg.profile]),
          kv('मोड', kModes[cfg.mode].n),
          kv('ग्रिड', '${cfg.n}x${cfg.n}'),
          kv('हेड-टू-हेड (जीत-हार-ड्रा)', h == null ? '0-0-0' : '${h[0]}-${h[1]}-${h[2]}'),
        ])),
        sec('रणनीति प्रीव्यू'),
        SizedBox(height: 190, child: Board(newGame(cfg))),
        const SizedBox(height: 10),
        for (final s in _tips()) Padding(padding: const EdgeInsets.only(bottom: 6), child: tx('- $s', z: 13)),
        const SizedBox(height: 10),
      ],
      Btn('मैच शुरू करें', searching ? null : () => nav.replace('game', {'cfg': cfg.toJson()}), fill: true, ic: Icons.play_arrow),
      if (!fixed) ...[
        const SizedBox(height: 10),
        Btn('री-रोल ओपोनेंट', searching ? null : () => setState(_search), ic: Icons.casino),
      ],
    ]);
  }
}

class GamePage extends StatefulWidget {
  final Map<String, dynamic> a;
  const GamePage(this.a, {super.key});
  @override
  State<GamePage> createState() => _GameState();
}

class _GameState extends State<GamePage> {
  late Game g;
  Timer? tk;
  Timer? ait;
  bool dlg = false;
  int gain = -1;

  @override
  void initState() {
    super.initState();
    Game? ng;
    if (widget.a['resume'] == true && app.checkpoint != null) {
      try {
        ng = Game.fromJson(app.checkpoint!);
      } catch (_) {
        app.checkpoint = null;
      }
    }
    ng ??= newGame(Cfg.fromJson((widget.a['cfg'] as Map?) ?? {}));
    g = ng;
    app.checkpoint = g.toJson();
    app.save();
    tk = Timer.periodic(const Duration(seconds: 1), _tick);
    _sched();
  }

  @override
  void dispose() {
    tk?.cancel();
    ait?.cancel();
    super.dispose();
  }

  void _save() {
    if (!g.finished) {
      app.checkpoint = g.toJson();
      app.save();
    }
  }

  void _tick(Timer t) {
    if (!mounted || dlg || g.finished) return;
    g.tick();
    if (g.finished) {
      _ended();
    } else {
      if (t.tick % 5 == 0) _save();
      _sched();
    }
    setState(() {});
  }

  void _sched() {
    if (g.finished || dlg) return;
    if (!(g.cfg.ai && g.turn != 0)) return;
    if (ait != null && ait!.isActive) return;
    final d = g.cfg.mode == 11 ? 250 : (app.speed == 0 ? 900 : (app.speed == 1 ? 600 : 300));
    ait = Timer(Duration(milliseconds: d), () {
      if (!mounted || g.finished || dlg) return;
      if (!(g.cfg.ai && g.turn != 0)) return;
      final nz = max(0.0, 4.0 - g.cfg.diff * 0.4);
      g.play(g.pick(g.turn, g.cfg.profile, nz));
      _after();
    });
  }

  void _after() {
    fx(g.flash.isNotEmpty ? 2 : 1);
    _save();
    if (g.finished) {
      _ended();
    } else {
      _sched();
    }
    if (mounted) setState(() {});
  }

  void _tapCell(int i) {
    if (g.finished || dlg) return;
    if (g.cfg.ai && g.turn != 0) return;
    if (g.cells[i] != -1) return;
    g.play(i);
    _after();
  }

  void _newGame(Cfg c) {
    ait?.cancel();
    dlg = false;
    gain = -1;
    g = newGame(c);
    app.checkpoint = g.toJson();
    app.save();
    if (mounted) setState(() {});
    _sched();
  }

  void _record() {
    final c = g.cfg;
    final r = g.result;
    final acc = g.moves[0] == 0 ? 0 : (g.acc[0] * 100 / g.moves[0]).round();
    int opp = 0;
    if (c.rivalSim) {
      opp = g.rivalScore;
    } else if (g.scores.length > 1) {
      opp = g.scores.sublist(1).reduce(max);
    }
    final on = (c.ai || c.rivalSim) ? c.rival : (c.players == 3 ? 'खिलाड़ी 2 और 3' : (c.players == 2 ? 'खिलाड़ी 2' : '-'));
    final ranked = c.ai || c.rivalSim || c.mode == 9;
    app.checkpoint = null;
    gain = app.record(c, r, g.scores[0], opp, acc, g.maxCombo[0], on, ranked);
    if (c.round >= 0 && r != 0) app.tourDone(r == 1);
    app.commit();
  }

  Future<void> _ended() async {
    if (dlg) return;
    dlg = true;
    ait?.cancel();
    fx(2);
    final c = g.cfg;
    final r = g.result;
    final canRev = r == -1 && g.revive > 0 && g.empties > 0 && (c.timeLimit > 0 || c.moveLimit > 0 || c.mode == 9);
    if (!canRev) _record();
    String title;
    if (c.players > 1 && !c.ai) {
      title = g.winner < 0 ? 'ड्रा' : 'विजेता: ${g.pn(g.winner)}';
    } else {
      title = r == 1 ? 'विजय' : (r == 0 ? 'ड्रा' : 'हार');
    }
    final acc = g.moves[0] == 0 ? 0 : (g.acc[0] * 100 / g.moves[0]).round();
    final opts = <List<String>>[];
    if (canRev) opts.add(['revive', 'रिवाइव (अतिरिक्त चांस)']);
    if (c.round >= 0) {
      if (r != 0) opts.add(['tour', 'सीरीज़ देखें']);
    } else {
      opts.add(['again', r == -1 ? 'बदला (रिवेंज)' : 'रीमैच']);
    }
    if (r == 0 && c.players > 1) opts.add(['tie', 'सडन डेथ टाई-ब्रेकर']);
    if (c.sector > 0 && r == 1 && c.sector < kSectors) opts.add(['next', 'अगला सेक्टर']);
    opts.add(['exit', 'बाहर']);
    final res = await showDialog<String>(
      context: navKey.currentContext!,
      barrierDismissible: false,
      builder: (dc) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: pal.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: pal.ink, width: 2)),
          insetPadding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              tx(title, z: 24, b: true),
              const SizedBox(height: 10),
              for (int p = 0; p < c.players; p++) kv(g.pn(p), '${g.scores[p]}'),
              if (c.rivalSim) kv(c.rival, '${g.rivalScore}'),
              kv('सटीकता', '$acc%'),
              kv('सर्वश्रेष्ठ कॉम्बो', '${g.maxCombo[0]}'),
              if (gain >= 0) kv('कमाए अंक', '+$gain'),
              if (c.round == 2 && r == 1) tx('टूर्नामेंट चैंपियन: +200 अंक', b: true),
              const SizedBox(height: 12),
              for (int i = 0; i < opts.length; i++)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Btn(opts[i][1], () => Navigator.pop(dc, opts[i][0]), fill: i == 0)),
            ]),
          ),
        ),
      ),
    );
    if (res == 'revive') {
      dlg = false;
      g.reviveNow();
      _save();
      if (mounted) setState(() {});
      _sched();
      return;
    }
    if (canRev) _record();
    switch (res) {
      case 'again':
        _newGame(c.copy(seed: Random().nextInt(1 << 30)));
        break;
      case 'tie':
        _newGame(c.copy(mode: 10, n: min(5, max(3, c.n)), seed: Random().nextInt(1 << 30), moveLimit: 0, target: 0, timeLimit: 0, blocked: 0));
        break;
      case 'next':
        if (c.sector + 1 > kFreeSectors && !app.pro) {
          toast('अगला सेक्टर प्रो में उपलब्ध है');
          nav.pop();
        } else {
          nav.replace('prematch', {'cfg': sectorCfg(c.sector + 1).toJson()});
        }
        break;
      case 'tour':
        nav.replace('tour', {'n': c.n});
        break;
      default:
        nav.pop();
    }
  }

  void _undo() {
    if (g.finished || (g.cfg.ai && g.turn != 0)) return;
    if (g.undoMove()) {
      ait?.cancel();
      _save();
      setState(() {});
    } else {
      toast('अनडू उपलब्ध नहीं');
    }
  }

  void _hint() {
    if (g.finished || g.hints <= 0 || (g.cfg.ai && g.turn != 0)) return;
    g.hint = g.pick(g.turn, 2, 0.0);
    g.hints--;
    if (g.hint >= 0) g.log.insert(0, 'हिंट: ${g.coord(g.hint)}');
    setState(() {});
  }

  void _freeze() {
    if (g.finished || g.freeze <= 0) return;
    g.frozen = 10;
    g.freeze--;
    g.log.insert(0, 'टाइम फ्रीज़');
    setState(() {});
  }

  void _extend() {
    if (g.finished || g.extend <= 0) return;
    g.turnLeft += 10;
    if (g.cfg.timeLimit > 0) g.timeLeft += 15;
    g.extend--;
    g.log.insert(0, 'समय बढ़ाया');
    setState(() {});
  }

  void _extra() {
    if (g.finished || g.extra <= 0) return;
    if (g.cfg.moveLimit > 0) {
      g.left[g.turn] += 3;
    } else if (g.cfg.players > 1) {
      g.extraTurn = true;
    } else {
      g.turnLeft += 15;
    }
    g.extra--;
    g.log.insert(0, 'अतिरिक्त चांस');
    _save();
    setState(() {});
  }

  void _expand() {
    if (g.finished) return;
    if (g.expand <= 0 || g.n >= 9) {
      toast('विस्तार उपलब्ध नहीं');
      return;
    }
    if (!app.pro && g.n >= 5) {
      toast('6x6 और उससे बड़े ग्रिड के लिए प्रो आवश्यक है');
      return;
    }
    g.expandBoard();
    g.expand--;
    _save();
    setState(() {});
  }

  void _clear() {
    if (g.finished) return;
    if (g.clearLeft <= 0) {
      toast('क्लियर उपलब्ध नहीं');
      return;
    }
    g.clearBoard();
    _save();
    setState(() {});
  }

  Future<void> _restart() async {
    final ok = await askYes('राउंड रीस्टार्ट', 'वर्तमान राउंड नए सिरे से शुरू होगा।');
    if (ok) _newGame(g.cfg.copy(seed: Random().nextInt(1 << 30)));
  }

  void _logSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: pal.bg,
      shape: RoundedRectangleBorder(side: BorderSide(color: pal.ink, width: 2)),
      builder: (c) => SizedBox(
        height: 380,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
          tx('मूव लॉग', z: 18, b: true),
          const SizedBox(height: 8),
          if (g.log.isEmpty) tx('अभी कोई चाल नहीं', c: pal.dim),
          for (final e in g.log) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: tx(e)),
        ]),
      ),
    );
  }

  void _tags() {
    showModalBottomSheet(
      context: context,
      backgroundColor: pal.bg,
      shape: RoundedRectangleBorder(side: BorderSide(color: pal.ink, width: 2)),
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          tx('क्विक रिएक्शन कमांड', z: 18, b: true),
          const SizedBox(height: 12),
          Seg(kTags, -1, (k) {
            g.log.insert(0, 'टैग: ${kTags[k]}');
            Navigator.pop(c);
            toast(kTags[k]);
            setState(() {});
          }),
        ]),
      ),
    );
  }

  Widget _hud() {
    final c = g.cfg;
    final chips = <Widget>[];
    for (int p = 0; p < c.players; p++) {
      final act = g.turn == p && !g.finished;
      final fg = act ? pal.bg : pal.ink;
      chips.add(Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: act ? pal.ink : pal.bg, border: Border.all(color: pal.ink, width: 2)),
          child: Column(children: [
            tx(g.pn(p), z: 11, c: fg, ml: 1),
            tx('${g.scores[p]}', z: 22, b: true, c: fg),
          ]),
        ),
      ));
    }
    if (c.rivalSim) {
      chips.add(Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(border: Border.all(color: pal.ink, width: 2)),
          child: Column(children: [tx(c.rival, z: 11, ml: 1), tx('${g.rivalScore}', z: 22, b: true)]),
        ),
      ));
    }
    return Row(children: chips);
  }

  @override
  Widget build(BuildContext context) {
    final cf = g.cfg;
    final parts = <String>[kModes[cf.mode].n, 'ग्रिड ${g.n}x${g.n}'];
    if (cf.timeLimit > 0) parts.add('समय ${g.timeLeft}s');
    if (cf.moveLimit > 0) parts.add('चालें ${g.left.join('/')}');
    if (cf.target > 0) parts.add('लक्ष्य ${cf.target}');
    if (cf.mode == 9) parts.add('जीवन ${g.lives}');
    if (g.combo[0] > 1) parts.add('कॉम्बो x${g.combo[0]}');
    if (g.frozen > 0) parts.add('फ्रीज़ ${g.frozen}s');
    final u = g.unlimited ? 'असीमित' : '${g.undo}';
    final acts = <List<dynamic>>[
      ['अनडू $u', Icons.undo, _undo],
      ['हिंट ${g.hints}', Icons.lightbulb_outline, _hint],
      ['फ्रीज़ ${g.freeze}', Icons.ac_unit, _freeze],
      ['समय+ ${g.extend}', Icons.add_alarm, _extend],
      ['एक्स्ट्रा ${g.extra}', Icons.exposure_plus_1, _extra],
      ['विस्तार ${g.expand}', Icons.open_in_full, _expand],
      ['क्लियर ${g.clearLeft}', Icons.cleaning_services, _clear],
      ['रीस्टार्ट', Icons.refresh, _restart],
      ['लॉग', Icons.list_alt, _logSheet],
      ['टैग', Icons.label_outline, _tags],
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(children: [
        _hud(),
        const SizedBox(height: 8),
        tx(parts.join('  |  '), z: 12, c: pal.dim, a: TextAlign.center),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: tx('चाल: ${g.pn(g.turn)}', z: 12, b: true, ml: 1)),
          tx('${g.turnLeft}s', z: 12, b: true),
        ]),
        const SizedBox(height: 4),
        bar(g.turnLeft / max(1, cf.turnSecs), h: 8),
        const SizedBox(height: 8),
        Expanded(child: Board(g, onTap: _tapCell)),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final a in acts)
              Padding(padding: const EdgeInsets.only(right: 6), child: Btn(a[0] as String, a[2] as VoidCallback, ic: a[1] as IconData, sm: true)),
          ]),
        ),
      ]),
    );
  }
}

class TourPage extends StatefulWidget {
  final Map<String, dynamic> a;
  const TourPage(this.a, {super.key});
  @override
  State<TourPage> createState() => _TourState();
}

class _TourState extends State<TourPage> {
  late int n = min((widget.a['n'] as int?) ?? app.lastN, app.pro ? 9 : 5);

  void _setN(int v) {
    if (v < 3 || v > 9) return;
    if (v > 5 && !app.pro) {
      toast('6x6 और उससे बड़े ग्रिड के लिए प्रो आवश्यक है');
      return;
    }
    setState(() => n = v);
  }

  void _new() {
    final names = List<String>.from(kRivals)..shuffle(Random());
    app.tour = {'n': n, 'round': 0, 'names': names.take(3).toList()};
    app.lastN = n;
    app.addLog('नई टूर्नामेंट सीरीज़');
    app.commit();
    setState(() {});
  }

  @override
  Widget build(BuildContext c) {
    final t = app.tour;
    if (t == null) {
      return pg([
        tx('टूर्नामेंट और नॉकआउट सीरीज़', z: 20, b: true),
        const SizedBox(height: 6),
        tx('तीन राउंड जीतकर ट्रॉफी और 200 बोनस अंक पाएँ। एक हार पर सीरीज़ समाप्त।', c: pal.dim),
        const SizedBox(height: 12),
        box(kv('ट्रॉफियाँ', '${app.trophies}')),
        sec('ग्रिड आकार'),
        stepper('${n}x$n', () => _setN(n - 1), () => _setN(n + 1)),
        const SizedBox(height: 16),
        Btn('नई सीरीज़ शुरू करें', _new, fill: true, ic: Icons.emoji_events),
      ]);
    }
    final round = (t['round'] as num).toInt();
    final tn = (t['n'] as num).toInt();
    final names = (t['names'] as List).map((e) => e.toString()).toList();
    final pf = [2, 1, 0];
    return pg([
      tx('सीरीज़ ग्रिड ${tn}x$tn', c: pal.dim),
      const SizedBox(height: 10),
      for (int r = 0; r < 3; r++)
        box(Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              tx(kStages[r], z: 12, c: pal.dim),
              tx(names[r], z: 18, b: true),
              tx(kProf[pf[r]], z: 12),
            ]),
          ),
          tx(r < round ? 'जीता' : (r == round ? 'अगला' : 'प्रतीक्षा'), b: true),
        ])),
      Btn('अगला राउंड खेलें', () {
        final cfg = makeCfg(5, tn, pf[round], names[round], diff: 2 + round * 3, round: round, blocked: round == 2 ? max(1, tn * tn ~/ 12) : 0);
        nav.push('prematch', {'cfg': cfg.toJson()});
      }, fill: true, ic: Icons.play_arrow),
      const SizedBox(height: 10),
      Btn('सीरीज़ छोड़ें', () async {
        final ok = await askYes('सीरीज़ छोड़ें', 'वर्तमान टूर्नामेंट समाप्त हो जाएगा।');
        if (ok) {
          app.tour = null;
          app.commit();
        }
      }),
    ]);
  }
}

class Mi {
  final String t, id;
  final IconData i;
  const Mi(this.t, this.i, this.id);
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  @override
  Widget build(BuildContext c) {
    const items = [
      Mi('प्रोफाइल संपादन', Icons.edit, 'profile'),
      Mi('आँकड़े', Icons.bar_chart, 'stats'),
      Mi('मैच हिस्ट्री', Icons.history, 'history'),
      Mi('अचीवमेंट', Icons.military_tech, 'ach'),
      Mi('लीडरबोर्ड', Icons.leaderboard, 'board'),
      Mi('सीज़न ट्रैक', Icons.flag, 'season'),
      Mi('रिकॉर्ड और हेड-टू-हेड', Icons.workspace_premium, 'records'),
      Mi('गतिविधि लॉग', Icons.event_note, 'activity'),
      Mi('प्रो अपग्रेड', Icons.star, 'pro'),
      Mi('सेटिंग', Icons.settings, 'settings'),
      Mi('रूल बुक', Icons.menu_book, 'rules'),
      Mi('सिस्टम स्थिति', Icons.monitor_heart, 'status'),
    ];
    return pg([
      box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          avatarW(app.avatar, 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              tx(app.name, z: 20, b: true, ml: 1),
              const SizedBox(height: 6),
              tierBadge(app.tier),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        kv('अंक', '${app.points}'),
        kv('ग्लोबल रैंक', '#${app.rank}'),
        kv('सीज़न अंक', '${app.seasonPoints}'),
        const SizedBox(height: 6),
        bar(app.tierFrac),
        const SizedBox(height: 4),
        tx(app.tier >= kTierMin.length - 1 ? 'सर्वोच्च टियर' : 'अगला टियर: ${kTierNames[app.tier + 1]} (${kTierMin[app.tier + 1]} अंक)', z: 12, c: pal.dim),
      ])),
      for (final m in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Tap(
            onTap: () => nav.push(m.id),
            builder: (d) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: d ? pal.faint : pal.bg, border: Border.all(color: pal.ink, width: 2)),
              child: Row(children: [
                Icon(m.i, color: pal.ink),
                const SizedBox(width: 12),
                Expanded(child: tx(m.t, z: 15, b: true)),
                Icon(Icons.chevron_right, color: pal.ink),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfileState();
}

class _ProfileState extends State<ProfilePage> {
  late final TextEditingController tc = TextEditingController(text: app.name);

  @override
  void dispose() {
    tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    return pg([
      Center(child: avatarW(app.avatar, 88)),
      sec('नाम'),
      TextField(
        controller: tc,
        maxLength: 12,
        cursorColor: pal.ink,
        style: TextStyle(color: pal.ink, fontSize: 16),
        decoration: deco('नाम'),
      ),
      const SizedBox(height: 8),
      Btn('नाम सहेजें', () {
        final v = tc.text.trim();
        if (v.isEmpty) {
          toast('नाम खाली नहीं हो सकता');
          return;
        }
        app.name = v;
        app.commit();
        toast('सहेजा गया');
      }, fill: true),
      sec('अवतार / मोनोग्राम'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (int i = 0; i < kAv.length; i++)
          Tap(
            onTap: () {
              app.avatar = i;
              app.commit();
            },
            builder: (d) => avatarW(i, 54, sel: app.avatar == i),
          ),
      ]),
    ]);
  }
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext c) {
    final m = max(1, app.matches);
    return pg([
      box(Column(children: [
        kv('खेले गए मैच', '${app.matches}'),
        kv('जीत', '${app.wins}'),
        kv('हार', '${app.losses}'),
        kv('ड्रा', '${app.draws}'),
        kv('विनिंग परसेंटेज', '${(app.wins * 100 / m).round()}%'),
        kv('कुल स्कोर', '${app.totalScore}'),
        kv('औसत स्कोर', '${(app.totalScore / m).round()}'),
        kv('औसत सटीकता', '${(app.accSum / m).round()}%'),
        kv('कुल अंक', '${app.points}'),
        kv('ग्लोबल रैंक', '#${app.rank}'),
        kv('मौजूदा स्ट्रीक', '${app.streak}'),
        kv('दैनिक स्ट्रीक', '${app.dailyStreak} दिन'),
      ])),
    ]);
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext c) {
    if (app.history.isEmpty) return pg([tx('अभी कोई मैच नहीं खेला गया', c: pal.dim)]);
    return pg([
      for (final h in app.history)
        box(Row(children: [
          SizedBox(width: 56, child: tx(_i(h, 'r', 0) == 1 ? 'जीत' : (_i(h, 'r', 0) == 0 ? 'ड्रा' : 'हार'), b: true)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              tx(kModes[min(11, max(0, _i(h, 'm', 1)))].n, b: true, ml: 1),
              tx('${_i(h, 'n', 4)}x${_i(h, 'n', 4)} | ${_s(h, 'o', '-')}', z: 12, c: pal.dim, ml: 1),
            ]),
          ),
          tx('${_i(h, 'a', 0)} - ${_i(h, 'b', 0)}', z: 16, b: true),
        ]), m: const EdgeInsets.only(bottom: 8)),
    ]);
  }
}

class AchPage extends StatelessWidget {
  const AchPage({super.key});
  @override
  Widget build(BuildContext c) {
    final l = app.achs();
    final done = l.where((a) => a.c >= a.g).length;
    return pg([
      box(kv('प्राप्त बैज', '$done/${l.length}')),
      for (final a in l)
        box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: tx(a.n, b: true)),
            tx('${min(a.c, a.g)}/${a.g}', b: true),
          ]),
          const SizedBox(height: 8),
          bar(a.c / a.g),
        ]), m: const EdgeInsets.only(bottom: 8)),
    ]);
  }
}

class LeaderPage extends StatelessWidget {
  const LeaderPage({super.key});
  @override
  Widget build(BuildContext c) {
    final rows = <List<dynamic>>[];
    for (int i = 0; i < kBoardNames.length; i++) {
      rows.add([kBoardNames[i], kBoardPts[i], false]);
    }
    rows.add([app.name, app.points, true]);
    rows.sort((a, b) => (b[1] as int).compareTo(a[1] as int));
    final my = rows.indexWhere((e) => e[2] == true);
    Widget row(int i) {
      final e = rows[i];
      final me = e[2] == true;
      final fg = me ? pal.bg : pal.ink;
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: me ? pal.ink : pal.bg, border: Border.all(color: pal.ink, width: 2)),
        child: Row(children: [
          SizedBox(width: 48, child: tx('#${i + 1}', b: true, c: fg)),
          Expanded(child: tx(e[0] as String, b: me, c: fg, ml: 1)),
          tx('${e[1]}', b: true, c: fg),
        ]),
      );
    }

    return pg([
      box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [tierBadge(app.tier), const SizedBox(width: 10), Expanded(child: tx('आपकी रैंक #${app.rank}', z: 16, b: true))]),
        const SizedBox(height: 10),
        bar(app.tierFrac),
        const SizedBox(height: 4),
        tx('${app.points} अंक', z: 12, c: pal.dim),
      ])),
      sec('टियर सीढ़ी'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (int i = 0; i < kTierNames.length; i++) Seg(['${kTierNames[i]} ${kTierMin[i]}'], app.tier == i ? 0 : -1, (_) {}),
      ]),
      sec('ग्लोबल लीडरबोर्ड (सिम्युलेटेड)'),
      for (int i = 0; i < min(30, rows.length); i++) row(i),
      if (my >= 30) ...[
        Center(child: tx('...')),
        const SizedBox(height: 6),
        row(my),
      ],
    ]);
  }
}

class SeasonPage extends StatelessWidget {
  const SeasonPage({super.key});
  @override
  Widget build(BuildContext c) {
    final reached = app.seasonPoints ~/ 250;
    return pg([
      box(Column(children: [
        kv('सीज़न', app.season),
        kv('सीज़न अंक', '${app.seasonPoints}'),
        kv('पूर्ण माइलस्टोन', '${min(10, reached)}/10'),
        const SizedBox(height: 6),
        bar(min(1.0, app.seasonPoints / 2500)),
      ])),
      for (int i = 1; i <= 10; i++)
        box(Row(children: [
          Icon(reached >= i ? Icons.check_box : Icons.check_box_outline_blank, color: pal.ink),
          const SizedBox(width: 12),
          Expanded(child: tx('माइलस्टोन $i', b: true)),
          tx('${i * 250} अंक'),
        ]), m: const EdgeInsets.only(bottom: 8)),
    ]);
  }
}

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});
  @override
  Widget build(BuildContext c) {
    final keys = app.h2h.keys.toList()..sort((a, b) => app.h2h[b]!.reduce((x, y) => x + y).compareTo(app.h2h[a]!.reduce((x, y) => x + y)));
    return pg([
      sec('पर्सनल रिकॉर्ड'),
      box(Column(children: [
        kv('सर्वश्रेष्ठ मैच स्कोर', '${app.bestScore}'),
        kv('सर्वश्रेष्ठ जीत स्ट्रीक', '${app.bestStreak}'),
        kv('सर्वश्रेष्ठ कॉम्बो', '${app.bestCombo}'),
        kv('सर्वश्रेष्ठ सटीकता', '${app.bestAcc}%'),
        kv('एंडलेस सर्वश्रेष्ठ', '${app.endlessBest}'),
        kv('ट्रॉफियाँ', '${app.trophies}'),
      ])),
      sec('हेड-टू-हेड (जीत-हार-ड्रा)'),
      if (keys.isEmpty) tx('अभी कोई रिकॉर्ड नहीं', c: pal.dim),
      for (final k in keys) box(kv(k, '${app.h2h[k]![0]}-${app.h2h[k]![1]}-${app.h2h[k]![2]}'), m: const EdgeInsets.only(bottom: 8)),
    ]);
  }
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});
  @override
  Widget build(BuildContext c) {
    return pg([
      box(kv('दैनिक स्ट्रीक', '${app.dailyStreak} दिन')),
      if (app.log.isEmpty) tx('अभी कोई गतिविधि नहीं', c: pal.dim),
      for (final e in app.log) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: tx(e, z: 13)),
    ]);
  }
}

class ProPage extends StatelessWidget {
  const ProPage({super.key});
  @override
  Widget build(BuildContext c) {
    const perks = [
      '60 से आगे सभी अतिरिक्त सेक्टर (61 से 300)',
      'एडवांस ग्रिड 6x6 से 9x9 और कस्टम आकार',
      'असीमित अनडू',
      'डबल पॉइंट बूस्टर',
      'विशेष रैंक बैज',
    ];
    if (!app.pro) {
      return pg([
        tx('प्रो अपग्रेड', z: 22, b: true),
        const SizedBox(height: 4),
        tx('लाइफटाइम अनलॉक: एक बार का अपग्रेड, कोई सब्सक्रिप्शन नहीं।', c: pal.dim),
        const SizedBox(height: 12),
        box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final p in perks) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(Icons.check, size: 18, color: pal.ink), const SizedBox(width: 8), Expanded(child: tx(p))])),
        ])),
        Btn('हमेशा के लिए अनलॉक करें', () async {
          final ok = await askYes('प्रो अनलॉक', 'सभी प्रो सुविधाएँ स्थायी रूप से सक्रिय होंगी।', yes: 'अनलॉक');
          if (ok) {
            app.pro = true;
            app.addLog('प्रो अनलॉक');
            app.commit();
          }
        }, fill: true, ic: Icons.star),
      ]);
    }
    return pg([
      box(Row(children: [Icon(Icons.verified, color: pal.ink), const SizedBox(width: 10), Expanded(child: tx('प्रो सक्रिय: लाइफटाइम', z: 16, b: true))])),
      sec('प्रो कमांड सूट'),
      Tog('डबल पॉइंट बूस्टर', app.boost, (v) {
        app.boost = v;
        app.commit();
      }),
      kv('असीमित अनडू', 'सक्रिय'),
      kv('विशेष रैंक बैज', 'सक्रिय'),
      kv('प्रो सेक्टर', '61 से 300'),
      kv('एडवांस ग्रिड', 'उपलब्ध'),
      const SizedBox(height: 12),
      Btn('सेक्टर सूची खोलें', () => nav.push('sectors'), ic: Icons.grid_on),
      const SizedBox(height: 10),
      Btn('एडवांस ग्रिड मैच', () => nav.push('setup', {'mode': 1}), ic: Icons.apps),
    ]);
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext c) {
    final pv = Game(const Cfg(n: 3, seed: 3));
    pv.cells[0] = 0;
    pv.cells[4] = 1;
    pv.cells[8] = 0;
    pv.cells[2] = -2;
    pv.last = 4;
    void commit(void Function() f) {
      f();
      app.commit();
    }

    return pg([
      Tog('डार्क मोड', app.dark, (v) => commit(() => app.dark = v)),
      Tog('साउंड इफेक्ट', app.sound, (v) => commit(() => app.sound = v)),
      Tog('हैप्टिक वाइब्रेशन', app.haptic, (v) => commit(() => app.haptic = v)),
      Tog('बैटरी सेवर / लो-एनिमेशन', app.saver, (v) => commit(() => app.saver = v)),
      Tog('ग्रिड कोऑर्डिनेट्स और नंबर लेबल', app.coords, (v) => commit(() => app.coords = v)),
      sec('राउंड स्पीड'),
      Seg(const ['धीमा', 'सामान्य', 'तेज़'], app.speed, (k) => commit(() => app.speed = k)),
      sec('ग्रिड लाइन मोटाई'),
      Seg(const ['1', '2', '3', '4'], app.thick - 1, (k) => commit(() => app.thick = k + 1)),
      sec('ग्रिड लाइन स्टाइल'),
      Seg(const ['सीधी', 'गोल', 'मोटा फ्रेम'], app.lineStyle, (k) => commit(() => app.lineStyle = k)),
      sec('सेल मार्किंग स्टाइल'),
      Seg(const ['क्रॉस', 'सर्कल', 'ब्लॉक', 'डॉट', 'नंबर'], app.mark, (k) => commit(() => app.mark = k)),
      sec('प्रीव्यू'),
      SizedBox(height: 170, child: Board(pv)),
      sec('डेटा'),
      Btn('कैश और सेशन डेटा क्लीनअप', () async {
        final ok = await askYes('क्लीनअप', 'चेकपॉइंट और पुराना लॉग साफ होगा। प्रोग्रेस सुरक्षित रहेगी।');
        if (ok) {
          app.cleanup();
          toast('क्लीनअप पूर्ण');
        }
      }, ic: Icons.cleaning_services),
      const SizedBox(height: 10),
      Btn('लोकल प्रोग्रेस रीसेट', () async {
        final a = await askYes('प्रोग्रेस रीसेट', 'सभी अंक, सेक्टर और आँकड़े मिट जाएँगे। सेटिंग और प्रो सुरक्षित रहेंगे।');
        if (!a) return;
        final b = await askYes('अंतिम पुष्टि', 'यह क्रिया वापस नहीं हो सकती। रीसेट करें?', yes: 'रीसेट करें');
        if (b) {
          app.resetProgress();
          toast('प्रोग्रेस रीसेट हुई');
        }
      }, ic: Icons.delete_outline),
    ]);
  }
}

class RulesPage extends StatelessWidget {
  const RulesPage({super.key});
  @override
  Widget build(BuildContext c) {
    const r = [
      ['लक्ष्य', 'बारी-बारी से खाली सेल पर निशान लगाएँ और अधिक स्कोर बनाएँ।'],
      ['अंक', 'हर चाल पर 1 अंक। लगातार तीन या अधिक निशान की कतार बनने पर (लंबाई - 2) x 3 बोनस मिलता है।'],
      ['चेन बोनस', 'एक चाल से एक से अधिक दिशाओं में लाइन बने तो अतिरिक्त चेन बोनस मिलता है।'],
      ['कॉम्बो', 'लगातार लाइन बनाने पर गुणक बढ़ता है, अधिकतम x3।'],
      ['सटीकता', 'जो चालें अपने निशान के साथ जुड़ती हैं, वे सटीक मानी जाती हैं। जीत पर सटीकता बोनस मिलता है।'],
      ['ब्लॉक्ड सेल', 'हैच वाले सेल बंद हैं और उन पर चाल नहीं चल सकती।'],
      ['चाल टाइमर', 'समय खत्म होने पर अपने आप चाल चली जाती है और 2 अंक की पेनल्टी लगती है।'],
      ['सडन डेथ', 'पहली लाइन बनाने वाला तुरंत जीतता है। ड्रा पर टाई-ब्रेकर खेला जा सकता है।'],
      ['पावर-अप', 'अनडू, हिंट, टाइम फ्रीज़, समय बढ़ाना, अतिरिक्त चांस, बोर्ड विस्तार और बोर्ड क्लियर।'],
      ['रिवाइव', 'समय या चाल सीमा से हारने पर एक बार अतिरिक्त चांस मिल सकता है।'],
      ['रैंक', 'ब्रॉन्ज़ से ग्रैंडमास्टर तक अंकों के आधार पर टियर बदलते हैं।'],
      ['बैक बटन', 'हर दबाव पर एक स्तर पीछे जाता है। होम पर बाहर निकलने की पुष्टि माँगी जाती है।'],
    ];
    return pg([for (final e in r) box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [tx(e[0], z: 15, b: true), const SizedBox(height: 4), tx(e[1], z: 13)]))]);
  }
}

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});
  @override
  State<StatusPage> createState() => _StatusState();
}

class _StatusState extends State<StatusPage> {
  List<List<dynamic>> res = [];

  void _run() {
    final o = <List<dynamic>>[];
    bool ok1 = true;
    try {
      ok1 = jsonDecode(jsonEncode(app.toJson())) is Map;
    } catch (_) {
      ok1 = false;
    }
    o.add(['डेटा JSON राउंड-ट्रिप', ok1]);
    o.add(['अंक और आँकड़ों की सीमा', app.points >= 0 && app.wins >= 0 && app.matches >= 0]);
    bool cp = true;
    if (app.checkpoint != null) {
      try {
        Game.fromJson(app.checkpoint!);
      } catch (_) {
        cp = false;
      }
    }
    o.add(['चेकपॉइंट संरचना', cp]);
    o.add(['लोकल स्टोरेज उपलब्ध', app.hasStore]);
    o.add(['नेटवर्क उपयोग: कोई नहीं', true]);
    o.add(['विज्ञापन: कोई नहीं', true]);
    setState(() => res = o);
  }

  @override
  Widget build(BuildContext c) {
    final size = jsonEncode(app.toJson()).length;
    final cleared = app.sec.values.where((e) => e[1] > 0).length;
    return pg([
      box(Column(children: [
        kv('ऐप', 'Anivore'),
        kv('वर्ज़न', kVersion),
        kv('मोड', 'पूर्णतः ऑफलाइन'),
        kv('संस्करण', app.pro ? 'प्रो (लाइफटाइम)' : 'स्टैंडर्ड'),
        kv('सहेजा गया डेटा', '$size बाइट'),
        kv('अंतिम ऑटो-सेव', app.lastSave == 0 ? '-' : DateTime.fromMillisecondsSinceEpoch(app.lastSave).toString().substring(0, 19)),
        kv('चेकपॉइंट', app.checkpoint == null ? 'नहीं' : 'उपलब्ध'),
        kv('क्लियर सेक्टर', '$cleared/$kSectors'),
        kv('सक्रिय टूर्नामेंट', app.tour == null ? 'नहीं' : 'हाँ'),
      ])),
      Btn('डायग्नोस्टिक जाँच चलाएँ', _run, fill: true, ic: Icons.health_and_safety),
      const SizedBox(height: 12),
      for (final r in res) box(Row(children: [Expanded(child: tx(r[0] as String)), tx((r[1] as bool) ? 'ठीक' : 'त्रुटि', b: true)]), m: const EdgeInsets.only(bottom: 8)),
    ]);
  }
}
