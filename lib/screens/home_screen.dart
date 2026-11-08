import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/rainbow_background.dart';
import 'backup_screen.dart';
import 'collection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: RainbowBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final compact = viewport.maxHeight < 560;
            final titleSize = viewport.maxWidth < 360
                ? 36.0
                : viewport.maxWidth < 600
                ? 42.0
                : 48.0;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        key: const Key('home-content'),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '\u{1F951}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: compact ? 68 : 90,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: compact ? 12 : 20),
                          Text(
                            'BơAnh Alliance',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleSize,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: compact ? 28 : 36),
                          Center(
                            child: SizedBox(
                              width: 280,
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CollectionScreen(),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  backgroundColor: AppColors.butterDark,
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'BẮT ĐẦU CHƠI',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: SizedBox(
                              width: 280,
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BackupScreen(),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.cloud_outlined,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Sao lưu / Khôi phục',
                                  textAlign: TextAlign.center,
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  foregroundColor: AppColors.text,
                                  side: BorderSide(
                                    color: AppColors.butterDark.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Xu và tiến độ tự lưu trên trình duyệt này.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Hạnh phúc không đâu cách xa ♡',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.text,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
