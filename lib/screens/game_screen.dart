import 'package:flutter/material.dart';
import '../services/sound_service.dart';

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

  int totalCoins = 0;
  int coinProgress = 0;
  int totalPairs = 0;

  // Số sự kiện đạt cấp tối đa đã xử lý trong phiên hiện tại
  int handledMaxLevelCelebrations = 0;

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

    final results = await Future.wait([
      GameStorageService.loadGame(collectionId),
      GameStorageService.loadHighScore(collectionId),
      GameStorageService.loadTotalCoins(),
      GameStorageService.loadCoinProgress(),
      GameStorageService.loadTotalPairs(),
    ]);

    final savedGame = results[0] as GameState?;
    final savedHighScore = results[1] as int;
    final savedCoins = results[2] as int;
    final savedProgress = results[3] as int;
    final savedPairs = results[4] as int;

    if (!mounted) return;

    final loadedGame =
        savedGame ?? GameLogic.createNewGame(widget.collection.maxLevel);

    setState(() {
      gameState = loadedGame;
      highScore = savedHighScore;
      totalCoins = savedCoins;
      coinProgress = savedProgress;
      totalPairs = savedPairs;
      isLoading = false;

      handledMaxLevelCelebrations = loadedGame.maxLevelCelebrations;
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

    // Lưu số cặp đã ghép trước lượt này
    final previousPairs = gameState.pairsMerged;

    final nextState = GameLogic.merge(
      gameState,
      from,
      to,
      widget.collection.maxLevel,
    );

    if (identical(nextState, gameState)) return;

    final newlyMergedPairs = nextState.pairsMerged - previousPairs;

    setState(() {
      gameState = nextState;
      selectedIndex = null;
    });

    _saveCurrentGame();

    // Cộng xu theo tổng số cặp thực tế đã ghép
    if (newlyMergedPairs > 0) {
      _recordMergeRewards(newlyMergedPairs);
    }

    _checkMilestones();
  }

  Future<void> _recordMergeRewards(int pairs) async {
    final earnedCoins = await GameStorageService.recordMergedPairs(pairs);

    final results = await Future.wait([
      GameStorageService.loadTotalCoins(),
      GameStorageService.loadCoinProgress(),
      GameStorageService.loadTotalPairs(),
    ]);

    if (!mounted) return;

    setState(() {
      totalCoins = results[0];
      coinProgress = results[1];
      totalPairs = results[2];
    });

    if (earnedCoins > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Bạn nhận được $earnedCoins xu!'),
          backgroundColor: AppColors.butterDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _checkMilestones() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isLoading || dialogShowing) return;

      if (gameState.maxLevelCelebrations > handledMaxLevelCelebrations) {
        handledMaxLevelCelebrations = gameState.maxLevelCelebrations;

        _showMaxLevelDialog();
      } else if (gameState.isGameOver) {
        _showGameOverDialog();
      }
    });
  }

  Future<void> _showMaxLevelDialog() async {
    if (dialogShowing || !mounted) return;

    dialogShowing = true;

    // Phát nhạc chiến thắng ngẫu nhiên
    SoundService.playRandomVictorySound();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'CHÚC MỪNG! 🎉',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Bạn đã tạo được ảnh cấp độ cao nhất!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.text, fontSize: 14),
                  ),

                  const SizedBox(height: 18),

                  // Hiển thị ảnh cấp độ tối đa
                  Container(
                    width: 240,
                    height: 240,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.butterDark.withValues(alpha: 0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        widget.collection.imagePath(widget.collection.maxLevel),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.emoji_events_rounded,
                            size: 100,
                            color: AppColors.butterDark,
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            SoundService.stop();
                            Navigator.pop(dialogContext);
                            _restartGame();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.text,
                            side: const BorderSide(color: AppColors.butterDark),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text('Chơi lại'),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            SoundService.stop();
                            Navigator.pop(dialogContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.butterDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text('Tiếp tục'),
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

  // Chơi lại nhưng không xóa điểm cao nhất và số xu
  void _restartGame() {
    setState(() {
      gameState = GameLogic.createNewGame(widget.collection.maxLevel);
      selectedIndex = null;
      handledMaxLevelCelebrations = 0;
    });

    SoundService.stop();
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

  Widget _buildCoinProgressCard({bool compact = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 9 : 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.butter.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                color: Color(0xFFE5AC32),
                size: 23,
              ),
              const SizedBox(width: 7),
              const Text(
                'Xu của bạn',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$totalCoins xu',
                style: const TextStyle(
                  color: Color(0xFFD69A25),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: coinProgress / GameStorageService.pairsPerReward,
              minHeight: 9,
              backgroundColor: AppColors.butterLight,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFE5AC32),
              ),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            '$coinProgress/${GameStorageService.pairsPerReward} cặp ghép '
            '• Đủ 14 cặp nhận ${GameStorageService.coinsPerReward} xu',
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 10 : 12,
            ),
          ),
        ],
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

                _buildCoinProgressCard(),

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

  // Giao diện điện thoại thích ứng theo cả chiều rộng và chiều cao
  Widget _buildCompactLayout(double width, double height) {
    const horizontalPadding = 12.0;

    final boardSize = (width - horizontalPadding * 2)
        .clamp(180.0, 440.0)
        .toDouble();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 10,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thống kê
              Row(
                children: [
                  _statCard(
                    'Điểm',
                    '${gameState.score}',
                    Icons.star_rounded,
                    compact: true,
                  ),
                  const SizedBox(width: 7),
                  _statCard(
                    'Lượt chơi',
                    '${gameState.moves}',
                    Icons.touch_app_rounded,
                    compact: true,
                  ),
                  const SizedBox(width: 7),
                  _statCard(
                    'Cấp tối đa',
                    '${widget.collection.maxLevel}',
                    Icons.emoji_events_rounded,
                    compact: true,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Kỷ lục
              Text(
                '🏆 Kỷ lục: $highScore điểm',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 10),

              // Xu
              _buildCoinProgressCard(compact: true),

              const SizedBox(height: 12),

              // Tiêu đề
              const Text(
                'Ghép hai ảnh giống nhau!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),

              const SizedBox(height: 8),

              // Bàn chơi tự điều chỉnh kích thước
              SizedBox.square(
                dimension: boardSize,
                child: GameBoard(
                  board: gameState.board,
                  collection: widget.collection,
                  selectedIndex: selectedIndex,
                  onTileTap: _handleTileTap,
                  onMerge: _mergeTiles,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Kéo hai ảnh giống nhau hoặc chạm lần lượt '
                'hai ô để ghép.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: _restartGame,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Chơi lại từ đầu'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.butterDark),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10,
                  ),
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

                    // Màn hình rộng: bố cục hai cột
                    if (width >= 760) {
                      return _buildDesktopLayout(width, height);
                    }

                    // Tất cả màn hình điện thoại: bố cục một cột có thể cuộn
                    return _buildCompactLayout(width, height);
                  },
                ),
        ),
      ),
    );
  }
}
