import 'package:flutter/material.dart';

import '../main.dart';
import '../models/collection_achievement.dart';
import '../models/game_state.dart';

class ChallengePanel extends StatelessWidget {
  final CollectionAchievement achievement;
  final GameState state;
  final int target;
  final bool choosingRescue;
  final bool canRescue;
  final VoidCallback onRescue;
  final VoidCallback onCancel;

  const ChallengePanel({
    super.key,
    required this.achievement,
    required this.state,
    required this.target,
    required this.choosingRescue,
    required this.canRescue,
    required this.onRescue,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mục tiêu & huy hiệu',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.firstWinMoves != null
                ? 'Ảnh cuối sau ${state.firstWinMoves} lượt ghép'
                : 'Tới ảnh cuối trong $target lượt ghép • Hiện tại: ${state.moves}',
            style: const TextStyle(fontSize: 12, color: AppColors.text),
          ),
          const SizedBox(height: 4),
          if (state.firstWinMoves == null && state.moves > target)
            const Text(
              'Đã qua mốc Nhanh tay. Hãy thử mục tiêu Tự lực hoặc kỷ lục cá nhân.',
              style: TextStyle(fontSize: 12, color: AppColors.text),
            ),
          Text(
            achievement.bestMoves == null
                ? 'Hoàn thành ván để lập kỷ lục số lượt đầu tiên.'
                : 'Kỷ lục: ${achievement.bestMoves} lượt • Ít hơn là tốt hơn',
            style: const TextStyle(fontSize: 12, color: AppColors.text),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _badge('Nhanh tay ≤ $target lượt', achievement.speedWinner),
              _badge('Tự lực: không đổi ô', achievement.cleanWinner),
              _badge('Phá kỷ lục số lượt', achievement.recordBreaker),
            ],
          ),
          const SizedBox(height: 6),
          if (choosingRescue) ...[
            const Text(
              'Chạm ô muốn đổi. Ảnh mới sẽ tạo một cặp ghép được.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            TextButton(onPressed: onCancel, child: const Text('Hủy chọn ô')),
          ] else
            OutlinedButton.icon(
              onPressed: canRescue ? onRescue : null,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: Text(
                state.rescueUsed
                    ? 'Đã dùng lượt đổi ô'
                    : 'Đổi 1 ô • Còn 1 lượt',
              ),
            ),
          const Text(
            'Đổi ô miễn phí, không cộng điểm hoặc xu. Huy hiệu được giữ qua các ván.',
            style: TextStyle(fontSize: 11, color: AppColors.text),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, bool earned) => Chip(
    avatar: Icon(
      earned ? Icons.verified_rounded : Icons.radio_button_unchecked,
      size: 16,
      color: earned ? const Color(0xFF51813A) : Colors.grey,
    ),
    label: Text(label, style: const TextStyle(fontSize: 11)),
    backgroundColor: earned ? const Color(0xFFE8F3DF) : AppColors.cream,
    visualDensity: VisualDensity.compact,
  );
}
