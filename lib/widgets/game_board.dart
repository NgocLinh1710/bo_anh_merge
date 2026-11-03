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

  const GameBoard({
    super.key,
    required this.board,
    required this.collection,
    required this.selectedIndex,
    required this.onTileTap,
    required this.onMerge,
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
                    return GameLogic.canMerge(
                      board,
                      details.data,
                      index,
                      collection.maxLevel,
                    );
                  },
                  onAcceptWithDetails: (details) {
                    onMerge(details.data, index);
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
