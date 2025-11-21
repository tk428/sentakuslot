import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DecisionRouletteApp());
}

class DecisionRouletteApp extends StatelessWidget {
  const DecisionRouletteApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF27C6D1); // 背景と合うティール系

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '意思決定ルーレット',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7FB),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          bodyMedium: TextStyle(
            fontSize: 15,
            letterSpacing: 0.1,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// ===== モデル =====

class RouletteOption {
  RouletteOption({
    required this.id,
    required this.label,
    required this.weight,
  });

  final String id;
  String label; // 1〜30文字
  int weight; // 1〜10

  RouletteOption clone() =>
      RouletteOption(id: id, label: label, weight: weight);
}

class Roulette {
  Roulette({
    required this.id,
    required this.title,
    this.isFavorite = false,
    DateTime? lastUsed,
    List<RouletteOption>? options,
  })  : lastUsed = lastUsed ?? DateTime.now(),
        options = options ?? [];

  final String id;
  String title;
  bool isFavorite;
  DateTime lastUsed;
  List<RouletteOption> options;

  bool get hasEnoughOptions => options.length >= 2;

  Roulette clone() {
    return Roulette(
      id: id,
      title: title,
      isFavorite: isFavorite,
      lastUsed: lastUsed,
      options: options.map((o) => o.clone()).toList(),
    );
  }
}

/// ===== ホーム画面 =====

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int maxSaved = 10;

  final List<Roulette> _roulettes = [];

  @override
  void initState() {
    super.initState();
    // サンプル
    _roulettes.addAll([
      Roulette(
        id: _genId(),
        title: 'アリ or ナシ？',
        isFavorite: true,
        options: [
          RouletteOption(id: _genId(), label: 'アリ', weight: 7),
          RouletteOption(id: _genId(), label: 'ナシ', weight: 3),
        ],
      ),
      Roulette(
        id: _genId(),
        title: '何食べる？',
        options: [
          RouletteOption(id: _genId(), label: 'ラーメン', weight: 3),
          RouletteOption(id: _genId(), label: 'カレー', weight: 3),
          RouletteOption(id: _genId(), label: 'パスタ', weight: 4),
        ],
      ),
    ]);
  }

  static String _genId() => DateTime.now().microsecondsSinceEpoch.toString();

  List<Roulette> get _sortedRoulettes {
    final fav = _roulettes.where((r) => r.isFavorite).toList()
      ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    final others = _roulettes.where((r) => !r.isFavorite).toList()
      ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return [...fav, ...others];
  }

  Future<void> _openSpin(Roulette roulette) async {
    final updated = await Navigator.of(context).push<Roulette>(
      MaterialPageRoute(
        builder: (_) => SpinPage(
          roulette: roulette.clone(),
          onSaveRequested: (r) => _handleSaveFromResult(context, r),
        ),
      ),
    );

    if (updated != null) {
      final index = _roulettes.indexWhere((r) => r.id == updated.id);
      if (index != -1) {
        setState(() {
          _roulettes[index] = updated;
          _roulettes[index].lastUsed = DateTime.now();
        });
      }
    }
  }

  Future<void> _handleSaveFromResult(
      BuildContext ctx, Roulette roulette) async {
    final existsIndex = _roulettes.indexWhere((r) => r.id == roulette.id);

    if (existsIndex != -1) {
      setState(() {
        _roulettes[existsIndex] = roulette;
        _roulettes[existsIndex].lastUsed = DateTime.now();
      });
      return;
    }

    if (_roulettes.length >= maxSaved) {
      final didDelete = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CleanupPage(
            roulettes: _sortedRoulettes,
            onDeleteConfirmed: (idsToDelete) {
              setState(() {
                _roulettes.removeWhere(
                  (r) => idsToDelete.contains(r.id),
                );
              });
            },
          ),
        ),
      );

      if (didDelete != true) return;
    }

    setState(() {
      _roulettes.add(roulette);
    });
  }

  Future<void> _openEditor({Roulette? roulette}) async {
    final result = await Navigator.of(context).push<Roulette>(
      MaterialPageRoute(
        builder: (_) => EditRoulettePage(
          roulette: roulette?.clone(),
        ),
      ),
    );

    if (result == null) return;

    final existsIndex = _roulettes.indexWhere((r) => r.id == result.id);

    if (existsIndex != -1) {
      setState(() {
        _roulettes[existsIndex] = result;
      });
    } else {
      if (_roulettes.length >= maxSaved) {
        final didDelete = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CleanupPage(
              roulettes: _sortedRoulettes,
              onDeleteConfirmed: (idsToDelete) {
                setState(() {
                  _roulettes.removeWhere(
                    (r) => idsToDelete.contains(r.id),
                  );
                });
              },
            ),
          ),
        );
        if (didDelete != true) return;
      }
      setState(() {
        _roulettes.add(result);
      });
    }
  }

  void _toggleFavorite(Roulette r) {
    setState(() {
      r.isFavorite = !r.isFavorite;
    });
  }

  void _deleteRoulette(Roulette r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('「${r.title}」を削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _roulettes.removeWhere((x) => x.id == r.id);
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _sortedRoulettes;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('意思決定ルーレット'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'ルーレットがありません。\n「新しいルーレット」から追加してください。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: scheme.onBackground.withOpacity(0.7),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final r = items[index];
                        return Material(
                          color: scheme.surface,
                          elevation: 1,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openSpin(r),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${r.options.length} 件の項目',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'お気に入り',
                                    onPressed: () => _toggleFavorite(r),
                                    icon: Icon(
                                      r.isFavorite
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber[700],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '編集',
                                    onPressed: () =>
                                        _openEditor(roulette: r),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: '削除',
                                    onPressed: () => _deleteRoulette(r),
                                    icon: const Icon(Icons.delete_outline),
                                    color: scheme.error,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    _openEditor(
                      roulette: Roulette(
                        id: _genId(),
                        title: '',
                        options: [],
                      ),
                    );
                  },
                  label: const Text('新しいルーレット'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== 編集画面 =====

class EditRoulettePage extends StatefulWidget {
  const EditRoulettePage({super.key, this.roulette});

  final Roulette? roulette;

  @override
  State<EditRoulettePage> createState() => _EditRoulettePageState();
}

class _EditRoulettePageState extends State<EditRoulettePage> {
  late Roulette _editing;

  @override
  void initState() {
    super.initState();
    _editing = widget.roulette ??
        Roulette(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: '',
          options: [],
        );
  }

  void _addOption() {
    setState(() {
      _editing.options.add(
        RouletteOption(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          label: '',
          weight: 5,
        ),
      );
    });
  }

  void _removeOption(RouletteOption opt) {
    setState(() {
      _editing.options.removeWhere((o) => o.id == opt.id);
    });
  }

  void _changeWeight(RouletteOption opt, int delta) {
    setState(() {
      opt.weight = (opt.weight + delta).clamp(1, 10);
    });
  }

  void _saveAndClose() {
    if (_editing.title.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('タイトルが空です'),
          content: Text('ルーレットのタイトルを入力してください。'),
        ),
      );
      return;
    }
    if (_editing.options.length < 2 ||
        _editing.options.any((o) => o.label.trim().isEmpty)) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('項目が足りません'),
          content: Text('2つ以上の有効な項目を設定してください。'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(_editing);
  }

  void _openSpinPreview() {
    if (_editing.options.length < 2 ||
        _editing.options.any((o) => o.label.trim().isEmpty)) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('項目が足りません'),
          content: Text('2つ以上の有効な項目を設定してから回してください。'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpinPage(
          roulette: _editing.clone(),
          onSaveRequested: (_) async {
            // プレビューからホーム保存はここでは何もしない
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _editing.options;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ルーレット編集'),
        actions: [
          TextButton(
            onPressed: _saveAndClose,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'タイトル（例：アリ or ナシ？）',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: _editing.title),
                onChanged: (v) => _editing.title = v,
                maxLength: 30,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(30),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: options.length + 1,
                itemBuilder: (context, index) {
                  if (index == options.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.add),
                        onPressed: _addOption,
                        label: const Text('項目を追加'),
                      ),
                    );
                  }

                  final opt = options[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 6),
                    child: Material(
                      color: scheme.surface,
                      elevation: 1,
                      shadowColor: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  hintText: '項目名',
                                  border: InputBorder.none,
                                ),
                                controller:
                                    TextEditingController(text: opt.label),
                                onChanged: (v) => opt.label = v,
                                maxLength: 30,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(30),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => _changeWeight(opt, -1),
                                  icon: const Icon(Icons.remove_circle),
                                  color: Colors.orange[700],
                                ),
                                Text(opt.weight.toString()),
                                IconButton(
                                  onPressed: () => _changeWeight(opt, 1),
                                  icon: const Icon(Icons.add_circle),
                                  color: Colors.orange[700],
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => _removeOption(opt),
                              icon: const Icon(Icons.delete_outline),
                              color: scheme.error,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _openSpinPreview,
                      child: const Text('回す'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _saveAndClose,
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== スロット画面 =====

class SpinPage extends StatefulWidget {
  const SpinPage({
    super.key,
    required this.roulette,
    required this.onSaveRequested,
  });

  final Roulette roulette;
  final Future<void> Function(Roulette) onSaveRequested;

  @override
  State<SpinPage> createState() => _SpinPageState();
}

class _SpinPageState extends State<SpinPage> {
  static const int _maxLoops = 80;

  late Roulette _roulette;
  final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: 0);

  bool _isSpinning = false;
  bool _waitingStopTap = false;
  String? _selectedLabel;
  bool _showActions = false;
  int _currentIndex = 0;

  Timer? _spinTimer;
  int _pendingTargetIndex = 0;
  int _targetItem = 0;
  int _currentItemRaw = 0;

  @override
  void initState() {
    super.initState();
    _roulette = widget.roulette;
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_isSpinning || _roulette.options.length < 2) return;

    final options = _roulette.options;

    // 重み付きランダムでターゲット決定
    final weights = <int>[];
    for (var i = 0; i < options.length; i++) {
      for (var j = 0; j < options[i].weight; j++) {
        weights.add(i);
      }
    }
    final random = Random();
    _pendingTargetIndex = weights[random.nextInt(weights.length)];

    // かなり先のインデックスをゴールにしておく
    final base = options.length * (_maxLoops - 5);
    _targetItem = base + _pendingTargetIndex;

    _spinTimer?.cancel();
    _currentItemRaw =
        _controller.hasClients ? _controller.selectedItem : 0;

    setState(() {
      _isSpinning = true;
      _waitingStopTap = true;
      _selectedLabel = null;
      _showActions = false;
    });

    // 高速にジャンプして「回っている感」を出す
    _spinTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!_isSpinning) {
        timer.cancel();
        return;
      }
      final maxItem = options.length * _maxLoops;
      _currentItemRaw = (_currentItemRaw + 1) % maxItem;
      _controller.jumpToItem(_currentItemRaw);
    });
  }

  Future<void> _stopByTap() async {
    if (!_isSpinning || !_waitingStopTap) return;

    final options = _roulette.options;
    _waitingStopTap = false;
    _spinTimer?.cancel();

    // ゴールへ向かって減速しながら止まる
    await _controller.animateToItem(
      _targetItem,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
    );

    setState(() {
      _isSpinning = false;
      _selectedLabel = options[_pendingTargetIndex].label;
      _roulette.lastUsed = DateTime.now();
      _currentIndex = _pendingTargetIndex;
    });

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _showActions = true;
    });
  }

  void _handleSlotTap() {
    if (!_isSpinning && !_waitingStopTap && !_showActions) {
      // 何もしていない状態 → 回し始める
      _spin();
    } else if (_isSpinning && _waitingStopTap) {
      // 回転中 → TAP で停止
      _stopByTap();
    }
  }

  Future<void> _handleSave() async {
    await widget.onSaveRequested(_roulette);
  }

  void _goBackToTitle() {
    Navigator.of(context).pop(_roulette);
  }

  Future<void> _openEditor() async {
    final edited = await Navigator.of(context).push<Roulette>(
      MaterialPageRoute(
        builder: (_) => EditRoulettePage(
          roulette: _roulette.clone(),
        ),
      ),
    );
    if (edited != null) {
      setState(() {
        _roulette = edited;
        _selectedLabel = null;
        _showActions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // AppBar はなし（上の白いバーを消す）
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                'assets/7898C408-6A13-4004-80C3-E1BCC6F6D99D.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildTitleBubble(),
              const SizedBox(height: 12),
              Expanded(
                flex: 5,
                child: Center(
                  child: GestureDetector(
                    onTap: _handleSlotTap,
                    child: _buildSlotFrame(scheme),
                  ),
                ),
              ),
              if (_showActions)
                _buildResultActions(scheme)
              else
                _buildSpinButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// フラット黄色吹き出し（尻尾は下向き三角）
  Widget _buildTitleBubble() {
    const borderColor = Color(0xFFA86A1A);
    const bubbleColor = Color(0xFFFFF176);

    final titleText =
        _roulette.title.isEmpty ? 'タイトル未設定' : _roulette.title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: borderColor,
                width: 3,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55212121),
                  blurRadius: 16,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '意思決定ルーレット',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 0.3,
                    color: Colors.brown[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  titleText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'タップして回して、TAP! で止める',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.brown[700],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: -14,
            left: 0,
            right: 0,
            child: Center(
              child: CustomPaint(
                size: const Size(26, 14),
                painter: _BubbleTailPainter(
                  fillColor: bubbleColor,
                  borderColor: borderColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// スロット筐体（吹き出しと同じくらいの横幅）
  Widget _buildSlotFrame(ColorScheme scheme) {
    const borderColor = Color(0xFFA86A1A);
    const innerBgTop = Color(0xFFFFF9E5);
    const innerBgBottom = Color(0xFFFFE0B2);

    final width = MediaQuery.of(context).size.width * 0.9;

    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7EA),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: borderColor,
              width: 4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55212121),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [innerBgTop, innerBgBottom],
                      ),
                    ),
                  ),
                  _buildSlotReel(scheme),
                  // 中央の帯
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        height: 54,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD489),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: borderColor.withOpacity(0.7),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 上下フェード
                  IgnorePointer(
                    child: Column(
                      children: [
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                innerBgTop.withOpacity(0.8),
                                innerBgTop.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                innerBgBottom.withOpacity(0.8),
                                innerBgBottom.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // TAP! オーバーレイ
                  if (_isSpinning && _waitingStopTap) _buildTapOverlay(),
                  // 結果ポップ
                  _buildResultOverlay(scheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 実際のリール（上→下へのスクロール＋濃い文字色）
  Widget _buildSlotReel(ColorScheme scheme) {
    final options = _roulette.options;
    if (options.isEmpty) {
      return const Center(
        child: Text('項目がありません'),
      );
    }

    return ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: 52,
      physics: const NeverScrollableScrollPhysics(),
      perspective: 0.0015,
      diameterRatio: 2.0,
      overAndUnderCenterOpacity: 0.6,
      onSelectedItemChanged: (index) {
        setState(() {
          _currentIndex = index % options.length;
        });
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: options.length * _maxLoops,
        builder: (context, index) {
          final opt = options[index % options.length];
          final isCenter = (index % options.length) == _currentIndex;

          return Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 120),
              style: TextStyle(
                fontSize: isCenter ? 22 : 18,
                fontWeight:
                    isCenter ? FontWeight.w700 : FontWeight.w400,
                color: const Color(0xFF5B3B0F),
              ),
              child: Text(
                opt.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }

  /// TAP! 表示
  Widget _buildTapOverlay() {
    return IgnorePointer(
      ignoring: false,
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF00897B),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Text(
            'TAP!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// 結果ポップ
  Widget _buildResultOverlay(ColorScheme scheme) {
    if (_selectedLabel == null) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: true,
      child: Center(
        child: AnimatedScale(
          scale: _showActions ? 1.05 : 0.6,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _showActions ? 1 : 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF8),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 24,
                    offset: Offset(0, 14),
                    color: Color(0x66000000),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFA86A1A),
                  width: 2,
                ),
              ),
              child: Text(
                _selectedLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFF5B3B0F),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpinButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: const StadiumBorder(),
            backgroundColor: const Color(0xFF00897B),
          ),
          onPressed: _spin,
          child: Text(_isSpinning ? '回転中…' : '回す'),
        ),
      ),
    );
  }

  /// 結果後のボタン配置
  Widget _buildResultActions(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // もう一度回す（横幅いっぱい）
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
                backgroundColor: const Color(0xFF00897B),
              ),
              onPressed: () {
                setState(() {
                  _selectedLabel = null;
                  _showActions = false;
                });
                _spin();
              },
              child: const Text('もう一度回す'),
            ),
          ),
          const SizedBox(height: 8),
          // 保存 ＋ 編集
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                    backgroundColor: const Color(0xFFFFA000),
                    foregroundColor: Colors.brown[900],
                  ),
                  onPressed: _handleSave,
                  child: const Text('保存'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                    side: const BorderSide(
                      color: Color(0xFF00897B),
                      width: 2,
                    ),
                    backgroundColor: Colors.white.withOpacity(0.9),
                    foregroundColor: const Color(0xFF00897B),
                  ),
                  onPressed: _openEditor,
                  child: const Text('編集'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // タイトルに戻る
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
                foregroundColor: Colors.brown[900],
                backgroundColor: Colors.white.withOpacity(0.8),
              ),
              onPressed: _goBackToTitle,
              child: const Text('タイトルに戻る'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 吹き出しの三角しっぽ
class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({
    required this.fillColor,
    required this.borderColor,
  });

  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w / 2, h) // 下
      ..lineTo(0, 0)
      ..lineTo(w, 0)
      ..close();

    final paintFill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final paintStroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ===== 保存上限時の削除画面 =====

class CleanupPage extends StatefulWidget {
  const CleanupPage({
    super.key,
    required this.roulettes,
    required this.onDeleteConfirmed,
  });

  final List<Roulette> roulettes;
  final void Function(List<String> idsToDelete) onDeleteConfirmed;

  @override
  State<CleanupPage> createState() => _CleanupPageState();
}

class _CleanupPageState extends State<CleanupPage> {
  final Set<String> _selectedIds = {};

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _handleDelete() async {
    if (_selectedIds.isEmpty) {
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('何も削除されません'),
          content: const Text('保存されませんがよろしいですか？'),
          actions: [
            TextButton(
              child: const Text('いいえ'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style:
                  TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('はい'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (result == true) {
        Navigator.of(context).pop(false);
      }
      return;
    }

    widget.onDeleteConfirmed(_selectedIds.toList());
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('削除するルーレットを選択'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '保存上限に達しました。\n削除したいルーレットにチェックを入れてください。',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: widget.roulettes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final r = widget.roulettes[index];
                  final selected = _selectedIds.contains(r.id);
                  return Material(
                    color: selected
                        ? scheme.primaryContainer.withOpacity(0.8)
                        : scheme.surface,
                    elevation: selected ? 2 : 1,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _toggle(r.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                r.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 17),
                              ),
                            ),
                            Text(
                              '${r.options.length} 件',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _handleDelete,
                  child: const Text('削除して終了'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
