import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Curves; // ← Curves 用
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DecisionRouletteApp());
}

class DecisionRouletteApp extends StatelessWidget {
  const DecisionRouletteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
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
      CupertinoPageRoute(
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
        CupertinoPageRoute(
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
      CupertinoPageRoute(
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
          CupertinoPageRoute(
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
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('削除しますか？'),
        content: Text('「${r.title}」を削除します。'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _roulettes.removeWhere((x) => x.id == r.id);
              });
            },
            child: const Text('削除'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _sortedRoulettes;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('意思決定ルーレット'),
      ),
      child: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'ルーレットがありません。\n「＋」から追加してください。',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Container(
                        height: 0.5,
                        color: CupertinoColors.systemGrey4,
                      ),
                      itemBuilder: (context, index) {
                        final r = items[index];
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          onPressed: () => _openSpin(r),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              if (r.isFavorite)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Icon(
                                    CupertinoIcons.star_fill,
                                    size: 18,
                                    color: CupertinoColors.systemYellow,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _toggleFavorite(r),
                                child: Icon(
                                  r.isFavorite
                                      ? CupertinoIcons.star_fill
                                      : CupertinoIcons.star,
                                  size: 22,
                                  color: CupertinoColors.systemYellow,
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _openEditor(roulette: r),
                                child: const Icon(
                                  CupertinoIcons.pencil,
                                  size: 22,
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _deleteRoulette(r),
                                child: const Icon(
                                  CupertinoIcons.delete,
                                  size: 22,
                                  color: CupertinoColors.systemRed,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () {
                    _openEditor(
                      roulette: Roulette(
                        id: _genId(),
                        title: '',
                        options: [],
                      ),
                    );
                  },
                  child: const Text('＋ 新しいルーレット'),
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
/// （ここから下は、あなたが貼ってくれた EditRoulettePage / SpinPage / CleanupPage をそのまま使ってOK）
/// もしこのあともエラーが出る場合は、ログの「一番最初の赤いエラー行」
/// （`lib/main.dart:◯:◯` の行）を見れば、どの行が原因かが分かる。
///
/// ひとまず今は main.dart の頭〜HomePage までだけ貼り替えてもらえれば十分。
/// 編集画面：項目名 + 比率 + ゴミ箱 / 下に回す・保存

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
      showCupertinoDialog(
        context: context,
        builder: (_) => const CupertinoAlertDialog(
          title: Text('タイトルが空です'),
          content: Text('ルーレットのタイトルを入力してください。'),
        ),
      );
      return;
    }
    if (_editing.options.length < 2 ||
        _editing.options.any((o) => o.label.trim().isEmpty)) {
      showCupertinoDialog(
        context: context,
        builder: (_) => const CupertinoAlertDialog(
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
      showCupertinoDialog(
        context: context,
        builder: (_) => const CupertinoAlertDialog(
          title: Text('項目が足りません'),
          content: Text('2つ以上の有効な項目を設定してから回してください。'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => SpinPage(
          roulette: _editing,
          onSaveRequested: (_) async {
					  // 編集プレビューからの保存は無視（ホーム側で管理）
					  return;
					},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _editing.options;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('ルーレット編集'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saveAndClose,
          child: const Text('保存'),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: CupertinoTextField(
                placeholder: 'タイトル（例：アリ or ナシ？）',
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
                itemCount: options.length + 1,
                itemBuilder: (context, index) {
                  if (index == options.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8),
                      child: CupertinoButton(
                        onPressed: _addOption,
                        child: const Text('＋ 項目を追加'),
                      ),
                    );
                  }

                  final opt = options[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            placeholder: '項目名',
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
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _changeWeight(opt, -1),
                              child: const Icon(
                                CupertinoIcons.minus_circle,
                                size: 22,
                              ),
                            ),
                            Text(
                              opt.weight.toString(),
                              style: const TextStyle(fontSize: 16),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _changeWeight(opt, 1),
                              child: const Icon(
                                CupertinoIcons.plus_circle,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _removeOption(opt),
                          child: const Icon(
                            CupertinoIcons.delete,
                            color: CupertinoColors.systemRed,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      onPressed: _openSpinPreview,
                      child: const Text('回す'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton.filled(
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

/// スロット画面

/// スロット画面（Apple公式っぽいデザイン版）

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

  // 中央行を太字にするためのインデックス
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

    // ある程度ぐるぐる回ってから止まるように大きいインデックスに飛ばす
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

    // 1秒後にボタン表示
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
      CupertinoPageRoute(
        builder: (_) => EditRoulettePage(
          roulette: _roulette,
        ),
      ),
    );
  }

  // ===== UI 部分 =====

  @override
  Widget build(BuildContext context) {
    final titleText = _roulette.title.isEmpty ? 'ルーレット' : _roulette.title;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(titleText),
        backgroundColor:
            CupertinoColors.systemBackground.withOpacity(0.9),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _roulette.title.isEmpty ? ' ' : _roulette.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'タップして回す',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // スロット筐体
            Expanded(
              child: Center(
                child: _buildSlotFrame(),
              ),
            ),
            if (_showActions)
              _buildResultActions()
            else
              _buildSpinButton(),
          ],
        ),
      ),
    );
  }

  /// スロット筐体全体（フレーム＋リール窓）
  Widget _buildSlotFrame() {
    return AspectRatio(
      aspectRatio: 3 / 4, // 縦長気味の筐体
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.white,
              CupertinoColors.systemGrey6,
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // リール背景
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        CupertinoColors.black.withOpacity(0.06),
                        CupertinoColors.black.withOpacity(0.02),
                      ],
                    ),
                  ),
                ),
                // リール（ListWheelScrollView）
                _buildSlotReel(),
                // 中央の窓（選択行を示す帯）
                IgnorePointer(
                  child: Center(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground
                            .withOpacity(0.90),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoColors.separator,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                // 上下の影（フェード）
                IgnorePointer(
                  child: Column(
                    children: [
                      Container(
                        height: 44,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xAAFFFFFF),
                              Color(0x00FFFFFF),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 44,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Color(0xAAFFFFFF),
                              Color(0x00FFFFFF),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 結果ラベルのポップアップ
                _buildResultOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 縦方向のリール（古典的スロットの「回転部分」）
  Widget _buildSlotReel() {
    final options = _roulette.options;
    if (options.isEmpty) {
      return const Center(
        child: Text('項目がありません'),
      );
    }

    return ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: 44,
      physics: _isSpinning
          ? const NeverScrollableScrollPhysics()
          : const FixedExtentScrollPhysics(),
      perspective: 0.0015, // ほぼ平面に近い見た目 → 縦スロットっぽい
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
              duration: const Duration(milliseconds: 120),
              style: TextStyle(
                fontSize: isCenter ? 22 : 18,
                fontWeight:
                    isCenter ? FontWeight.w600 : FontWeight.w400,
                color: isCenter
                    ? CupertinoColors.label
                    : CupertinoColors.secondaryLabel,
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

  /// 結果のオーバーレイ（中央にふわっと）
  Widget _buildResultOverlay() {
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
              color: CupertinoColors.systemBackground.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 20,
                  offset: Offset(0, 10),
                  color: Color(0x33000000),
                ),
              ],
            ),
            child: Text(
              _selectedLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// スピン中 or まだ結果が出ていないときのボタン
  Widget _buildSpinButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: _spin,
          child: Text(_isSpinning ? '回転中…' : '回す'),
        ),
      ),
    );
  }

  /// 結果表示後のアクションボタン群
  Widget _buildResultActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  onPressed: _spin,
                  child: const Text('もう一度回す'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoButton.filled(
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
                child: CupertinoButton(
                  onPressed: _openEditor,
                  child: const Text('編集'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoButton(
                  onPressed: _goBackToTitle,
                  child: const Text('タイトルに戻る'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
/// 保存上限時の削除画面

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
      final result = await showCupertinoDialog<bool>(
        context: context,
        builder: (_) => const CupertinoAlertDialog(
          title: Text('何も削除されません'),
          content: Text('保存されませんがよろしいですか？'),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: Text('はい'),
              // true = 削除せず終了
            ),
            CupertinoDialogAction(
              child: Text('いいえ'),
            ),
          ],
        ),
      );

      if (result == true) {
        Navigator.of(context).pop(false); // didDelete = false
      }
      return;
    }

    widget.onDeleteConfirmed(_selectedIds.toList());
    Navigator.of(context).pop(true); // didDelete = true
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('削除するルーレットを選択'),
      ),
      child: SafeArea(
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
                itemCount: widget.roulettes.length,
                separatorBuilder: (_, __) =>
                    Container(height: 0.5, color: CupertinoColors.systemGrey4),
                itemBuilder: (context, index) {
                  final r = widget.roulettes[index];
                  final selected = _selectedIds.contains(r.id);
                  return CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    onPressed: () => _toggle(r.id),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.circle,
                          color: selected
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.inactiveGray,
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
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
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
