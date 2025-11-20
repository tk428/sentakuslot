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
    // Material Design 3 の考え方：
    // - ColorScheme を基準に色を決める
    // - 角丸・影・余白で階層を作る
    // - useMaterial3: true で最新のコンポーネントセットを利用
    final baseColor = Colors.blue;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '意思決定ルーレット',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: baseColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
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
      options: options
          .map(
            (o) => RouletteOption(
              id: o.id,
              label: o.label,
              weight: o.weight,
            ),
          )
          .toList(),
    );
  }
}

/// ===== ホーム画面：ルーレット一覧 =====

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
    // サンプルデータ
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

      if (didDelete != true) {
        return;
      }
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
                        'ルーレットがありません。\n「＋」から追加してください。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: scheme.onBackground.withOpacity(0.7),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 16, top: 8),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final r = items[index];
                        return Material(
                          color: scheme.surfaceVariant.withOpacity(0.3),
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
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${r.options.length} 件の項目',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.onSurfaceVariant
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _toggleFavorite(r),
                                    icon: Icon(
                                      r.isFavorite
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _openEditor(roulette: r),
                                    icon: const Icon(Icons.edit),
                                  ),
                                  IconButton(
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
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

/// ===== 編集画面：項目名 + 比率 + ゴミ箱 / 下に回す・保存 =====

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
          roulette: _editing,
          onSaveRequested: (_) {
            // 編集プレビューからの保存は無視（ホーム側で管理）
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
                      color: scheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text(opt.weight.toString()),
                                IconButton(
                                  onPressed: () => _changeWeight(opt, 1),
                                  icon: const Icon(Icons.add_circle_outline),
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
                      onPressed: _openSpinPreview,
                      child: const Text('回す'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
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
  late Roulette _roulette;
  final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: 0);

  bool _isSpinning = false;
  String? _selectedLabel;
  bool _showActions = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _roulette = widget.roulette;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() async {
    if (_isSpinning) return;
    if (_roulette.options.length < 2) return;

    setState(() {
      _isSpinning = true;
      _showActions = false;
      _selectedLabel = null;
    });

    // 重み付きランダム
    final weights = <int>[];
    for (var i = 0; i < _roulette.options.length; i++) {
      final w = _roulette.options[i].weight;
      for (var j = 0; j < w; j++) {
        weights.add(i);
      }
    }
    final random = Random();
    final targetIndexInOptions = weights[random.nextInt(weights.length)];

    const int loopCount = 20;
    final base = _roulette.options.length * loopCount;
    final targetItem = base + targetIndexInOptions;

    await _controller.animateToItem(
      targetItem,
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeOutCubic,
    );

    setState(() {
      _isSpinning = false;
      _selectedLabel = _roulette.options[targetIndexInOptions].label;
      _roulette.lastUsed = DateTime.now();
      _currentIndex = targetIndexInOptions;
    });

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _showActions = true;
    });
  }

  Future<void> _handleSave() async {
    await widget.onSaveRequested(_roulette);
  }

  void _goBackToTitle() {
    Navigator.of(context).pop(_roulette);
  }

  void _openEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditRoulettePage(
          roulette: _roulette,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleText = _roulette.title.isEmpty ? 'ルーレット' : _roulette.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildTitleBubble(scheme),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _spin,
                  child: _buildSlotFrame(scheme),
                ),
              ),
            ),
            if (_showActions) _buildResultActions(scheme) else _buildSpinButton(),
          ],
        ),
      ),
    );
  }

  /// 上半分：カラフルな吹き出しタイトル
  Widget _buildTitleBubble(ColorScheme scheme) {
    final subtitle = 'タップして回す';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary,
              scheme.tertiary,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '意思決定ルーレット',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimary,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _roulette.title.isEmpty ? 'タイトル未設定' : _roulette.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimary.withOpacity(0.85),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 下半分：スロット筐体
  Widget _buildSlotFrame(ColorScheme scheme) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surfaceVariant.withOpacity(0.9),
              scheme.surface.withOpacity(0.9),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // 背景
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        scheme.inverseSurface.withOpacity(0.15),
                        scheme.surface.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
                // リール
                _buildSlotReel(scheme),
                // 中央ハイライト窓
                IgnorePointer(
                  child: Center(
                    child: Container(
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.onPrimaryContainer.withOpacity(0.15),
                          width: 1,
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
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              scheme.surface.withOpacity(0.95),
                              scheme.surface.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              scheme.surface.withOpacity(0.95),
                              scheme.surface.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 結果オーバーレイ
                _buildResultOverlay(scheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 実際に縦に回るリール部分
  Widget _buildSlotReel(ColorScheme scheme) {
    final options = _roulette.options;
    if (options.isEmpty) {
      return const Center(
        child: Text('項目がありません'),
      );
    }

    return ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: 48,
      // ★ ここでユーザー操作を完全封鎖 → ボタン / タップでのみ回る
      physics: const NeverScrollableScrollPhysics(),
      perspective: 0.0015,
      diameterRatio: 2.0,
      overAndUnderCenterOpacity: 0.25,
      onSelectedItemChanged: (index) {
        setState(() {
          _currentIndex = index % options.length;
        });
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: options.length * 1000,
        builder: (context, index) {
          final opt = options[index % options.length];
          final isCenter = (index % options.length) == _currentIndex;

          return Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 140),
              style: TextStyle(
                fontSize: isCenter ? 22 : 18,
                fontWeight:
                    isCenter ? FontWeight.w700 : FontWeight.w400,
                color: isCenter
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
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

  /// 結果ラベルのオーバーレイ
  Widget _buildResultOverlay(ColorScheme scheme) {
    if (_selectedLabel == null) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: !_showActions,
      child: Center(
        child: AnimatedScale(
          scale: _showActions ? 1.0 : 1.05,
          duration: const Duration(milliseconds: 180),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 24,
                  offset: Offset(0, 12),
                  color: Color(0x66000000),
                ),
              ],
            ),
            child: Text(
              _selectedLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpinButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _spin,
          child: Text(_isSpinning ? '回転中…' : '回す'),
        ),
      ),
    );
  }

  Widget _buildResultActions(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _spin,
                  child: const Text('もう一度回す'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _handleSave,
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _openEditor,
                  child: const Text('編集'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: _goBackToTitle,
                  child: const Text('タイトルに戻る'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
                        ? scheme.primaryContainer.withOpacity(0.6)
                        : scheme.surfaceVariant.withOpacity(0.4),
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
