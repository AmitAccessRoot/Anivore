import 'dart:async';
import 'dart:math' as math;

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

const int kSize = 4;

enum Dir { left, right, up, down }

class LineResult {
  const LineResult(this.values, this.merged, this.gained);

  final List<int> values;
  final List<bool> merged;
  final int gained;
}

LineResult slideLine(List<int> line) {
  final List<int> tiles = line.where((int v) => v != 0).toList();
  final List<int> values = <int>[];
  final List<bool> merged = <bool>[];
  int gained = 0;
  int i = 0;
  while (i < tiles.length) {
    if (i + 1 < tiles.length && tiles[i] == tiles[i + 1]) {
      final int sum = tiles[i] * 2;
      values.add(sum);
      merged.add(true);
      gained += sum;
      i += 2;
    } else {
      values.add(tiles[i]);
      merged.add(false);
      i += 1;
    }
  }
  while (values.length < kSize) {
    values.add(0);
    merged.add(false);
  }
  return LineResult(values, merged, gained);
}

List<List<int>> emptyGrid() => List<List<int>>.generate(
      kSize,
      (int _) => List<int>.filled(kSize, 0),
    );

List<List<int>> copyGrid(List<List<int>> g) =>
    g.map((List<int> row) => List<int>.from(row)).toList();

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
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final math.Random _rng = math.Random();
  List<List<int>> _grid = emptyGrid();
  List<List<int>> _stamp = emptyGrid();
  List<List<int>>? _prevGrid;
  List<List<int>>? _prevStamp;
  int _prevScore = 0;
  int _score = 0;
  int _best = 0;
  int _moveNo = 0;
  bool _over = false;
  bool _won = false;
  bool _continued = false;
  Offset _drag = Offset.zero;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _grid = emptyGrid();
    _stamp = emptyGrid();
    _prevGrid = null;
    _prevStamp = null;
    _prevScore = 0;
    _score = 0;
    _moveNo = 0;
    _over = false;
    _won = false;
    _continued = false;
    _spawn();
    _spawn();
  }

  void _newGame() {
    setState(_reset);
  }

  void _spawn() {
    final List<int> empty = <int>[];
    for (int r = 0; r < kSize; r++) {
      for (int c = 0; c < kSize; c++) {
        if (_grid[r][c] == 0) {
          empty.add(r * kSize + c);
        }
      }
    }
    if (empty.isEmpty) {
      return;
    }
    final int pick = empty[_rng.nextInt(empty.length)];
    final int r = pick ~/ kSize;
    final int c = pick % kSize;
    _grid[r][c] = _rng.nextInt(10) == 0 ? 4 : 2;
    _stamp[r][c] = _moveNo;
  }

  bool _hasTile(int v) => _grid.any((List<int> row) => row.contains(v));

  bool _canMove() {
    for (int r = 0; r < kSize; r++) {
      for (int c = 0; c < kSize; c++) {
        if (_grid[r][c] == 0) {
          return true;
        }
        if (c + 1 < kSize && _grid[r][c] == _grid[r][c + 1]) {
          return true;
        }
        if (r + 1 < kSize && _grid[r][c] == _grid[r + 1][c]) {
          return true;
        }
      }
    }
    return false;
  }

  void _move(Dir d) {
    if (_over || _won) {
      return;
    }
    final List<List<int>> g = copyGrid(_grid);
    final List<List<int>> st = copyGrid(_stamp);
    final int nextMove = _moveNo + 1;
    int gained = 0;
    bool changed = false;
    for (int i = 0; i < kSize; i++) {
      final List<List<int>> cells = coordsFor(d, i);
      final List<int> line = <int>[
        for (final List<int> p in cells) g[p[0]][p[1]],
      ];
      final LineResult res = slideLine(line);
      gained += res.gained;
      for (int k = 0; k < kSize; k++) {
        final int r = cells[k][0];
        final int c = cells[k][1];
        if (g[r][c] != res.values[k]) {
          changed = true;
        }
        g[r][c] = res.values[k];
        if (res.merged[k]) {
          st[r][c] = nextMove;
        }
      }
    }
    if (!changed) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _prevGrid = copyGrid(_grid);
      _prevStamp = copyGrid(_stamp);
      _prevScore = _score;
      _grid = g;
      _stamp = st;
      _moveNo = nextMove;
      _score += gained;
      if (_score > _best) {
        _best = _score;
      }
      _spawn();
      if (!_continued && _hasTile(2048)) {
        _won = true;
      }
      if (!_canMove()) {
        _over = true;
      }
    });
  }

  void _undo() {
    final List<List<int>>? g = _prevGrid;
    final List<List<int>>? s = _prevStamp;
    if (g == null || s == null) {
      return;
    }
    setState(() {
      _grid = copyGrid(g);
      _stamp = copyGrid(s);
      _score = _prevScore;
      _prevGrid = null;
      _prevStamp = null;
      _over = false;
      _won = false;
    });
  }

  void _onDragEnd() {
    final double dx = _drag.dx;
    final double dy = _drag.dy;
    if (math.max(dx.abs(), dy.abs()) < 20) {
      return;
    }
    if (dx.abs() > dy.abs()) {
      _move(dx > 0 ? Dir.right : Dir.left);
    } else {
      _move(dy > 0 ? Dir.down : Dir.up);
    }
  }

  Widget _button(String label, VoidCallback? onTap, bool dark) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFFEDEDED) : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: dark ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreBox(String label, int value, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1F1F1F) : const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 12, color: softColor(context)),
          ),
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

  Widget _tile(int r, int c, double cell, bool dark) {
    final int v = _grid[r][c];
    final BorderRadius radius = BorderRadius.circular(8);
    if (v == 0) {
      return Container(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2C2C2C) : const Color(0xFFCDC1B4),
          borderRadius: radius,
        ),
      );
    }
    final Widget body = Container(
      decoration: BoxDecoration(color: tileColor(v), borderRadius: radius),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          child: Text(
            v.toString(),
            style: TextStyle(
              fontSize: cell * 0.45,
              fontWeight: FontWeight.bold,
              color: tileTextColor(v),
            ),
          ),
        ),
      ),
    );
    if (_stamp[r][c] != _moveNo) {
      return body;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('pop-$r-$c-$_moveNo'),
      tween: Tween<double>(begin: 0.5, end: 1.0),
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
    final List<Widget> children = <Widget>[];
    for (int r = 0; r < kSize; r++) {
      for (int c = 0; c < kSize; c++) {
        children.add(
          Positioned(
            left: gap + c * (cell + gap),
            top: gap + r * (cell + gap),
            width: cell,
            height: cell,
            child: _tile(r, c, cell, dark),
          ),
        );
      }
    }
    if (_over || _won) {
      children.add(
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xCC000000) : const Color(0xCCFFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _over ? 'खेल खत्म' : 'आप जीत गए!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: mainColor(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _button(
                    _over ? 'फिर से खेलें' : 'खेलते रहें',
                    _over
                        ? _newGame
                        : () {
                            setState(() {
                              _won = false;
                              _continued = true;
                            });
                          },
                    dark,
                  ),
                ],
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
                math.min(math.min(c.maxWidth - 40, c.maxHeight - 240), 520.0),
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
                          _scoreBox('स्कोर', _score, dark),
                          const SizedBox(width: 8),
                          _scoreBox('सर्वश्रेष्ठ', _best, dark),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'स्वाइप करके टाइल मिलाइए और 2048 बनाइए।',
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
                          Expanded(child: _button('नया खेल', _newGame, dark)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _button(
                              'पीछे जाएँ',
                              _prevGrid == null ? null : _undo,
                              dark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
