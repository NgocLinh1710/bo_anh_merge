import 'package:flutter/material.dart';

import '../main.dart';
import '../models/game_collection.dart';

class ImageTile extends StatelessWidget {
  final int? level;
  final GameCollection collection;
  final bool selected;
  final VoidCallback? onTap;
  final bool showImage;

  const ImageTile({
    super.key,
    required this.level,
    required this.collection,
    this.selected = false,
    this.onTap,
    this.showImage = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = level != null && collection.hasLevel(level!) && showImage;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? AppColors.butter : AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.butterDark
                : Colors.white.withValues(alpha: 0.9),
            width: selected ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.text.withValues(alpha: 0.08),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: level == null
              ? const SizedBox.expand()
              : hasImage
              ? Image.asset(
                  collection.imagePath(level!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return _fallback();
                  },
                )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.butterLight,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.butterDark,
            size: 22,
          ),
          if (level != null)
            Text(
              'Lv.$level',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
        ],
      ),
    );
  }
}
