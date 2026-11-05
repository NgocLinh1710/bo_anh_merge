import 'package:flutter/material.dart';

import '../main.dart';
import '../models/game_collection.dart';
import '../utils/game_logic.dart';
import 'image_tile.dart';

class GameBoard extends StatelessWidget {
  final List<int?> board;
  final GameCollection collection;
  final int? selectedIndex;

  final Function(int) onTileTap;
  final Function(int, int) onMerge;

  // Được gọi khi kéo ảnh khác cấp vào một ảnh khác
  final VoidCallback? onInvalidMergeAttempt;

  const GameBoard({
    super.key,
    required this.board,
    required this.collection,
    required this.selectedIndex,
    required this.onTileTap,
    required this.onMerge,
    this.onInvalidMergeAttempt,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.butterLight.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.butterDark.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: GameLogic.boardCapacity,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: GameLogic.boardSize,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            final level = board[index];

            return LayoutBuilder(
              builder: (context, constraints) {
                final tileSize = constraints.maxWidth;

                final tile = ImageTile(
                  level: level,
                  collection: collection,
                  selected: selectedIndex == index,
                  onTap: () => onTileTap(index),
                );

                return DragTarget<int>(
                  onWillAcceptWithDetails: (details) {
                    final from = details.data;

                    if (from < 0 || from >= board.length || from == index) {
                      return false;
                    }

                    return board[from] != null && board[index] != null;
                  },

                  onAcceptWithDetails: (details) {
                    final from = details.data;

                    if (from < 0 || from >= board.length || from == index) {
                      return;
                    }

                    final isValidMerge = GameLogic.canMerge(
                      board,
                      from,
                      index,
                      collection.maxLevel,
                    );

                    if (isValidMerge) {
                      // Ghép đúng một cặp ảnh
                      onMerge(from, index);
                      return;
                    }

                    final sourceLevel = board[from];
                    final targetLevel = board[index];

                    // Trừ thời gian khi hai ảnh khác cấp
                    if (sourceLevel != null &&
                        targetLevel != null &&
                        sourceLevel != targetLevel) {
                      onInvalidMergeAttempt?.call();
                    }
                  },

                  builder: (context, candidateData, rejectedData) {
                    final isTarget = candidateData.isNotEmpty;

                    if (level == null) {
                      return tile;
                    }

                    return Draggable<int>(
                      data: index,
                      maxSimultaneousDrags: 1,

                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox.square(
                          dimension: tileSize,
                          child: Opacity(
                            opacity: 0.85,
                            child: ImageTile(
                              level: level,
                              collection: collection,
                            ),
                          ),
                        ),
                      ),

                      childWhenDragging: Opacity(opacity: 0.25, child: tile),

                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: isTarget
                              ? Border.all(
                                  color: AppColors.butterDark,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: tile,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
