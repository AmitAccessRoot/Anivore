import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kBlack = Color(0xFF111111), kGrey = Color(0xFF8A8A8A), kLine = Color(0xFFE2E2E2), kGold = Color(0xFFC9A227);
const names = ['Rohit Kumar', 'Sonu Kumar', 'Chandan Kumar', 'Rajesh Verma', 'Amit Singh', 'Priya Sharma', 'Vikas Yadav', 'Neha Gupta', 'Arjun Mehta', 'Sanjay Das', 'Pooja Rani', 'Manoj Tiwari', 'Kiran Patel', 'Deepak Joshi'];
const avatars = [Icons.pets, Icons.face, Icons.rocket_launch, Icons.sports_esports, Icons.bolt, Icons.star, Icons.shield, Icons.local_fire_department];
const reactions = ['Hurry Up!', 'Well Played!', 'Good Luck!', 'Nice Move!'];

late SharedPreferences P;
final tick = ValueNotifier<int>(0);
int gi(String k, [int d = 0]) => P.getInt(k) ?? d;
bool gb(String k, [bool d = true]) => P.getBool(k) ?? d;
void si(String k, int v) { P.setInt(k, v); tick.value++; }
void sb(String k, bool v) { P.setBool(k, v); tick.value++; }
bool get isPro => gb('pro', false);
String tier(int t) => t < 100 ? 'Bronze' : t < 300 ? 'Silver' : t < 600 ? 'Gold' : t < 1000 ? 'Platinum' : 'Diamond';
void hap([bool strong = false]) {
  if (gb('vib')) { strong ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact(); }
  if (gb('snd')) SystemSound.play(SystemSoundType.click);
}
void go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, systemNavigationBarIconBrightness: Brightness.dark));
  P = await SharedPreferences.getInstance();
  if (!P.containsKey('coins')) { P.setInt('coins', 100); P.setInt('undos', 3); }
  final day = DateTime.now().difference(DateTime(2020)).inDays, last = gi('last', -1);
  if (last != day) {
    P.setInt('streak', last == day - 1 ? gi('streak') + 1 : 1);
    P.setInt('last', day);
    P.setInt('coins', gi('coins') + 5);
  }
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Anivore',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: false,
          scaffoldBackgroundColor: Colors.white,
          canvasColor: Colors.white,
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          colorScheme: const ColorScheme.light(primary: kBlack, secondary: kBlack, surface: Colors.white),
          textSelectionTheme: const TextSelectionThemeData(cursorColor: kBlack, selectionColor: Colors.black12, selectionHandleColor: kBlack),
          dialogBackgroundColor: Colors.white,
        ),
        home: const Shell(),
      );
}

class Btn extends StatelessWidget {
  final String t; final VoidCallback? f; final bool dark; final double h;
  const Btn(this.t, this.f, {super.key, this.dark = false, this.h = 52});
  @override
  Widget build(BuildContext c) => Opacity(
        opacity: f == null ? .35 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: f == null ? null : () { hap(); f!(); },
          child: Container(
            height: h, alignment: Alignment.center,
            decoration: BoxDecoration(color: dark ? kBlack : Colors.white, border: Border.all(color: kBlack, width: 1.5), borderRadius: BorderRadius.circular(12)),
            child: Text(t, style: TextStyle(color: dark ? Colors.white : kBlack, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ),
      );
}

class Pg extends StatelessWidget {
  final String title; final Widget child;
  const Pg(this.title, this.child, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => Navigator.pop(c), child: const Icon(Icons.arrow_back, color: kBlack)),
                const SizedBox(width: 14),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kBlack)),
              ]),
            ),
            Expanded(child: child),
          ]),
        ),
      );
}

Widget stat(String l, String v) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(color: kGrey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kBlack)),
        ]),
      ),
    );

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellS();
}

class _ShellS extends State<Shell> {
  int tab = 0;
  Widget nav(int i, IconData on, IconData off) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () { hap(); setState(() => tab = i); },
          child: SizedBox(height: 56, child: Icon(tab == i ? on : off, color: tab == i ? kBlack : kGrey, size: 28)),
        ),
      );
  @override
  Widget build(BuildContext c) => ValueListenableBuilder<int>(
        valueListenable: tick,
        builder: (_, __, ___) => PopScope(
          canPop: tab == 0,
          onPopInvokedWithResult: (didPop, _) { if (!didPop) setState(() => tab = 0); },
          child: Scaffold(
            body: Column(children: [
              Expanded(child: SafeArea(bottom: false, child: tab == 0 ? const Home() : const Account())),
              Container(
                padding: EdgeInsets.only(bottom: MediaQuery.of(c).padding.bottom),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kLine))),
                child: Row(children: [nav(0, Icons.home, Icons.home_outlined), nav(1, Icons.person, Icons.person_outline)]),
              ),
            ]),
          ),
        ),
      );
}

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext c) {
    final t = gi('trophies');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Anivore', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1, color: kBlack)),
        Text('${tier(t)} tier${isPro ? '  |  PRO' : ''}', style: TextStyle(color: isPro ? kGold : kGrey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        Row(children: [stat('Coins', '${gi('coins')}'), stat('Trophies', '$t')]),
        const SizedBox(height: 28),
        Btn('Play vs Computer', () => go(c, const Game(mode: 1, opp: 'Computer')), dark: true),
        const SizedBox(height: 12),
        Btn('Find Online Battle', () => go(c, const Match())),
        const SizedBox(height: 12),
        Btn('2 Player Local', () => go(c, const Game(mode: 0, opp: 'Player 2'))),
        const SizedBox(height: 12),
        Btn('Global Leaderboard', () => go(c, const Board())),
      ]),
    );
  }
}

class Match extends StatefulWidget {
  const Match({super.key});
  @override
  State<Match> createState() => _MatchS();
}

class _MatchS extends State<Match> {
  final r = Random();
  Timer? t; int i = 0; String? pick;
  @override
  void initState() {
    super.initState();
    final end = DateTime.now().add(Duration(milliseconds: isPro ? 800 : 5000 + r.nextInt(5001)));
    t = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) return;
      if (DateTime.now().isAfter(end)) {
        t?.cancel();
        setState(() => pick = names[r.nextInt(names.length)]);
        hap(true);
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Game(mode: 2, opp: pick!)));
        });
      } else {
        setState(() => i = r.nextInt(names.length));
      }
    });
  }
  @override
  void dispose() { t?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext c) => Pg(
        'Finding opponent',
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(pick == null ? 'Searching...' : 'Opponent found', style: const TextStyle(color: kGrey)),
            const SizedBox(height: 24),
            for (var k = -2; k <= 2; k++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  k == 0 && pick != null ? pick! : names[(i + k + names.length) % names.length],
                  style: TextStyle(fontSize: k == 0 ? 28 : 16, fontWeight: k == 0 ? FontWeight.w800 : FontWeight.w400, color: k == 0 ? kBlack : kGrey),
                ),
              ),
          ]),
        ),
      );
}

class Game extends StatefulWidget {
  final int mode; final String opp; // 0 local, 1 computer, 2 online (simulated)
  const Game({super.key, required this.mode, required this.opp});
  @override
  State<Game> createState() => _GameS();
}

class _GameS extends State<Game> {
  static const lines = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]];
  final r = Random();
  List<String> b = List.filled(9, '');
  List<int> hist = [];
  String turn = 'X', msg = ''; String? res;
  double left = 10; bool sudden = false, counted = false;
  Timer? tm, aiT, msgT;
  int get mode => widget.mode;
  double get lim => sudden ? 5 : 10;

  @override
  void initState() {
    super.initState();
    tm = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (res != null || !mounted) return;
      setState(() {
        left -= .1;
        if (left <= 0) { turn = turn == 'X' ? 'O' : 'X'; left = lim; _ai(); }
      });
    });
  }
  @override
  void dispose() { tm?.cancel(); aiT?.cancel(); msgT?.cancel(); super.dispose(); }

  String? winner(List<String> x) {
    for (final l in lines) { if (x[l[0]] != '' && x[l[0]] == x[l[1]] && x[l[1]] == x[l[2]]) return x[l[0]]; }
    return null;
  }
  int pickMove() {
    final free = [for (var i = 0; i < 9; i++) if (b[i] == '') i];
    for (final p in ['O', 'X']) {
      for (final i in free) { final t = [...b]; t[i] = p; if (winner(t) != null) return i; }
    }
    if (b[4] == '') return 4;
    return free[r.nextInt(free.length)];
  }
  void _ai() {
    aiT?.cancel();
    if (mode == 0 || turn != 'O' || res != null) return;
    aiT = Timer(Duration(milliseconds: 600 + r.nextInt(900)), () { if (mounted && res == null && turn == 'O') setState(() => move(pickMove())); });
  }
  void tap(int i) {
    if (res != null || b[i] != '' || (mode != 0 && turn != 'X')) return;
    setState(() => move(i));
  }
  void move(int i) {
    b[i] = turn; hist.add(i); hap();
    final w = winner(b);
    if (w != null) { res = w; finish(); }
    else if (!b.contains('')) { res = 'D'; hap(true); }
    else { turn = turn == 'X' ? 'O' : 'X'; left = lim; _ai(); }
  }
  void finish() {
    hap(true);
    if (mode == 0) return;
    if (!counted) { si('played', gi('played') + 1); counted = true; }
    if (res == 'X') {
      si('wins', gi('wins') + 1);
      si('trophies', gi('trophies') + (isPro ? 20 : 10));
      si('coins', gi('coins') + 10);
    } else {
      si('trophies', max(0, gi('trophies') - 5));
    }
  }
  void undo() {
    if (hist.isEmpty || res != null) return;
    if (!isPro) {
      if (gi('undos') <= 0) { say('No undo left. Buy one for 30 coins.'); return; }
      si('undos', gi('undos') - 1);
    }
    aiT?.cancel();
    final n = (mode != 0 && turn == 'X' && hist.length >= 2) ? 2 : 1;
    for (var k = 0; k < n; k++) { b[hist.removeLast()] = ''; }
    turn = mode == 0 ? (turn == 'X' ? 'O' : 'X') : 'X';
    left = lim;
  }
  void revive() {
    if (!isPro) {
      if (gi('coins') < 50) { say('Need 50 coins to revive.'); return; }
      si('coins', gi('coins') - 50);
    }
    for (var k = 0; k < 2 && hist.isNotEmpty; k++) { b[hist.removeLast()] = ''; }
    res = null; turn = 'X'; left = lim;
  }
  void reset({bool sd = false}) {
    aiT?.cancel();
    b = List.filled(9, ''); hist = []; res = null; turn = 'X'; sudden = sd; left = lim; counted = false;
  }
  void say(String m) {
    msg = m; msgT?.cancel();
    msgT = Timer(const Duration(seconds: 2), () { if (mounted) setState(() => msg = ''); });
  }

  @override
  Widget build(BuildContext c) {
    final lost = res == 'O' && mode != 0;
    final status = res == null
        ? (mode == 0 ? 'Player $turn turn' : turn == 'X' ? 'Your turn' : '${widget.opp} is thinking')
        : res == 'D' ? 'Draw' : mode == 0 ? 'Player $res wins' : res == 'X' ? 'You win' : '${widget.opp} wins';
    return Pg(
      mode == 0 ? 'Local 2 Player' : 'vs ${widget.opp}',
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(children: [
          Text(status + (sudden ? '  (Sudden Death)' : ''), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kBlack)),
          const SizedBox(height: 12),
          Container(
            height: 8, alignment: Alignment.centerLeft,
            decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(4)),
            child: FractionallySizedBox(widthFactor: (left / lim).clamp(0.0, 1.0), child: Container(decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)))),
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1,
            child: GridView.count(
              crossAxisCount: 3, physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < 9; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque, onTap: () => tap(i),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border.all(color: kLine, width: 1.5)),
                      child: Text(b[i], style: TextStyle(fontSize: 56, fontWeight: FontWeight.w300, color: b[i] == 'X' ? kBlack : kGrey)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(height: 22, child: Text(msg, style: const TextStyle(color: kGrey))),
          if (res == null) ...[
            Row(children: [
              Expanded(child: Btn(isPro ? 'Undo (Unlimited)' : 'Undo (${gi('undos')})', undo, h: 44)),
              const SizedBox(width: 8),
              Expanded(child: Btn('Buy Undo (30)', isPro ? null : () {
                if (gi('coins') < 30) { say('Not enough coins.'); return; }
                si('coins', gi('coins') - 30); si('undos', gi('undos') + 1);
              }, h: 44)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final q in reactions)
                GestureDetector(
                  behavior: HitTestBehavior.opaque, onTap: () => setState(() => say(q)),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(20)), child: Text(q, style: const TextStyle(fontSize: 13, color: kBlack))),
                ),
            ]),
          ] else ...[
            Btn(lost ? 'Revenge' : 'Play Again', () => setState(reset), dark: true),
            if (res == 'D') ...[const SizedBox(height: 10), Btn('Sudden Death Round', () => setState(() => reset(sd: true)))],
            if (lost) ...[const SizedBox(height: 10), Btn(isPro ? 'Instant Revive (Free)' : 'Instant Revive (50 coins)', () => setState(revive))],
          ],
        ]),
      ),
    );
  }
}

class Board extends StatelessWidget {
  const Board({super.key});
  @override
  Widget build(BuildContext c) {
    final r = Random(7), t = gi('trophies');
    final sims = [for (var i = 0; i < 25; i++) (names[i % names.length] + (i >= names.length ? ' ${i ~/ names.length + 1}' : ''), 2400 - i * 70 - r.nextInt(30))];
    final above = sims.where((s) => s.$2 > t).length;
    final rank = above < sims.length ? above + 1 : max(26, 5000 - t * 5);
    Widget row(int n, String name, int s, {bool me = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(border: const Border(bottom: BorderSide(color: kLine)), color: me ? const Color(0xFFF5F5F5) : Colors.white),
          child: Row(children: [
            SizedBox(width: 48, child: Text('#$n', style: const TextStyle(color: kGrey, fontWeight: FontWeight.w600))),
            Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: me && isPro ? kGold : kBlack))),
            if (me && isPro) Container(margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(4)), child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
            Text('$s  ${tier(s)}', style: const TextStyle(color: kGrey, fontSize: 13)),
          ]),
        );
    return Pg('Global Leaderboard', Column(children: [
      Expanded(child: ListView(children: [for (var i = 0; i < sims.length; i++) row(i + 1, sims[i].$1, sims[i].$2)])),
      row(rank, 'You', t, me: true),
      SizedBox(height: MediaQuery.of(c).padding.bottom > 0 ? 0 : 8),
    ]));
  }
}

class Account extends StatelessWidget {
  const Account({super.key});
  Widget toggle(String l, String k) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(l, style: const TextStyle(fontSize: 16, color: kBlack))),
          Switch(value: gb(k), onChanged: (v) => sb(k, v), activeColor: kBlack, activeTrackColor: kGrey, inactiveThumbColor: kGrey, inactiveTrackColor: kLine, overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
        ]),
      );
  @override
  Widget build(BuildContext c) {
    final p = gi('played'), w = gi('wins'), t = gi('trophies'), av = gi('avatar');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isPro ? kGold : kBlack, width: 2)), child: Icon(avatars[av], size: 32, color: kBlack)),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('You', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isPro ? kGold : kBlack)),
              if (isPro) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(4)), child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
            ]),
            Text('${tier(t)} tier', style: const TextStyle(color: kGrey)),
          ]),
        ]),
        const SizedBox(height: 20),
        Wrap(spacing: 14, children: [
          for (var i = 0; i < avatars.length; i++)
            GestureDetector(behavior: HitTestBehavior.opaque, onTap: () { hap(); si('avatar', i); },
                child: Container(margin: const EdgeInsets.only(bottom: 10), width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: av == i ? kBlack : kLine, width: av == i ? 2 : 1)), child: Icon(avatars[i], color: av == i ? kBlack : kGrey))),
        ]),
        const SizedBox(height: 10),
        Row(children: [stat('Matches', '$p'), stat('Wins', '$w')]),
        const SizedBox(height: 8),
        Row(children: [stat('Win rate', p == 0 ? '0%' : '${(w * 100 / p).round()}%'), stat('Login streak', '${gi('streak')} d')]),
        const SizedBox(height: 8),
        Row(children: [stat('Trophies', '$t'), stat('Coins', '${gi('coins')}')]),
        const SizedBox(height: 24),
        toggle('Sound', 'snd'),
        toggle('Vibration', 'vib'),
        const SizedBox(height: 20),
        if (!isPro) ...[
          Btn('BECOME PRO', () => showDialog(context: c, builder: (d) => AlertDialog(
                backgroundColor: Colors.white, surfaceTintColor: Colors.transparent,
                title: const Text('Anivore PRO Lifetime'),
                content: const Text('One-time purchase, no subscription.\n\nUnlimited undo\nGolden name and PRO badge\n2x trophies on every win\nInstant matchmaking\nFree revive'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d), style: TextButton.styleFrom(foregroundColor: kBlack, splashFactory: NoSplash.splashFactory), child: const Text('Cancel')),
                  // TODO: replace with in_app_purchase (non-consumable) before release.
                  TextButton(onPressed: () { sb('pro', true); Navigator.pop(d); }, style: TextButton.styleFrom(foregroundColor: kBlack, splashFactory: NoSplash.splashFactory), child: const Text('Buy lifetime pass')),
                ],
              )), dark: true),
        ] else
          const Text('PRO unlocked for life: unlimited undo, 2x trophies, instant matchmaking, golden name.', style: TextStyle(color: kGold, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
