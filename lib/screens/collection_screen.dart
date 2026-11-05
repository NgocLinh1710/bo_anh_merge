import 'dart:ui';

import 'package:flutter/material.dart';

import 'game_screen.dart';
import '../main.dart';
import '../models/game_collection.dart';
import '../services/collection_service.dart';
import '../services/game_storage_service.dart';
import '../models/game_mode.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late Future<List<GameCollection>> collectionsFuture;

  int totalCoins = 0;
  Set<String> unlockedCollections = {};

  bool isPlayerDataLoading = true;
  bool isUnlocking = false;

  @override
  void initState() {
    super.initState();

    collectionsFuture = CollectionService.loadCollections();
    _loadPlayerData();
  }

  // Tải số xu và danh sách ver đã mở khóa
  Future<void> _loadPlayerData() async {
    try {
      final coins = await GameStorageService.loadTotalCoins();
      final unlocked = await GameStorageService.loadUnlockedCollections();

      if (!mounted) return;

      setState(() {
        totalCoins = coins;
        unlockedCollections = unlocked;
        isPlayerDataLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu người chơi: $e');

      if (!mounted) return;

      setState(() {
        isPlayerDataLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải dữ liệu người chơi: $e')),
      );
    }
  }

  // Kiểm tra ver đã được mở khóa hay chưa
  bool _isUnlocked(GameCollection collection) {
    return CollectionService.isFree(collection.id) ||
        unlockedCollections.contains(collection.id);
  }

  Future<void> selectCollection(GameCollection collection) async {
    if (isUnlocking) return;

    if (!_isUnlocked(collection)) {
      await _showUnlockDialog(collection);
      return;
    }

    // Hiển thị lựa chọn chế độ chơi
    final selectedMode = await _showGameModeDialog(collection);

    if (selectedMode == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GameScreen(collection: collection, mode: selectedMode),
      ),
    );

    if (!mounted) return;

    await _loadPlayerData();
  }

  Future<GameMode?> _showGameModeDialog(GameCollection collection) async {
    final availableModes = collection.availableModes;

    if (availableModes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bộ sưu tập này hiện chưa có chế độ chơi!'),
        ),
      );
      return null;
    }

    return showDialog<GameMode>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.cream,
          elevation: 12,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sports_esports_rounded,
                    size: 48,
                    color: AppColors.butterDark,
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Chọn chế độ chơi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    collection.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.text),
                  ),

                  const SizedBox(height: 22),

                  ...availableModes.map((mode) {
                    final isFreeMode = mode == GameMode.free;

                    final icon = isFreeMode
                        ? Icons.all_inclusive_rounded
                        : Icons.timer_rounded;

                    final description = isFreeMode
                        ? 'Chơi thoải mái, không giới hạn thời gian.\n'
                              'Nhận 11 xu sau mỗi 14 cặp ghép thành công.'
                        : 'Bắt đầu với 14 giây.\n'
                              'Mỗi lần ghép sai bị trừ 1 giây.\n'
                              'Nhận 10 xu sau mỗi 5 cặp ghép thành công.';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.of(dialogContext).pop(mode);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.butterDark.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: AppColors.butterLight,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 28,
                                    color: AppColors.butterDark,
                                  ),
                                ),

                                const SizedBox(width: 14),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mode.displayName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.text,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Text(
                                        description,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.5,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.butterDark,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 4),

                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text(
                      'Quay lại',
                      style: TextStyle(color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Hiển thị hộp thoại xác nhận mở khóa
  Future<void> _showUnlockDialog(GameCollection collection) async {
    if (isUnlocking) return;

    final price = CollectionService.unlockPrice(collection.id);

    // ver chưa được thiết lập giá
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bộ sưu tập này hiện chưa mở bán!')),
      );
      return;
    }

    if (unlockedCollections.contains(collection.id)) return;

    // Kiểm tra số xu hiện có
    if (totalCoins < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn chưa có đủ xu để mở khóa bộ sưu tập này!'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    final screenSize = MediaQuery.sizeOf(context);

    // Chiều rộng
    final dialogWidth = (screenSize.width - 32).clamp(0.0, 520.0).toDouble();

    // Chiều cao
    final previewHeight = (screenSize.height * 0.22)
        .clamp(110.0, 220.0)
        .toDouble();

    final shouldUnlock = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.cream,
          elevation: 12,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SizedBox(
            width: dialogWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenSize.height * 0.85),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(screenSize.width < 400 ? 18 : 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Mở khóa bộ sưu tập?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),

                      const SizedBox(height: 20),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: double.infinity,
                          height: previewHeight,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Image.asset(
                              collection.imagePath(1),
                              width: double.infinity,
                              height: previewHeight,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  color: AppColors.butterLight,
                                  child: const Icon(
                                    Icons.image_rounded,
                                    size: 48,
                                    color: AppColors.butterDark,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Bạn muốn mở khóa "${collection.name}"?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Giá mở khóa
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$price xu',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Số xu hiện có
                      Text(
                        'Số xu hiện có: $totalCoins',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(
                                  dialogContext,
                                  rootNavigator: true,
                                ).pop(false);
                              },
                              child: const Text('Để sau'),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.butterDark,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.of(
                                  dialogContext,
                                  rootNavigator: true,
                                ).pop(true);
                              },
                              child: const Text('Mở khóa'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (shouldUnlock != true || !mounted || isUnlocking) {
      return;
    }

    await _processUnlock(collection, price);
  }

  // Thực hiện mở khóa và cập nhật dữ liệu
  Future<void> _processUnlock(GameCollection collection, int price) async {
    if (isUnlocking) return;

    setState(() {
      isUnlocking = true;
    });

    try {
      final success = await GameStorageService.unlockCollection(
        collection.id,
        price,
      );

      if (!mounted) return;

      // Tải lại số xu và danh sách đã mở khóa
      final newCoins = await GameStorageService.loadTotalCoins();
      final newUnlocked = await GameStorageService.loadUnlockedCollections();

      if (!mounted) return;

      setState(() {
        totalCoins = newCoins;
        unlockedCollections = newUnlocked;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã mở khóa ${collection.name} thành công!'),
            backgroundColor: AppColors.butterDark,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn chưa có đủ xu để mở khóa bộ sưu tập này!'),
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Lỗi mở khóa bộ sưu tập: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi khi mở khóa: $e'),
          backgroundColor: Colors.deepOrange,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUnlocking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chọn bộ ảnh',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.butterLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$totalCoins xu',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.cream, AppColors.butterLight, Color(0xFFF0E9FC)],
          ),
        ),

        child: FutureBuilder<List<GameCollection>>(
          future: collectionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                isPlayerDataLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.butterDark),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Không thể tải bộ sưu tập.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.text),
                  ),
                ),
              );
            }

            final collections = snapshot.data ?? [];

            if (collections.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 64,
                        color: AppColors.butterDark,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Chưa có bộ sưu tập nào!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Phiền bạn hãy đợi team update các ver ảnh nhéee',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.text, height: 1.5),
                      ),
                    ],
                  ),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1100
                    ? 4
                    : constraints.maxWidth >= 700
                    ? 3
                    : 2;

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: collections.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    final isUnlocked = _isUnlocked(collection);

                    return _CollectionCard(
                      collection: collection,
                      isUnlocked: isUnlocked,
                      price: CollectionService.unlockPrice(collection.id),
                      isUnlocking: isUnlocking,
                      onTap: () => selectCollection(collection),
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

// Thẻ hiển thị từng bộ sưu tập
class _CollectionCard extends StatelessWidget {
  final GameCollection collection;
  final bool isUnlocked;
  final int? price;
  final bool isUnlocking;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.collection,
    required this.isUnlocked,
    required this.price,
    required this.isUnlocking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isUnlocking ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: isUnlocked ? 0 : 6,
                          sigmaY: isUnlocked ? 0 : 6,
                        ),
                        child: Image.asset(
                          collection.imagePath(1),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              color: AppColors.butterLight,
                              child: const Icon(
                                Icons.image_rounded,
                                size: 52,
                                color: AppColors.butterDark,
                              ),
                            );
                          },
                        ),
                      ),

                      if (!isUnlocked) ...[
                        Container(color: Colors.black.withValues(alpha: 0.38)),

                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                              size: 42,
                            ),

                            const SizedBox(height: 6),

                            const Text(
                              'BỊ KHÓA',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),

                            if (price != null) ...[
                              const SizedBox(height: 8),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.monetization_on_rounded,
                                    color: Colors.orange,
                                    size: 18,
                                  ),

                                  const SizedBox(width: 4),

                                  Text(
                                    '$price xu',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                collection.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.text,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                '${collection.availableLevels.length} ảnh • '
                '${collection.maxLevel} cấp độ',
                style: const TextStyle(fontSize: 12, color: AppColors.text),
              ),

              const SizedBox(height: 10),

              if (isUnlocked)
                const Text(
                  'CHỌN  →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.butterDark,
                  ),
                )
              else if (price != null)
                const Text(
                  'MỞ KHÓA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.butterDark,
                  ),
                )
              else
                const Text(
                  'CHƯA MỞ BÁN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
