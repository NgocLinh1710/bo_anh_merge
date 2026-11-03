import 'package:flutter/material.dart';

import '../main.dart';
import '../models/game_collection.dart';
import '../models/game_state.dart';
import '../services/game_storage_service.dart';
import '../utils/game_logic.dart';
import '../widgets/game_board.dart';

class GameScreen extends StatefulWidget {
  final GameCollection collection;

  const GameScreen({super.key, required this.collection});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState gameState;

  int? selectedIndex;
  int highScore = 0;

  bool dialogShowing = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    gameState = GameLogic.createNewGame(widget.collection.maxLevel);

    _loadSavedGame();
  }

  // Tải ván chơi và điểm cao nhất đã lưu
  Future<void> _loadSavedGame() async {
    final collectionId = widget.collection.id;

    final savedGame = await GameStorageService.loadGame(collectionId);
    final savedHighScore = await GameStorageService.loadHighScore(collectionId);

    if (!mounted) return;

    setState(() {
      gameState =
          savedGame ?? GameLogic.createNewGame(widget.collection.maxLevel);

      highScore = savedHighScore;
      isLoading = false;
    });

    _checkMilestones();
  }

  // Lưu trạng thái hiện tại và cập nhật điểm cao nhất
  Future<void> _saveCurrentGame() async {
    final stateToSave = gameState;
    final collectionId = widget.collection.id;

    await GameStorageService.saveGame(collectionId, stateToSave);

    final savedHighScore = await GameStorageService.loadHighScore(collectionId);

    if (!mounted) return;

    if (savedHighScore != highScore) {
      setState(() {
        highScore = savedHighScore;
      });
    }
  }

  void _handleTileTap(int index) {
    if (isLoading || gameState.isGameOver || dialogShowing) return;

    final level = gameState.board[index];

    if (level == null) {
      setState(() {
        selectedIndex = null;
      });
      return;
    }

    if (selectedIndex == null) {
      setState(() {
        selectedIndex = index;
      });
      return;
    }

    if (selectedIndex == index) {
      setState(() {
        selectedIndex = null;
      });
      return;
    }

    if (GameLogic.canMerge(
      gameState.board,
      selectedIndex!,
      index,
      widget.collection.maxLevel,
    )) {
      _mergeTiles(selectedIndex!, index);
    } else {
      setState(() {
        selectedIndex = index;
      });
    }
  }

  void _mergeTiles(int from, int to) {
    if (isLoading || gameState.isGameOver || dialogShowing) return;

    final nextState = GameLogic.merge(
      gameState,
      from,
      to,
      widget.collection.maxLevel,
    );

    if (identical(nextState, gameState)) return;

    setState(() {
      gameState = nextState;
      selectedIndex = null;
    });

    _saveCurrentGame();
    _checkMilestones();
  }

  void _checkMilestones() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isLoading || dialogShowing) return;

      final maxLevel = widget.collection.maxLevel;

      final reachedMax =
          GameLogic.containsMaxLevel(gameState.board, maxLevel) &&
          gameState.maxLevelNoticeShownFor < maxLevel;

      if (reachedMax) {
        setState(() {
          gameState = gameState.copyWith(maxLevelNoticeShownFor: maxLevel);
        });

        _saveCurrentGame();
        _showMaxLevelDialog();
      } else if (gameState.isGameOver) {
        _showGameOverDialog();
      }
    });
  }

  Future<void> _showMaxLevelDialog() async {
    if (dialogShowing || !mounted) return;

    dialogShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Chúc mừng! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Bạn đã đạt cấp độ cao nhất '
            '(${widget.collection.maxLevel})!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.text, height: 1.5),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _restartGame();
              },
              child: const Text(
                'Chơi lại',
                style: TextStyle(color: AppColors.butterDark),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.butterDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tiếp tục'),
            ),
          ],
        );
      },
    );

    dialogShowing = false;

    if (mounted && gameState.isGameOver) {
      _showGameOverDialog();
    }
  }

  Future<void> _showGameOverDialog() async {
    if (dialogShowing || !mounted) return;

    dialogShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Hết nước đi rồi!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Điểm của bạn: ${gameState.score}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.text),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _restartGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.butterDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Chơi lại'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text(
                'Về bộ sưu tập',
                style: TextStyle(color: AppColors.text),
              ),
            ),
          ],
        );
      },
    );

    dialogShowing = false;
  }

  // Chơi lại nhưng không xóa điểm cao nhất
  void _restartGame() {
    setState(() {
      gameState = GameLogic.createNewGame(widget.collection.maxLevel);
      selectedIndex = null;
    });

    _saveCurrentGame();
  }

  // Thẻ thống kê
  Widget _statCard(
    String label,
    String value,
    IconData icon, {
    bool compact = false,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 6 : 12,
          horizontal: compact ? 4 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.butterDark, size: compact ? 17 : 22),
            SizedBox(height: compact ? 2 : 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 15 : 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.butterDark, size: 23),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.text),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Giao diện rộng: thông tin bên trái, bàn chơi bên phải
  Widget _buildDesktopLayout(double width, double height) {
    const padding = 16.0;
    const spacing = 20.0;

    final availableWidth = width - padding * 2;
    final availableHeight = height - padding * 2;

    final leftWidth = availableWidth * 0.30;
    final boardAvailableWidth = availableWidth - leftWidth - spacing;

    final boardSize = [
      availableHeight,
      boardAvailableWidth,
      620.0,
    ].reduce((a, b) => a < b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(padding),
      child: Row(
        children: [
          SizedBox(
            width: leftWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Ghép hai ảnh giống nhau!',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _desktopStatCard(
                  'Điểm',
                  '${gameState.score}',
                  Icons.star_rounded,
                ),

                const SizedBox(height: 8),

                _desktopStatCard(
                  'Lượt chơi',
                  '${gameState.moves}',
                  Icons.touch_app_rounded,
                ),

                const SizedBox(height: 8),

                _desktopStatCard(
                  'Cấp tối đa',
                  '${widget.collection.maxLevel}',
                  Icons.emoji_events_rounded,
                ),

                const SizedBox(height: 14),

                Text(
                  '🏆 Kỷ lục: $highScore điểm',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Tìm và kéo hai ảnh giống nhau '
                  'hoặc chạm lần lượt hai ô để ghép.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: _restartGame,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Chơi lại từ đầu'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.butterDark),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: spacing),

          Expanded(
            child: Center(
              child: SizedBox.square(
                dimension: boardSize,
                child: GameBoard(
                  board: gameState.board,
                  collection: widget.collection,
                  selectedIndex: selectedIndex,
                  onTileTap: _handleTileTap,
                  onMerge: _mergeTiles,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Giao diện hẹp: tất cả thành phần nằm trong một cột
  Widget _buildCompactLayout(double width, double height) {
    const horizontalPadding = 12.0;
    const verticalPadding = 6.0;

    final boardSize = [
      width - horizontalPadding * 2,
      height * 0.58,
      440.0,
    ].reduce((a, b) => a < b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _statCard(
                'Điểm',
                '${gameState.score}',
                Icons.star_rounded,
                compact: true,
              ),
              const SizedBox(width: 6),
              _statCard(
                'Lượt chơi',
                '${gameState.moves}',
                Icons.touch_app_rounded,
                compact: true,
              ),
              const SizedBox(width: 6),
              _statCard(
                'Cấp tối đa',
                '${widget.collection.maxLevel}',
                Icons.emoji_events_rounded,
                compact: true,
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            '🏆 Kỷ lục: $highScore điểm',
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Ghép hai ảnh giống nhau!',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),

          const SizedBox(height: 5),

          Expanded(
            child: Center(
              child: SizedBox.square(
                dimension: boardSize,
                child: GameBoard(
                  board: gameState.board,
                  collection: widget.collection,
                  selectedIndex: selectedIndex,
                  onTileTap: _handleTileTap,
                  onMerge: _mergeTiles,
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Kéo hai ảnh giống nhau hoặc chạm lần lượt hai ô để ghép.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.text, fontSize: 11),
          ),

          const SizedBox(height: 4),

          OutlinedButton.icon(
            onPressed: _restartGame,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Chơi lại từ đầu'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.butterDark),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  // Giao diện điện thoại khi màn hình quá thấp
  Widget _buildMobileScrollLayout(double width) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Row(
                children: [
                  _statCard(
                    'Điểm',
                    '${gameState.score}',
                    Icons.star_rounded,
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                  _statCard(
                    'Lượt chơi',
                    '${gameState.moves}',
                    Icons.touch_app_rounded,
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                  _statCard(
                    'Cấp tối đa',
                    '${widget.collection.maxLevel}',
                    Icons.emoji_events_rounded,
                    compact: true,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                '🏆 Kỷ lục: $highScore điểm',
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Ghép hai ảnh giống nhau!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),

              const SizedBox(height: 12),

              GameBoard(
                board: gameState.board,
                collection: widget.collection,
                selectedIndex: selectedIndex,
                onTileTap: _handleTileTap,
                onMerge: _mergeTiles,
              ),

              const SizedBox(height: 14),

              const Text(
                'Tìm và kéo hai ảnh giống nhau hoặc '
                'chạm lần lượt hai ô để ghép.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _restartGame,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Chơi lại từ đầu'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.butterDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.collection.name,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Chơi lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: isLoading ? null : _restartGame,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.cream, AppColors.butterLight, Color(0xFFF0E9FC)],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.butterDark),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;

                    // Màn hình đủ rộng: bố cục hai cột
                    if (width >= 760) {
                      return _buildDesktopLayout(width, height);
                    }

                    // Màn hình hẹp nhưng đủ chiều cao: vẫn hiển thị toàn bộ game, không cuộn
                    if (height >= 400) {
                      return _buildCompactLayout(width, height);
                    }

                    // Màn hình quá thấp mới dùng cuộn
                    return _buildMobileScrollLayout(width);
                  },
                ),
        ),
      ),
    );
  }
}
