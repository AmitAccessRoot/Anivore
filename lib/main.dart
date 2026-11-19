import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const List<String> _qrRows = <String>[
  'fed87bace8bf8',
  '82ab848897a08',
  'ba513c6821ae8',
  'bac76912c12e8',
  'babd3fe2542e8',
  '82a82a32da208',
  'feaaaaaaaabf8',
  '0028b235a1000',
  '126f3ff7191d8',
  'f0c09a3f85000',
  '47c9a205a9058',
  'd526f88fdb9d0',
  'ff0d13355f1c8',
  '10e59c572cd08',
  'caab2a5287588',
  '151e8726bacb8',
  'aebc0a5b2d798',
  '914d7cf9a1018',
  '1370b8932bfe8',
  '69abde01e9fb0',
  '9303b00b39450',
  'a505600118468',
  '9fce70022cf98',
  '588b4000e78c8',
  '4aaea002fead8',
  '58ebe001298f0',
  '3fd880041ffb8',
  'a9d42002e8790',
  '53c6980deefa8',
  '91284c3597848',
  '9b4677d0e1a18',
  '50e5cbb2113f0',
  'eba9fa07e0788',
  '7de332a19d930',
  '4661c81831fd8',
  'fc6678e60e1d0',
  'c3c3b482f8250',
  '150a104374b78',
  '469ca26bdeef8',
  '717f2e1bcc250',
  'e2a347fecafd0',
  '00e9b626468d8',
  'fe727abd6faa8',
  '823db220688a0',
  'ba29cbfb7df80',
  'baaafb9c41090',
  'ba34f54af99f8',
  '8208532b5bd40',
  'fe5876c78d558',
];

List<List<bool>> _parseQr() {
  final List<List<bool>> out = <List<bool>>[];
  for (final String row in _qrRows) {
    final List<bool> bits = <bool>[];
    for (int c = 0; c < 49; c++) {
      final int digit = int.parse(row[c ~/ 4], radix: 16);
      bits.add(((digit >> (3 - (c % 4))) & 1) == 1);
    }
    out.add(bits);
  }
  return out;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const TwoCardGameApp());
}

class TwoCardGameApp extends StatelessWidget {
  const TwoCardGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Two Card Game',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(primary: Colors.black),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionColor: Color(0xFFDDDDDD),
          selectionHandleColor: Colors.black,
        ),
      ),
      home: const GamePage(),
    );
  }
}

enum _Screen { home, amount, pick, game, wallet, history, qr, upi, done }

class _Entry {
  const _Entry(this.title, this.amount, this.note, this.time);

  final String title;
  final double amount;
  final String note;
  final String time;
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.bits, this.cell);

  final List<List<bool>> bits;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final Paint dark = Paint()
      ..color = const Color(0xFF191919)
      ..isAntiAlias = false;
    for (int r = 0; r < bits.length; r++) {
      final List<bool> row = bits[r];
      for (int c = 0; c < row.length; c++) {
        if (row[c]) {
          canvas.drawRect(
            Rect.fromLTWH((c + 4) * cell, (r + 4) * cell, cell, cell),
            dark,
          );
        }
      }
    }
    final Offset centre = Offset(28.5 * cell, 28.5 * cell);
    canvas.drawCircle(centre, 5.6875 * cell, Paint()..color = Colors.white);
    canvas.drawCircle(centre, 5.1875 * cell, Paint()..color = Colors.black);
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: 'पे',
        style: TextStyle(
          color: Colors.white,
          fontSize: cell * 5.2,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(centre.dx - tp.width / 2, centre.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.cell != cell;
}

class _HomeIconPainter extends CustomPainter {
  const _HomeIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / 24;
    final Path p = Path()
      ..moveTo(12 * k, 2.5 * k)
      ..lineTo(1.5 * k, 12 * k)
      ..lineTo(5 * k, 12 * k)
      ..lineTo(5 * k, 21 * k)
      ..lineTo(10 * k, 21 * k)
      ..lineTo(10 * k, 15 * k)
      ..lineTo(14 * k, 15 * k)
      ..lineTo(14 * k, 21 * k)
      ..lineTo(19 * k, 21 * k)
      ..lineTo(19 * k, 12 * k)
      ..lineTo(22.5 * k, 12 * k)
      ..close();
    canvas.drawPath(p, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WalletIconPainter extends CustomPainter {
  const _WalletIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / 24;
    final Paint black = Paint()..color = Colors.black;
    final Paint white = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2 * k, 5 * k, 20 * k, 15 * k),
        Radius.circular(3.5 * k),
      ),
      black,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(13 * k, 10 * k, 9 * k, 5.5 * k),
        Radius.circular(2.5 * k),
      ),
      white,
    );
    canvas.drawCircle(Offset(16.5 * k, 12.75 * k), 1.1 * k, black);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  final math.Random _rnd = math.Random();
  final List<List<bool>> _qr = _parseQr();
  final TextEditingController _amtC = TextEditingController();
  final TextEditingController _upiC = TextEditingController();
  late final Ticker _ticker;
  Timer? _secTimer;
  Timer? _pickTimer;
  Timer? _doneTimer;

  _Screen _screen = _Screen.home;
  double _s = 1;
  double _bal = 5;
  double _bet = 0;
  int _sel = 0;
  bool _run = false;
  bool _locked = false;
  bool _popup = false;
  int _sec = 60;
  double _last = 0;
  double _pend = 0;
  bool _nextVisible = false;
  String _amtErr = '';
  String _upiErr = '';
  final List<double> _m = <double>[1, 1];
  final List<double> _v = <double>[0, 0];
  final List<double> _tv = <double>[0, 0];
  final List<double> _nc = <double>[0, 0];
  final List<double> _vals = <double>[0, 0];
  final List<_Entry> _hist = <_Entry>[];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _secTimer?.cancel();
    _pickTimer?.cancel();
    _doneTimer?.cancel();
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _ticker.dispose();
    _amtC.dispose();
    _upiC.dispose();
    super.dispose();
  }

  double _r2(double n) => (n * 100).round() / 100;

  String _fmt(double n) {
    final double r = _r2(n);
    if (r == r.truncateToDouble()) {
      return r.toInt().toString();
    }
    String t = r.toStringAsFixed(2);
    if (t.endsWith('0')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  double _parse(String t) {
    final double? x = double.tryParse(t.replaceAll(',', '.'));
    return x ?? 0;
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';

  void _log(String title, double amount, String note) {
    final DateTime d = DateTime.now();
    _hist.insert(0, _Entry(title, amount, note, '${_two(d.hour)}:${_two(d.minute)}'));
  }

  void _onTick(Duration elapsed) {
    final double now = elapsed.inMicroseconds / 1000.0;
    double dt = (now - _last) / 1000.0;
    if (dt > 0.05) {
      dt = 0.05;
    }
    if (dt < 0) {
      dt = 0;
    }
    _last = now;
    for (int i = 0; i < 2; i++) {
      if (now >= _nc[i]) {
        _tv[i] = (_rnd.nextDouble() * 2 - 1) * 0.1;
        _nc[i] = now + 1500 + _rnd.nextDouble() * 3000;
      }
      _v[i] += (_tv[i] - _v[i]) * math.min(1.0, dt * 1.5);
      _m[i] += _v[i] * dt;
      if (_m[i] < 1) {
        _m[i] = 1;
        _v[i] = _v[i].abs();
        _tv[i] = _tv[i].abs();
      }
      if (_m[i] > 2) {
        _m[i] = 2;
        _v[i] = -_v[i].abs();
        _tv[i] = -_tv[i].abs();
      }
      _vals[i] = _r2(_bet * _m[i]);
    }
    setState(() {});
  }

  void _go(_Screen screen) {
    FocusScope.of(context).unfocus();
    setState(() {
      _screen = screen;
    });
  }

  void _startGame() {
    _amtC.clear();
    setState(() {
      _amtErr = '';
      _nextVisible = false;
      _screen = _Screen.amount;
    });
  }

  void _onAmount(String t) {
    final double a = _parse(t);
    bool ok = a > 0;
    String err = '';
    if (ok && _r2(a) > _bal) {
      err = 'बैलेंस कम है';
      ok = false;
    }
    setState(() {
      _amtErr = err;
      _nextVisible = ok;
    });
  }

  void _toPick() {
    final double a = _parse(_amtC.text);
    if (!(a > 0) || _r2(a) > _bal) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _bet = _r2(a);
      _locked = false;
      _screen = _Screen.pick;
    });
  }

  void _pick(int i) {
    if (_locked || _run) {
      return;
    }
    setState(() {
      _locked = true;
      _sel = i;
    });
    _pickTimer?.cancel();
    _pickTimer = Timer(const Duration(milliseconds: 550), _begin);
  }

  void _begin() {
    if (!mounted) {
      return;
    }
    _secTimer?.cancel();
    if (_ticker.isActive) {
      _ticker.stop();
    }
    setState(() {
      _bal = _r2(_bal - _bet);
      _log('Bet', -_bet, '');
      _run = true;
      _locked = false;
      _sec = 60;
      for (int i = 0; i < 2; i++) {
        _m[i] = 1;
        _v[i] = 0;
        _tv[i] = 0;
        _nc[i] = 0;
        _vals[i] = _bet;
      }
      _last = 0;
      _screen = _Screen.game;
    });
    _ticker.start();
    _secTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      _sec--;
      if (_sec <= 0) {
        _finish();
      } else {
        setState(() {});
      }
    });
  }

  void _finish() {
    _secTimer?.cancel();
    if (_ticker.isActive) {
      _ticker.stop();
    }
    setState(() {
      _run = false;
      _pend = _vals[_sel];
      _popup = true;
    });
  }

  void _collect() {
    setState(() {
      _bal = _r2(_bal + _pend);
      _log('Success', _pend, '');
      _pend = 0;
      _popup = false;
      _screen = _Screen.home;
    });
  }

  void _openWithdraw() {
    _upiC.clear();
    setState(() {
      _upiErr = '';
      _screen = _Screen.upi;
    });
  }

  void _onUpi(String t) {
    setState(() {
      _upiErr = '';
    });
  }

  void _withdraw() {
    final String u = _upiC.text.trim();
    if (!(_bal > 0)) {
      setState(() {
        _upiErr = 'बैलेंस नहीं है';
      });
      return;
    }
    if (u.isEmpty) {
      setState(() {
        _upiErr = 'UPI नंबर डालें';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      final double a = _bal;
      _bal = 0;
      _log('Withdraw', -a, u);
      _screen = _Screen.done;
    });
    _doneTimer?.cancel();
    _doneTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted && _screen == _Screen.done) {
        setState(() {
          _screen = _Screen.wallet;
        });
      }
    });
  }

  TextStyle _ts(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = Colors.black,
  }) {
    return TextStyle(fontSize: size * _s, fontWeight: weight, color: color);
  }

  Widget _centered(Widget child) {
    return Center(child: SingleChildScrollView(child: child));
  }

  Widget _btn(
    String label,
    VoidCallback onTap, {
    Color bg = Colors.black,
    Color fg = Colors.white,
    Color border = Colors.black,
    double height = 46,
    IconData? icon,
  }) {
    final List<Widget> kids = <Widget>[];
    if (icon != null) {
      kids.add(Icon(icon, size: 20 * _s, color: fg));
      kids.add(SizedBox(width: 8 * _s));
    }
    kids.add(Text(label, style: _ts(15, color: fg)));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height * _s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12 * _s),
          border: Border.all(color: border, width: 1.5 * _s),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: kids),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint,
    double size,
    ValueChanged<String> onChanged, {
    bool money = false,
  }) {
    final OutlineInputBorder b = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12 * _s),
      borderSide: BorderSide(color: Colors.black, width: 1.5 * _s),
    );
    return SizedBox(
      height: 46 * _s,
      child: TextField(
        controller: c,
        onChanged: onChanged,
        expands: true,
        maxLines: null,
        minLines: null,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: money
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: money
            ? <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ]
            : <TextInputFormatter>[],
        cursorColor: Colors.black,
        style: TextStyle(fontSize: size * _s, color: Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: size * _s,
            color: const Color(0xFF999999),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 14 * _s),
          border: b,
          enabledBorder: b,
          focusedBorder: b,
        ),
      ),
    );
  }

  Widget _err(String t) {
    return SizedBox(
      height: 16 * _s,
      child: Center(
        child: Text(t, style: _ts(13, weight: FontWeight.w400, color: const Color(0xFFA32D2D))),
      ),
    );
  }

  Widget _plainCard(String label) {
    return Container(
      width: 96 * _s,
      height: 150 * _s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * _s),
        border: Border.all(color: Colors.black, width: 1.5 * _s),
      ),
      child: Text(label, style: _ts(15)),
    );
  }

  Widget _homeView() {
    return _centered(
      SizedBox(
        width: 212 * _s,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _plainCard('कार्ड 1'),
                SizedBox(width: 16 * _s),
                _plainCard('कार्ड 2'),
              ],
            ),
            SizedBox(height: 28 * _s),
            _btn('Start Game', _startGame),
          ],
        ),
      ),
    );
  }

  Widget _amountView() {
    final List<Widget> kids = <Widget>[
      Text('रकम डालें', style: _ts(20)),
      SizedBox(height: 14 * _s),
      _field(_amtC, '₹', 18, _onAmount, money: true),
      SizedBox(height: 6 * _s),
      _err(_amtErr),
    ];
    if (_nextVisible) {
      kids.add(SizedBox(height: 14 * _s));
      kids.add(_btn('कार्ड चुनें', _toPick));
    }
    return _centered(
      SizedBox(
        width: 204 * _s,
        child: Column(mainAxisSize: MainAxisSize.min, children: kids),
      ),
    );
  }

  Widget _pickCard(int i) {
    final bool chosen = _locked && _sel == i;
    final bool faded = _locked && _sel != i;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: faded ? 0.35 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.ease,
          width: (chosen ? 116.0 : 96.0) * _s,
          height: (chosen ? 176.0 : 150.0) * _s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14 * _s),
            border: Border.all(
              color: Colors.black,
              width: (chosen ? 3.0 : 1.5) * _s,
            ),
          ),
          child: Text('कार्ड ${i + 1}', style: _ts(15)),
        ),
      ),
    );
  }

  Widget _pickView() {
    return _centered(
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _pickCard(0),
          SizedBox(width: 12 * _s),
          _pickCard(1),
        ],
      ),
    );
  }

  Widget _gameCol(int i) {
    final bool chosen = _sel == i;
    final double p = _m[i] - 1;
    final double top = (8 + 208 * (1 - p)) * _s;
    return Column(
      children: <Widget>[
        Container(
          width: (chosen ? 108.0 : 92.0) * _s,
          height: 250 * _s,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14 * _s),
            border: Border.all(
              color: chosen ? Colors.black : const Color(0xFFBBBBBB),
              width: (chosen ? 3.0 : 1.5) * _s,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 10 * _s,
                right: 10 * _s,
                top: top,
                height: 34 * _s,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: chosen ? Colors.black : const Color(0xFF555555),
                    borderRadius: BorderRadius.circular(8 * _s),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 6 * _s),
        Text('₹${_vals[i].toStringAsFixed(2)}', style: _ts(20)),
      ],
    );
  }

  Widget _gameView() {
    return _centered(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 62 * _s,
            child: Center(child: Text('$_sec', style: _ts(30))),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _gameCol(0),
              SizedBox(width: 12 * _s),
              _gameCol(1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _walletView() {
    return _centered(
      SizedBox(
        width: 204 * _s,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('₹${_fmt(_bal)}', style: _ts(48)),
            SizedBox(height: 28 * _s),
            _btn('Deposit', () => _go(_Screen.qr), icon: Icons.add),
            SizedBox(height: 12 * _s),
            _btn(
              'Withdraw',
              _openWithdraw,
              bg: Colors.white,
              fg: Colors.black,
              icon: Icons.arrow_upward,
            ),
            SizedBox(height: 12 * _s),
            _btn(
              'History',
              () => _go(_Screen.history),
              bg: Colors.white,
              fg: Colors.black,
              icon: Icons.history,
            ),
          ],
        ),
      ),
    );
  }

  Widget _histRow(_Entry e) {
    final String sign = e.amount >= 0 ? '+' : '\u2212';
    final String sub = e.note.isEmpty ? e.time : '${e.time} · ${e.note}';
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10 * _s),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(e.title, style: _ts(15)),
                Text(
                  sub,
                  style: _ts(12, weight: FontWeight.w400, color: const Color(0xFF777777)),
                ),
              ],
            ),
          ),
          Text('${sign}₹${_fmt(e.amount.abs())}', style: _ts(15)),
        ],
      ),
    );
  }

  Widget _historyView() {
    final List<Widget> rows = <Widget>[];
    if (_hist.isEmpty) {
      rows.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12 * _s),
          child: Text(
            'कोई हिस्ट्री नहीं',
            style: _ts(14, weight: FontWeight.w400, color: const Color(0xFF777777)),
          ),
        ),
      );
    }
    for (final _Entry e in _hist) {
      rows.add(_histRow(e));
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(18 * _s, 16 * _s, 18 * _s, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('History', style: _ts(18)),
          SizedBox(height: 6 * _s),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: rows),
          ),
        ],
      ),
    );
  }

  Widget _qrView() {
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    double cellPx = (200 * _s * dpr / 57).floorToDouble();
    if (cellPx < 1) {
      cellPx = 1;
    }
    final double cell = cellPx / dpr;
    final double side = cell * 57;
    return Center(
      child: SizedBox(
        width: side,
        height: side,
        child: CustomPaint(painter: _QrPainter(_qr, cell)),
      ),
    );
  }

  Widget _upiView() {
    return _centered(
      SizedBox(
        width: 204 * _s,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('₹${_fmt(_bal)}', style: _ts(40)),
            SizedBox(height: 16 * _s),
            _field(_upiC, 'UPI नंबर', 16, _onUpi),
            SizedBox(height: 10 * _s),
            _err(_upiErr),
            SizedBox(height: 10 * _s),
            _btn('Withdraw', _withdraw),
          ],
        ),
      ),
    );
  }

  Widget _doneView() {
    return _centered(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 72 * _s,
            height: 72 * _s,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: Colors.white, size: 44 * _s),
          ),
          SizedBox(height: 16 * _s),
          Text('Success', style: _ts(22)),
        ],
      ),
    );
  }

  Widget _screenView() {
    if (_screen == _Screen.home) {
      return _homeView();
    }
    if (_screen == _Screen.amount) {
      return _amountView();
    }
    if (_screen == _Screen.pick) {
      return _pickView();
    }
    if (_screen == _Screen.game) {
      return _gameView();
    }
    if (_screen == _Screen.wallet) {
      return _walletView();
    }
    if (_screen == _Screen.history) {
      return _historyView();
    }
    if (_screen == _Screen.qr) {
      return _qrView();
    }
    if (_screen == _Screen.upi) {
      return _upiView();
    }
    return _doneView();
  }

  Widget _nav() {
    return Container(
      height: 56 * _s,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5E5), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _go(_run ? _Screen.game : _Screen.home),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * _s, vertical: 8 * _s),
              child: CustomPaint(
                size: Size(28 * _s, 28 * _s),
                painter: const _HomeIconPainter(),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _go(_Screen.wallet),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * _s, vertical: 8 * _s),
              child: CustomPaint(
                size: Size(28 * _s, 28 * _s),
                painter: const _WalletIconPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _popupView() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: const Color(0xBFFFFFFF),
          alignment: Alignment.center,
          child: Container(
            width: 176 * _s,
            padding: EdgeInsets.symmetric(horizontal: 16 * _s, vertical: 24 * _s),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20 * _s),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('₹${_fmt(_pend)}', style: _ts(32, color: Colors.white)),
                SizedBox(height: 16 * _s),
                _btn(
                  'Success',
                  _collect,
                  bg: Colors.white,
                  fg: Colors.black,
                  border: Colors.white,
                  height: 44,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double w = mq.size.width;
    final double h = mq.size.height - mq.padding.top - mq.padding.bottom;
    _s = math.min(w / 252, h / 448);
    final bool keyboard = mq.viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Column(
              children: <Widget>[
                Expanded(child: _screenView()),
                if (!keyboard) _nav(),
              ],
            ),
            if (_popup) _popupView(),
          ],
        ),
      ),
    );
  }
}
